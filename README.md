# DOKS + NGINX Gateway Fabric – Terraform

Provisions a **DigitalOcean Kubernetes (DOKS)** cluster with two node pools
(2 droplets each) and installs **NGINX Gateway Fabric** via Helm.

---

## File layout

```
.
├── main.tf                   # Cluster, node pools, Helm release
├── variables.tf              # All input variables with descriptions
├── outputs.tf                # Useful values printed after apply
├── terraform.tfvars.example  # Copy → terraform.tfvars and fill in
└── gateway.yaml              # GatewayClass / Gateway / sample HTTPRoute
```

---

## Pre-requisites

| Tool | Min version | Install |
|------|-------------|---------|
| Terraform | 1.6 | https://developer.hashicorp.com/terraform/install |
| kubectl | 1.29 | https://kubernetes.io/docs/tasks/tools/ |
| doctl (optional) | 1.104 | https://docs.digitalocean.com/reference/doctl/ |

---

## Quick start

### 1 · Configure credentials

```bash
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars – set do_token and any other values you want to change.
```

Or export the token as an environment variable (preferred for CI):

```bash
export TF_VAR_do_token="your-token-here"
```

### 2 · Initialise and apply

```bash
terraform init
terraform plan   # review the changes
terraform apply
```

### 3 · Connect kubectl

```bash
terraform output -raw kubeconfig_raw > ~/.kube/do-cluster.yaml
export KUBECONFIG=~/.kube/do-cluster.yaml
kubectl get nodes
```

### 4 · Apply the Gateway manifests

```bash
kubectl apply -f gateway.yaml
kubectl get gateway -n nginx-gateway
```

### 5 · Get the external LoadBalancer IP

```bash
kubectl get svc -n nginx-gateway
# EXTERNAL-IP column shows the DigitalOcean LoadBalancer IP
```

Point your DNS `A` record (or test with curl `-H 'Host: example.com'`) at that IP.

---

## Destroying the cluster

```bash
terraform destroy
```

> **Note:** The DigitalOcean LoadBalancer created by the Helm chart is managed
> by Kubernetes, not Terraform. Run `kubectl delete gateway main-gateway -n nginx-gateway`
> **before** `terraform destroy` to ensure the LB is cleaned up and you are not
> billed for a dangling resource.

---

## Customisation tips

* **Different droplet sizes** – change `node_pool_general_size` /
  `node_pool_secondary_size` in `terraform.tfvars`. Run
  `doctl compute size list` to see available slugs.

* **Different region** – set `region` (e.g. `sfo3`, `lon1`, `fra1`).
  Run `doctl kubernetes options regions`.

* **Enable auto-scaling** – in `main.tf`, set `auto_scale = true` and add
  `min_nodes` / `max_nodes` to the node pool blocks.

* **TLS** – uncomment the `https` listener in `gateway.yaml` and create a
  Kubernetes Secret with your certificate.

* **Separate tfvars per environment** – use
  `terraform apply -var-file=prod.tfvars`.
