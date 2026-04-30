# ==============================================================================
# variables.tf
# All input variables in one place. Override them in terraform.tfvars or via
# environment variables (TF_VAR_*) – never hard-code secrets in source files.
# ==============================================================================

# ── Authentication ─────────────────────────────────────────────────────────────

variable "do_token" {
  description = "DigitalOcean personal access token. Set via TF_VAR_do_token."
  type        = string
  sensitive   = true
}

# ── Cluster settings ───────────────────────────────────────────────────────────

variable "cluster_name" {
  description = "Unique name for the DOKS cluster (also used as a prefix for child resources)."
  type        = string
  default     = "my-doks-cluster"
}

variable "region" {
  description = "DigitalOcean region slug (e.g. nyc3, sfo3, lon1, fra1)."
  type        = string
  default     = "nyc3"
}

variable "k8s_version" {
  description = <<-EOT
    Kubernetes version string as returned by:
      doctl kubernetes options versions
    Example: "1.30.4-do.0"
  EOT
  type    = string
  default = "1.30.4-do.0"
}

variable "environment" {
  description = "Environment label applied to node labels and tags (e.g. dev, staging, prod)."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "tags" {
  description = "List of tags applied to all DigitalOcean resources for billing / filtering."
  type        = list(string)
  default     = ["terraform-managed"]
}

# ── Node pool sizes ────────────────────────────────────────────────────────────
# Run `doctl compute size list` for all valid slug values.

variable "node_pool_general_size" {
  description = "Droplet size for the general-purpose node pool."
  type        = string
  default     = "s-2vcpu-4gb"   # 2 vCPU, 4 GB RAM – good all-rounder
}

variable "node_pool_secondary_size" {
  description = "Droplet size for the secondary node pool."
  type        = string
  default     = "s-2vcpu-4gb"
}

# ── NGINX Gateway Fabric ───────────────────────────────────────────────────────

variable "nginx_gateway_namespace" {
  description = "Kubernetes namespace where NGINX Gateway Fabric is installed."
  type        = string
  default     = "nginx-gateway"
}

variable "nginx_gateway_chart_version" {
  description = <<-EOT
    Helm chart version for NGINX Gateway Fabric.
    Check latest at: https://github.com/nginxinc/nginx-gateway-fabric/releases
  EOT
  type    = string
  default = "1.3.0"
}

variable "gateway_api_crd_version" {
  description = <<-EOT
    Gateway API CRD bundle version to install before the Helm chart.
    Must match the version expected by nginx_gateway_chart_version.
    Check: https://github.com/kubernetes-sigs/gateway-api/releases
  EOT
  type    = string
  default = "v1.1.0"
}
