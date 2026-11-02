# azure-aks-terraform

Basic Azure setup with Terraform: remote state, resource group, VNet/subnet and an AKS cluster.
Built as a learning project to practise Terraform on Azure.

Two stacks:
- `bootstrap/`: storage account for remote state (local state, run once)
- `infra/`: resource group, VNet/subnet and AKS, using remote state

## Prerequisites
- Terraform >= 1.6, Azure CLI
- `az login` and `az account set --subscription <id>`

## 1. Bootstrap remote state
    cd bootstrap
    terraform init
    terraform apply -var subscription_id=<SUB_ID>

Note the outputs (`storage_account_name` etc).

## 2. Deploy AKS
    cd ../infra
    cp backend.hcl.example backend.hcl     # fill in storage_account_name
    terraform init -backend-config=backend.hcl
    terraform plan  -var subscription_id=<SUB_ID>
    terraform apply -var subscription_id=<SUB_ID>

    $(terraform output -raw get_credentials)
    kubectl get nodes

## 3. Tear down (AKS bills while running)
    cd infra && terraform destroy -var subscription_id=<SUB_ID>
    # Remote state is cheap; destroy bootstrap/ only when you are fully done.

## Configuration
Copy `terraform.tfvars.example` to `terraform.tfvars` in each stack and set `subscription_id`
(or pass it with `-var`). `*.tfvars` and `backend.hcl` are git-ignored.

## CI
`.github/workflows/validate.yml` runs `terraform fmt -check`, `init -backend=false` and
`validate` on both stacks. It needs no Azure credentials.

## Planned next steps
- Split networking and AKS into modules
- Separate dev/test environments with their own state keys
- Run `plan`/`apply` from a pipeline with OIDC auth instead of local runs
- Install ArgoCD on the cluster via Helm
