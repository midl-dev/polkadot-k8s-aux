# An empty module.
# We do not want cluster creation to take place, so this is a placeholder for the module that creates a cluster.

variable "project" {
  type = "string"
  description = "project name"
  default = ""
}

variable "kubernetes_endpoint" {
  type = "string"
}

variable "cluster_ca_certificate" {
  type = "string"
}

variable "kubernetes_access_token" {
  type = "string"
}

output "name" {
  value = ""
}

output "kubernetes_endpoint" {
  value = var.kubernetes_endpoint
}

output "cluster_ca_certificate" {
  value = var.cluster_ca_certificate
}

output "kubernetes_access_token" {
  value = var.kubernetes_access_token
}

output "location" {
  value = ""
}

output "project" {
  value = var.project
}
