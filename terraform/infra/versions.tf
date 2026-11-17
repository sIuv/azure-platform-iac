terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # Partial config: values come from backend.hcl (see backend.hcl.example).
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id

  # Registrera bara de Azure-tjänster som infra använder. Annars registrerar
  # providern ett tjugotal tjänster, vilket kan ta många minuter första gången.
  # Lägg till här när nya typer av resurser används.
  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.ContainerService", # AKS-klustret
    "Microsoft.Network",          # VNet och subnät
    "Microsoft.Compute",          # virtuella maskiner som är klustrets noder
  ]
}
