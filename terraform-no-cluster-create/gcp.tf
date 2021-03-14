# Configure kubernetes provider with Oauth2 access token.
# https://registry.terraform.io/providers/hashicorp/google/latest/docs/data-sources/client_config
# This fetches a new token, which will expire in 1 hour.
data "google_client_config" "default" {
}

# This file contains all the interactions with Kubernetes
provider "kubernetes" {
  host             = module.terraform-gke-blockchain.kubernetes_endpoint
  cluster_ca_certificate = module.terraform-gke-blockchain.cluster_ca_certificate
  token = data.google_client_config.default.access_token
}

module "terraform-gke-blockchain" {
  source = "./empty_module"
  project = var.project
  region = var.region
  node_locations = var.node_locations
  kubernetes_endpoint = var.kubernetes_endpoint
  cluster_ca_certificate = var.cluster_ca_certificate
  cluster_name = var.cluster_name
  kubernetes_access_token = var.kubernetes_access_token
}
