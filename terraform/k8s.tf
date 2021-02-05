resource "null_resource" "push_containers" {


  triggers = {
    host = md5(module.terraform-gke-blockchain.kubernetes_endpoint)
    cluster_ca_certificate = md5(
      module.terraform-gke-blockchain.cluster_ca_certificate,
    )
  }
  provisioner "local-exec" {
    interpreter = [ "/bin/bash", "-c" ]
    command = <<EOF
set -x

build_container () {
  set -x
  cd $1
  container=$(basename $1)
  cp Dockerfile.template Dockerfile
  sed -i "s/((polkadot_version))/${var.polkadot_version}/" Dockerfile
  cat << EOY > cloudbuild.yaml
steps:
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', "gcr.io/${module.terraform-gke-blockchain.project}/$container:${var.kubernetes_namespace}-latest", '.']
images: ["gcr.io/${module.terraform-gke-blockchain.project}/$container:${var.kubernetes_namespace}-latest"]
EOY
  gcloud builds submit --project ${module.terraform-gke-blockchain.project} --config cloudbuild.yaml .
  rm -v Dockerfile
  rm cloudbuild.yaml
}
export -f build_container
find ${path.module}/../docker -mindepth 1 -maxdepth 1 -type d -exec bash -c 'build_container "$0"' {} \; -printf '%f\n'
#build_container ${path.module}/../docker/validator-monitor
EOF
  }
}

resource "kubernetes_namespace" "polkadot_namespace" {
  metadata {
    name = var.kubernetes_namespace
  }
}

resource "kubernetes_secret" "polkadot_payout_account_mnemonic" {
  metadata {
    name = "polkadot-payout-account-mnemonic"
    namespace = var.kubernetes_namespace
  }
  data = {
    "payout-account-mnemonic" = var.payout_account_mnemonic
  }
  depends_on = [ null_resource.push_containers, kubernetes_namespace.polkadot_namespace ]
}

resource "null_resource" "apply" {
  provisioner "local-exec" {

    command = <<EOF
set -e
set -x
gcloud container clusters get-credentials "${module.terraform-gke-blockchain.name}" --region="${module.terraform-gke-blockchain.location}" --project="${module.terraform-gke-blockchain.project}"

rm -rvf ${path.module}/k8s-${var.kubernetes_namespace}
mkdir -p ${path.module}/k8s-${var.kubernetes_namespace}
cp -rv ${path.module}/../k8s/*base* ${path.module}/k8s-${var.kubernetes_namespace}
pushd ${path.module}/k8s-${var.kubernetes_namespace}
cat <<EOK > kustomization.yaml
${templatefile("${path.module}/../k8s/kustomization.yaml.tmpl",
     { "project" : module.terraform-gke-blockchain.project,
       "polkadot_archive_url": var.polkadot_archive_url,
       "polkadot_version": var.polkadot_version,
       "chain": var.chain,
       "kubernetes_namespace": var.kubernetes_namespace,
       "kubernetes_name_prefix": var.kubernetes_name_prefix,
       "polkadot_validators": var.polkadot_validators})}
EOK
mkdir -p polkadot-node
cat <<EOK > polkadot-node/kustomization.yaml
${templatefile("${path.module}/../k8s/polkadot-node-tmpl/kustomization.yaml.tmpl",
     { "project" : module.terraform-gke-blockchain.project,
       "polkadot_archive_url": var.polkadot_archive_url,
       "polkadot_version": var.polkadot_version,
       "chain": var.chain,
       "kubernetes_namespace": var.kubernetes_namespace,
       "kubernetes_name_prefix": var.kubernetes_name_prefix,
       "polkadot_validators": var.polkadot_validators})}
EOK
cat <<EOP > polkadot-node/polkadot-node-patch.yaml
${templatefile("${path.module}/../k8s/polkadot-node-tmpl/polkadot-node-patch.yaml.tmpl",
     { "kubernetes_pool_name" : var.kubernetes_pool_name })}
EOP
cat <<EOP > polkadot-node/validator-monitor-patch.yaml
${templatefile("${path.module}/../k8s/polkadot-node-tmpl/validator-monitor-patch.yaml.tmpl",
     { "kubernetes_pool_name" : var.kubernetes_pool_name })}
EOP
cat <<EOP > polkadot-node/prefixedpvnode.yaml
${templatefile("${path.module}/../k8s/polkadot-node-tmpl/prefixedpvnode.yaml.tmpl",
     { "kubernetes_name_prefix" : var.kubernetes_name_prefix })}
EOP
%{ for validator in var.polkadot_validators }
mkdir -p payout-cron-${validator.name}
cat <<EOP > payout-cron-${validator.name}/payout-cron-patch.yaml
${templatefile("${path.module}/../k8s/payout-cron-tmpl/payout-cron-patch.yaml.tmpl",
     { "kubernetes_pool_name" : var.kubernetes_pool_name,
       "validator": validator})}
EOP
cat <<EOK > payout-cron-${validator.name}/kustomization.yaml
${templatefile("${path.module}/../k8s/payout-cron-tmpl/kustomization.yaml.tmpl",
     { "project" : module.terraform-gke-blockchain.project,
       "kubernetes_pool_name" : var.kubernetes_pool_name,
       "kubernetes_namespace": var.kubernetes_namespace,
       "kubernetes_name_prefix": var.kubernetes_name_prefix,
       "validator" : validator })}
EOK
%{ endfor }
kubectl apply -k .
popd
#rm -rvf ${path.module}/k8s-${var.kubernetes_namespace}
EOF

  }
  depends_on = [ null_resource.push_containers, kubernetes_namespace.polkadot_namespace ]
}
