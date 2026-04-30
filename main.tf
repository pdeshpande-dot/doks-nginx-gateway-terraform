# ==============================================================================
# main.tf
# Entry point: Provisions the DigitalOcean Kubernetes (DOKS) cluster and
# two node pools, then installs NGINX Gateway Fabric via Helm once the
# cluster is ready.
# ==============================================================================

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.40"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
  }
}

# ==============================================================================
# Providers
# ==============================================================================

provider "digitalocean" {
  token = var.do_token
}

# The Kubernetes and Helm providers are configured dynamically using the
# credentials that DigitalOcean returns after the cluster is created.
provider "kubernetes" {
  host                   = digitalocean_kubernetes_cluster.main.endpoint
  token                  = digitalocean_kubernetes_cluster.main.kube_config[0].token
  cluster_ca_certificate = base64decode(
    digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
  )
}

provider "helm" {
  kubernetes {
    host                   = digitalocean_kubernetes_cluster.main.endpoint
    token                  = digitalocean_kubernetes_cluster.main.kube_config[0].token
    cluster_ca_certificate = base64decode(
      digitalocean_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate
    )
  }
}

# ==============================================================================
# DOKS Cluster
# ==============================================================================

resource "digitalocean_kubernetes_cluster" "main" {
  name    = var.cluster_name
  region  = var.region
  version = var.k8s_version

  # Cluster-level tags make cost attribution and firewall rules easier.
  tags = concat(var.tags, ["cluster:${var.cluster_name}"])

  # ── Node Pool 1: General-purpose workloads ──────────────────────────────────
  node_pool {
    name       = "${var.cluster_name}-pool-general"
    size       = var.node_pool_general_size
    node_count = 2                                   # 2 droplets as requested
    auto_scale = false

    labels = {
      pool = "general"
      env  = var.environment
    }

    tags = concat(var.tags, ["pool:general"])
  }
}

# ── Node Pool 2: Secondary / specialised workloads ───────────────────────────
# Defined as a separate resource so it can be managed independently
# (e.g. scaled or replaced without touching pool-1).
resource "digitalocean_kubernetes_node_pool" "secondary" {
  cluster_id = digitalocean_kubernetes_cluster.main.id

  name       = "${var.cluster_name}-pool-secondary"
  size       = var.node_pool_secondary_size
  node_count = 2                                     # 2 droplets as requested
  auto_scale = false

  labels = {
    pool = "secondary"
    env  = var.environment
  }

  tags = concat(var.tags, ["pool:secondary"])
}

# ==============================================================================
# NGINX Gateway Fabric – installed via Helm once the cluster exists
# ==============================================================================

# 1. Create the namespace that Gateway Fabric lives in.
resource "kubernetes_namespace" "nginx_gateway" {
  metadata {
    name = var.nginx_gateway_namespace
    labels = {
      "app.kubernetes.io/managed-by" = "terraform"
    }
  }

  # Ensure the cluster (and both node pools) are fully ready first.
  depends_on = [
    digitalocean_kubernetes_cluster.main,
    digitalocean_kubernetes_node_pool.secondary,
  ]
}

# 2. Install the Gateway API CRDs (required before the Helm chart).
#    Using a null_resource + local-exec keeps the CRD install idempotent
#    across plan/apply cycles without managing raw YAML in Terraform state.
resource "null_resource" "gateway_api_crds" {
  triggers = {
    # Re-apply if the CRD version changes.
    crd_version = var.gateway_api_crd_version
  }

  provisioner "local-exec" {
    command = <<-EOT
      kubectl apply -f \
        https://github.com/kubernetes-sigs/gateway-api/releases/download/${var.gateway_api_crd_version}/standard-install.yaml \
        --kubeconfig <(echo '${digitalocean_kubernetes_cluster.main.kube_config[0].raw_config}')
    EOT
    interpreter = ["bash", "-c"]
  }

  depends_on = [kubernetes_namespace.nginx_gateway]
}

# 3. Deploy NGINX Gateway Fabric via its official Helm chart.
resource "helm_release" "nginx_gateway_fabric" {
  name       = "nginx-gateway-fabric"
  repository = "oci://ghcr.io/nginxinc/charts"
  chart      = "nginx-gateway-fabric"
  version    = var.nginx_gateway_chart_version
  namespace  = kubernetes_namespace.nginx_gateway.metadata[0].name

  # Expose the gateway via a DigitalOcean LoadBalancer.
  set {
    name  = "nginx.service.type"
    value = "LoadBalancer"
  }

  # Optional: annotate the LB so DigitalOcean names it in the dashboard.
  set {
    name  = "nginx.service.annotations.service\\.beta\\.kubernetes\\.io/do-loadbalancer-name"
    value = "${var.cluster_name}-nginx-gateway"
  }

  # Wait for all pods to be Running before Terraform marks the release done.
  wait          = true
  wait_for_jobs = true
  timeout       = 300

  depends_on = [null_resource.gateway_api_crds]
}
