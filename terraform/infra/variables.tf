variable "subscription_id" {
  type        = string
  description = "Azure subscription ID"
}

variable "location" {
  type    = string
  default = "swedencentral"
}

variable "prefix" {
  type        = string
  default     = "demo"
  description = "Short name used in resource names"
}

variable "vnet_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "aks_subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "node_count" {
  type    = number
  default = 1
}

# Standard_D2ls_v5 (2 vCPU, 4 GiB) uppfyller AKS minimikrav för systemnoder
# (2 vCPU, 4 GiB). Billigare B-serien fungerade inte i swedencentral:
# Standard_B2s är inte tillåten i alla subscriptions, och Standard_B2als_v2
# gav "AllocationFailed" (Azure saknade ledig kapacitet). D-serien har oftast
# mer ledig kapacitet, och Azure föreslog själv den här storleken.
variable "node_vm_size" {
  type        = string
  default     = "Standard_D2ls_v5"
  description = "Cheap dev size. Check availability/quota in your region."
}

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
    managed_by  = "terraform"
  }
}
