output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "get_credentials" {
  value = "az aks get-credentials --resource-group ${azurerm_resource_group.main.name} --name ${azurerm_kubernetes_cluster.main.name}"
}
