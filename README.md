# azure-aks-terraform

A small project where I'm learning Terraform on Azure. It sets up a network
and a Kubernetes cluster (AKS) in Azure, all from code.

## The big picture

```text
 Your machine        GitHub Actions                    ghcr.io
┌─────────────┐     ┌─────────────────┐  push image   ┌─────────────────┐
│ bootstrap   │     │ App Build       ├──────────────►│ hello-app image │
│ (run once)  │     └─────────────────┘               └────────┬────────┘
└──────┬──────┘     ┌─────────────────┐                        │
       │            │ Terraform Infra │                        │
       │            └───┬─────────┬───┘                        │
       │ creates        │         │ OIDC login:                │ the cluster
       │                │         │ build, deploy, destroy     │ pulls the image
       │                │ state   │                            │
┌──────┼────────────────┼─────────┼────────────────────────────┼─────────┐
│ Azure│                │         │                            │         │
│      ▼                ▼         ▼                            ▼         │
│ ┌──────────────────────┐   ┌─────────────────────────────────────────┐ │
│ │ rg-tfdemo-tfstate    │   │ rg-demo-aks                             │ │
│ │ always there         │   │ only there while you're using it        │ │
│ │                      │   │                                         │ │
│ │ storage account      │   │ vnet-demo (10.0.0.0/16)                 │ │
│ │ └─ tfstate           │   │ └─ snet-aks (10.0.1.0/24)               │ │
│ │    └─ aks-dev.tfstate│   │    └─ aks-demo (1 node)                 │ │
│ │                      │   │       └─ namespace hello-app            │ │
│ │ identity for GitHub  │   │          ├─ Deployment (2 pods)         │ │
│ │ (made by hand)       │   │          └─ Service (internal only)     │ │
│ └──────────────────────┘   └─────────────────────────────────────────┘ │
└────────────────────────────────────────────────────────────────────────┘
```

What happens when you start **Terraform Infra** with `apply`:

```text
 check-image ───► terraform-apply ───► app-deploy ───► auto-destroy
 Can the image    Creates the          Deploys the     Waits 15, 30 or 60
 be downloaded?   network and          app and runs    minutes, then
                  the cluster          a smoke test    removes everything
```

- If `check-image` fails, nothing has been created, so there's nothing to remove.
- If a later step fails, `auto-destroy` skips the wait and removes everything
  straight away.
- If you pick `0` minutes there's no timer. You run `destroy` yourself.

## How it's organised

All Terraform code lives in `terraform/`. There are two folders, and you run
them in order:

- **`terraform/bootstrap/`** creates a storage account in Azure. That's where Terraform
  keeps its state file, which is its memory of what it has built. You only
  run this once.
- **`terraform/infra/`** is the actual setup: a resource group, a network and the
  AKS cluster. Its state is saved in the storage account from `terraform/bootstrap/`.

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
cd terraform/bootstrap
terraform init
terraform apply -var subscription_id=<your-subscription-id>
```

When it's done it prints a few names. Copy `storage_account_name`, you'll need
it in the next step.

Heads up: `terraform/bootstrap/` keeps its own state in a local file,
`terraform/bootstrap/terraform.tfstate`. Don't delete it and don't commit it.

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
cd terraform/infra
terraform destroy -var subscription_id=<your-subscription-id>
```

The storage account from `terraform/bootstrap/` costs almost nothing, so you can leave
it. Only destroy it when you're finished with the whole project.

## Skipping `-var subscription_id=...`

Typing the subscription id every time gets old. Copy
`terraform.tfvars.example` to `terraform.tfvars` in each folder and fill it in.
Terraform reads that file automatically.

Don't commit `terraform.tfvars`, `backend.hcl` or any `*.tfstate` files.

## The app

`app/` is a tiny Python web app that gets deployed to the cluster, just to
prove that everything works. It has two pages:

- `/` says hello and tells you which pod answered
- `/health` answers `{"status": "ok"}`

The Kubernetes files are in `app/k8s/`. The app isn't reachable from the
internet. To look at it yourself once it's deployed:

```bash
kubectl port-forward --namespace hello-app service/hello-app 8080:80
```

Then open http://localhost:8080.

The app uses [uv](https://docs.astral.sh/uv/) for Python and its
dependencies. Running the tests locally:

```bash
cd app
uv run pytest
```

uv installs the right Python version and the dependencies by itself the first
time. To add a dependency, use `uv add <package>` instead of editing
`pyproject.toml` by hand, so that `uv.lock` stays up to date.

## GitHub Actions

- **Terraform Validate** runs on every push. It checks that the code is
  formatted and valid. It doesn't log in to Azure or build anything.
- **App Build** runs whenever something in `app/` changes. It runs the tests
  and builds an OCI image from `app/Containerfile` with
  [Buildah](https://buildah.io/) (no Docker involved). On `main` it also
  pushes the image to GitHub Container Registry (ghcr.io). You can also start
  it by hand from the Actions tab, for example if the image is missing.
- **Terraform Infra** is started by hand from the Actions tab. When you pick
  `apply` it:
  1. checks that the app's image exists on ghcr.io and can be downloaded,
     before it creates anything
  2. builds the cluster with Terraform
  3. deploys the app to the cluster
  4. runs a smoke test that checks `/health`
  5. tears everything down after 15, 30 or 60 minutes, so nothing is left
     running by mistake

  It needs an Azure login set up for GitHub (OIDC) first.

The image is tagged with the commit that last changed `app/`, so App Build
and Terraform Infra always agree on which image to use.

New packages on ghcr.io are always private. After App Build has pushed the
image the first time, make it public once: your GitHub profile → Packages →
hello-app → Package settings → Change visibility → Public. Otherwise the
cluster isn't allowed to download it.

`terraform/bootstrap/` is never run from GitHub, only by hand from your own machine.

## Why it's built this way

**Terraform**

- **Bootstrap is separate.** The state storage has to exist before Terraform
  can save state in it, so it can't be part of the setup it stores state for.
- **State lives in Azure, not on one laptop.** GitHub's runners are thrown away
  after every job, so a local state file would be lost. The storage account
  also locks the state, so two runs can't change it at once.
- **Versioning is on for the state.** If the state file gets damaged, an older
  version can be restored.
- **Only the Azure services we use are registered.** By default the provider
  registers about 20 services, which made the first run hang for many minutes.

**Logging in**

- **GitHub logs in with OIDC.** GitHub proves who it is with a short-lived
  token, so there's no Azure password stored that could leak or expire.
- **State is read with Entra ID (`use_azuread_auth`).** Access is controlled by
  a role, so the storage account's master keys aren't used.

**The cluster**

- **`Standard_D2ls_v5` nodes.** It's a small size that meets AKS's minimum of
  2 vCPU and 4 GiB. `Standard_B2s` wasn't allowed on this subscription and
  `Standard_B2als_v2` failed because Azure had no free capacity.
- **Azure CNI overlay.** Pods get addresses from their own range instead of
  from the subnet, so a small subnet is enough.
- **Free AKS tier and one node.** This is a lab, so it doesn't need an uptime
  guarantee or spare nodes.
- **Everything is removed on a timer.** The node costs money for as long as it
  exists, and it's easy to forget. If `terraform destroy` fails, the whole
  resource group is deleted instead.

**The app**

- **Building is separate from deploying.** The image is built when `app/`
  changes, so starting the cluster doesn't have to wait for a build.
- **The image tag is the last commit that changed `app/`.** Both workflows can
  work out the same tag by themselves, and a tag always points to one exact
  version of the code.
- **The image is checked first.** Creating a cluster takes 10 minutes or more,
  so a missing image should stop the run before that.
- **OCI image built with Buildah.** OCI is the open image standard, so nothing
  here depends on Docker.
- **Plain Kubernetes YAML.** With one small app, a tool like Kustomize or Helm
  would add more to learn than it saves.
- **The app runs locked down.** It isn't root, and its file system is read-only.
- **No public address.** The smoke test reaches the app with
  `kubectl port-forward`, so nothing is exposed to the internet.

**Shortcuts that are fine for a lab, but not for production**

- The pipeline's identity is `Contributor` on the whole subscription.
- That identity and its login for GitHub were made by hand, not with Terraform.
- `az aks get-credentials` gives full admin access to the cluster. Production
  should use Entra ID login and turn local accounts off.
- The image is public, so the cluster doesn't need a login to download it.

## Ideas for later

- Move the network and cluster into reusable modules
- Separate dev and test environments
- Install ArgoCD on the cluster
