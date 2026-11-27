resource "azurerm_resource_group" "main" {
  name     = "rg-${var.prefix}-aks"
  location = var.location
  tags     = var.tags
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = [var.vnet_cidr]
  tags                = var.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_cidr]
}

# Trivy-undantag (granskat 2026-11-27):
# AZU-0041 vill att API-servern bara nås från vissa IP-adresser. GitHubs
# runners byter IP-adress hela tiden, så pipelinen skulle då inte kunna köra
# kubectl. Åtkomst kräver ändå inloggning, och klustret lever bara en kort
# stund. Ta bort undantaget om pipelinen flyttas till en runner med fast IP.
#trivy:ignore:AZU-0041
resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${var.prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-${var.prefix}"
  sku_tier            = "Free"
  tags                = var.tags

  # Är redan standard, men skrivs ut så att det syns (och så att Trivy ser det).
  role_based_access_control_enabled = true

  default_node_pool {
    name           = "system"
    node_count     = var.node_count
    vm_size        = var.node_vm_size
    vnet_subnet_id = azurerm_subnet.aks.id
  }

  # Krävs från azurerm 5. "Manual" betyder att noderna kommer från
  # default_node_pool ovan, precis som tidigare. "Auto" skulle låta Azure
  # skapa och ta bort noder själv (Node Auto Provisioning).
  node_provisioning_profile {
    mode = "Manual"
  }

  identity {
    type = "SystemAssigned"
  }

  # Cilium gör att klustret kan följa NetworkPolicy, alltså regler för vilka
  # poddar som får prata med varandra. Utan det ignoreras sådana regler.
  # Cilium är Microsofts rekommenderade val för Azure CNI och kostar inget extra.
  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.2.0.0/16"
    dns_service_ip      = "10.2.0.10"
  }
}
