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

# Standard_B2als_v2 (2 vCPU, 4 GiB) är den billigaste storleken som uppfyller
# AKS minimikrav för systemnoder (2 vCPU, 4 GiB). Gamla Standard_B2s är inte
# tillåten i alla subscriptions i swedencentral.
variable "node_vm_size" {
  type        = string
  default     = "Standard_B2als_v2"
  description = "Cheap dev size. Check availability/quota in your region."
}

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
    managed_by  = "terraform"
  }
}
