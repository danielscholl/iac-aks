variable "prefix" {
  type        = "string"
  description = "Unique Prefix."
  "default" = "dks"
}

variable "location" {
  type        = "string"
  description = "Location for the resource groups."
  default     = "eastus"
}

variable "sp_least_privilidge" {
  description = "[Alpha] This feature creates a limited role for use by the K8s Service principal which limits access to only those resources needed for k8s operation"
  default     = false
}

variable "kubetnetes_version" {
  type        = "string"
  description = "The k8s version to deploy eg: '1.8.5', '1.10.5' etc"
  default     = "1.10.5"
}

variable "vm_size" {
  description = "The VM_SKU to use for the agents in the cluster"
  default     = "Standard_DS2_v2"
}

variable "node_count" {
  description = "The number of agents nodes to provision in the cluster"
  default     = "3"
}

variable "linux_admin_username" {
  type        = "string"
  description = "User name for authentication to the Kubernetes linux agent virtual machines in the cluster."
  default     = "terraform"
}

variable "owner_initials" {
  type        = "string"
  description = "Resource Owner Initials."
  default     = "dks"
}