# Azure AKS with Terraform (basic)

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
