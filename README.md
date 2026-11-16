# azure-aks-terraform

A small project where I'm learning Terraform on Azure. It sets up a network
and a Kubernetes cluster (AKS) in Azure, all from code.

## How it's organised

There are two folders, and you run them in order:

- **`bootstrap/`** creates a storage account in Azure. That's where Terraform
  keeps its state file, which is its memory of what it has built. You only
  run this once.
- **`infra/`** is the actual setup: a resource group, a network and the
  AKS cluster. Its state is saved in the storage account from `bootstrap/`.

Why two folders? Terraform needs somewhere to save its state before it can
build anything else, so that place has to exist first.

## What you need

- Terraform 1.6 or newer
- Azure CLI, logged in:

```bash
az login
az account set --subscription <your-subscription-id>
```

## Step 1: Create the state storage

```bash
cd bootstrap
terraform init
terraform apply -var subscription_id=<your-subscription-id>
```

When it's done it prints a few names. Copy `storage_account_name`, you'll need
it in the next step.

Heads up: `bootstrap/` keeps its own state in a local file,
`bootstrap/terraform.tfstate`. Don't delete it and don't commit it.

## Step 2: Build the cluster

```bash
cd ../infra
cp backend.hcl.example backend.hcl
```

Open `backend.hcl` and paste in the storage account name from step 1. Then:

```bash
terraform init -backend-config=backend.hcl
terraform plan -var subscription_id=<your-subscription-id>
terraform apply -var subscription_id=<your-subscription-id>
```

`plan` shows what will be created. `apply` actually creates it, which takes
around 10 minutes.

To talk to the cluster afterwards:

```bash
$(terraform output -raw get_credentials)
kubectl get nodes
```

## Step 3: Tear it down when you're done

The cluster costs money for as long as it exists, so remove it when you're
not using it:

```bash
cd infra
terraform destroy -var subscription_id=<your-subscription-id>
```

The storage account from `bootstrap/` costs almost nothing, so you can leave
it. Only destroy it when you're finished with the whole project.

## Skipping `-var subscription_id=...`

Typing the subscription id every time gets old. Copy
`terraform.tfvars.example` to `terraform.tfvars` in each folder and fill it in.
Terraform reads that file automatically.

Don't commit `terraform.tfvars`, `backend.hcl` or any `*.tfstate` files.

## GitHub Actions

- **Terraform Validate** runs on every push. It checks that the code is
  formatted and valid. It doesn't log in to Azure or build anything.
- **Terraform Infra** is started by hand from the Actions tab. It can build or
  tear down `infra/`, and can tear it down automatically after 15, 30 or 60
  minutes so nothing is left running by mistake. It needs an Azure login set
  up for GitHub (OIDC) first, which isn't in place yet.

`bootstrap/` is never run from GitHub, only by hand from your own machine.

## Ideas for later

- Move the network and cluster into reusable modules
- Separate dev and test environments
- Install ArgoCD on the cluster
