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

variable "node_vm_size" {
  type        = string
  default     = "Standard_B2s"
  description = "Cheap dev size. Check availability/quota in your region."
}

variable "tags" {
  type = map(string)
  default = {
    environment = "dev"
    managed_by  = "terraform"
  }
}
