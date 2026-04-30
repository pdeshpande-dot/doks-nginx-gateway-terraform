# ==============================================================================
# outputs.tf
# Values printed after `terraform apply` – useful for connecting kubectl,
# configuring CI/CD pipelines, and quick health checks.
# ==============================================================================

output "cluster_id" {
  description = "DigitalOcean cluster UUID."
  value       = digitalocean_kubernetes_cluster.main.id
}

output "cluster_name" {
  description = "Human-readable cluster name."
  value       = digitalocean_kubernetes_cluster.main.name
}

output "cluster_endpoint" {
  description = "Kubernetes API server endpoint."
  value       = digitalocean_kubernetes_cluster.main.endpoint
  sensitive   = true
}

output "kubeconfig_raw" {
  description = <<-EOT
    Raw kubeconfig for the cluster.
    Save to a file and point KUBECONFIG at it, or pipe to:
      terraform output -raw kubeconfig_raw > ~/.kube/do-cluster.yaml
  EOT
  value     = digitalocean_kubernetes_cluster.main.kube_config[0].raw_config
  sensitive = true
}

output "node_pool_general_id" {
  description = "ID of the general-purpose node pool."
  value       = digitalocean_kubernetes_cluster.main.node_pool[0].id
}

output "node_pool_secondary_id" {
  description = "ID of the secondary node pool."
  value       = digitalocean_kubernetes_node_pool.secondary.id
}

output "nginx_gateway_namespace" {
  description = "Namespace where NGINX Gateway Fabric was deployed."
  value       = kubernetes_namespace.nginx_gateway.metadata[0].name
}

output "nginx_gateway_helm_status" {
  description = "Status of the NGINX Gateway Fabric Helm release."
  value       = helm_release.nginx_gateway_fabric.status
}
