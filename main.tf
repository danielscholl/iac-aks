/*
.Synopsis
   Terraform Control Script
.DESCRIPTION
   This module is responsible for orechestrating the resources
   and modules needed for a sample AKS Cluster with RBAC
   and Advanced Networking enabled.
*/

provider "azurerm" {
  version = "=1.10.0"
}

locals {
  rg              = "${var.prefix}-cluster"
  vnet_name       = "${local.rg}-vnet"
  address_prefix  = "10.0.0.0/16"
  subnet1_name    = "containerTier"
  subnet1_address = "10.0.0.0/20"
  subnet2_name    = "backendTier"
  subnet2_address = "10.0.16.0/24"
  nsg1_name       = "${local.vnet_name}-${local.subnet1_name}-nsg"
  nsg2_name       = "${local.vnet_name}-${local.subnet2_name}-nsg"
}

#########################################################
# RESOURCES
#########################################################

resource "azurerm_resource_group" "rg" {
  name     = "${local.rg}"
  location = "${var.location}"
}

data "azurerm_resource_group" "passed" {
  name = "${local.rg}"

  depends_on = [
    "azurerm_resource_group.rg",
  ]
}

# resource "azurerm_role_assignment" "aks_service_principal_role_subnet" {
#   # az role assignment create

#   count                = "${var.sp_least_privilidge}"
#   scope                = "${module.virtual_network.subnet1_id}"
#   role_definition_name = "${module.service_principal.aks_role_name}"
#   principal_id         = "${module.service_principal.sp_id}"

#   depends_on = [
#     "module.service_principal",
#     "module.virtual_network",
#   ]
# }

#########################################################
# MODULES
#########################################################

module "subnet1_nsg" {
  source              = "security_group"
  resource_group_name = "${data.azurerm_resource_group.passed.name}"
  location            = "${data.azurerm_resource_group.passed.location}"
  security_group_name = "${local.nsg1_name}"

  custom_rules = [
    {
      name                   = "ssh"
      priority               = "1000"
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = "tcp"
      destination_port_range = "22"
      source_address_prefix  = ["VirtualNetwork"]
      description            = "ssh-for-vm-management"
    },
  ]

  tags = {
    environment = "dev"
    costcenter  = "it"
  }
}

module "subnet2_nsg" {
  source              = "security_group"
  resource_group_name = "${data.azurerm_resource_group.passed.name}"
  location            = "${data.azurerm_resource_group.passed.location}"
  security_group_name = "${local.nsg2_name}"

  custom_rules = [
    {
      name                   = "ssh"
      priority               = "500"
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = "tcp"
      destination_port_range = "22"
      source_address_prefix  = ["VirtualNetwork"]
      description            = "ssh-for-vm-management"
    },
    {
      name                   = "rdp"
      priority               = "501"
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = "tcp"
      destination_port_range = "3389"
      source_address_prefix  = ["VirtualNetwork"]
      description            = "rdp-for-vm-management"
    },
    {
      name                   = "http"
      priority               = "1001"
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = "tcp"
      destination_port_range = "80"
      description            = "vnet-allow-http"
    },
    {
      name                   = "https"
      priority               = "1002"
      direction              = "Inbound"
      access                 = "Allow"
      protocol               = "tcp"
      destination_port_range = "443"
      description            = "vnet-allow-https"
    },
  ]

  tags = {
    environment = "dev"
    costcenter  = "it"
  }
}

module "virtual_network" {
  source              = "virtual_network"
  resource_group_name = "${data.azurerm_resource_group.passed.name}"
  location            = "${data.azurerm_resource_group.passed.location}"
  address_space       = "${local.address_prefix}"

  subnet_names = [
    "${local.subnet1_name}",
    "${local.subnet2_name}",
  ]

  subnet_prefixes = [
    "${local.subnet1_address}",
    "${local.subnet2_address}",
  ]

  nsg_ids = [
    "${module.subnet1_nsg.network_security_group_id}",
    "${module.subnet2_nsg.network_security_group_id}",
  ]

  tags = {
    environment = "dev"
    costcenter  = "sandbox"
  }
}

# module "service_principal" {
#   source = "service_principal"

#   group               = "${azurerm_resource_group.aks_demo.name}"
#   sp_least_privilidge = "${var.sp_least_privilidge}"
# }

# module "virtual_network" {
#   source = "virtual_network"

#   group = "${azurerm_resource_group.aks_demo.name}"
# }

# module "aks_cluster" {
#   source = "aks_cluster"

#   group         = "${azurerm_resource_group.aks_demo.name}"
#   client_id     = "${module.service_principal.client_id}"
#   client_secret = "${module.service_principal.client_secret}"
# }

#########################################################
# OUTPUT
#########################################################

output "configure" {
  value = <<CONFIGURE


Run the following commands to configure kubernetes client:


$ terraform output -module aks_cluster kube_config > ~/.kube/aksconfig
$ export KUBECONFIG=~/.kube/aksconfig


Test configuration using kubectl


$ kubectl get nodes
CONFIGURE
}
