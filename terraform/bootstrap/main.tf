# Bootstrap: creates the storage account that holds remote state for ../infra.
# This stack itself uses local state (chicken-and-egg). Run it once.

terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 5.15"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id

  # Registrera bara de Azure-tjänster som bootstrap använder. Annars registrerar
  # providern ett tjugotal tjänster, vilket kan ta många minuter första gången.
  resource_provider_registrations = "none"
  resource_providers_to_register = [
    "Microsoft.Storage", # lagringskontot för state
  ]
}

variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "location" {
  type    = string
  default = "swedencentral"
}

variable "prefix" {
  type    = string
  default = "tfdemo"
}

data "azurerm_client_config" "current" {}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "state" {
  name     = "rg-${var.prefix}-tfstate"
  location = var.location
}

# Trivy-undantag (granskat 2026-11-27):
# AZU-0012 vill att lagringskontot nekar all nätverkstrafik som standard.
# GitHubs runners byter IP-adress hela tiden och måste kunna läsa state, så
# det skulle kräva en privat endpoint och en egen runner. Åtkomst kräver ändå
# inloggning med Entra ID och rollen Storage Blob Data Contributor.
#trivy:ignore:AZU-0012
resource "azurerm_storage_account" "state" {
  name                     = "st${var.prefix}tfstate${random_string.suffix.result}"
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"

  blob_properties {
    versioning_enabled = true
  }

  # Här ligger state för terraform/infra. Försvinner det vet Terraform inte
  # längre vad som finns i Azure. Vill du verkligen riva allt: ta bort
  # blocket först, och kör sedan terraform destroy.
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_container" "state" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.state.id
  container_access_type = "private"

  # Samma skäl som för lagringskontot ovan.
  lifecycle {
    prevent_destroy = true
  }
}

# Lets you (the current user) read/write state using Entra ID auth.
resource "azurerm_role_assignment" "state_blob" {
  scope                = azurerm_storage_account.state.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

output "resource_group_name" {
  value = azurerm_resource_group.state.name
}

output "storage_account_name" {
  value = azurerm_storage_account.state.name
}

output "container_name" {
  value = azurerm_storage_container.state.name
}
