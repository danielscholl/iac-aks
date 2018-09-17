/*
.Synopsis
   Create a Virtual Network
.DESCRIPTION
   This module is responsible for creating a virtual network
   that can then be used by AKS for advanced Networking.
*/

#########################################################
# VARIABLES
#########################################################

locals {
  vnet_name = "${var.resource_group_name}-vnet"

  # subnet1_name   = "containerTier"
  # subnet1_prefix = "10.0.0.0/20"
  # nsg1_name      = "${local.vnet_name}-${local.subnet1_name}-nsg"

  # subnet2_name   = "backendTier"
  # subnet2_prefix = "10.0.16.0/24"
  # nsg2_name      = "${local.vnet_name}-${local.subnet2_name}-nsg"
}

#########################################################
# RESOURCES
#########################################################

resource "azurerm_virtual_network" "vnet" {
  # az network vnet create

  name                = "${local.vnet_name}"
  resource_group_name = "${var.resource_group_name}"
  location            = "${var.location}"
  address_space       = ["${var.address_space}"]
  dns_servers         = "${var.dns_servers}"
  tags                = "${var.tags}"
}

resource "azurerm_subnet" "subnet" {
  name                 = "${var.subnet_names[count.index]}"
  virtual_network_name = "${azurerm_virtual_network.vnet.name}"
  resource_group_name  = "${var.resource_group_name}"
  address_prefix       = "${var.subnet_prefixes[count.index]}"

  network_security_group_id = "${var.nsg_ids[count.index]}"
  count                     = "${length(var.subnet_names)}"
}

# resource "azurerm_network_security_group" "nsg1" {
#   # az network nsg create


#   name                = "${local.nsg1_name}"
#   resource_group_name = "${data.azurerm_resource_group.group.name}"
#   location            = "${data.azurerm_resource_group.group.location}"


#   security_rule {
#     name                       = "SSH"
#     priority                   = 1001
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "22"
#     source_address_prefix      = "*"
#     destination_address_prefix = "*"
#   }
# }


# resource "azurerm_subnet" "subnet1" {
#   # az network vnet subnet create


#   name                      = "${local.subnet1_name}"
#   resource_group_name       = "${data.azurerm_resource_group.group.name}"
#   virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
#   address_prefix            = "${local.subnet1_prefix}"
#   network_security_group_id = "${azurerm_network_security_group.nsg1.id}"


#   depends_on = [
#     "azurerm_network_security_group.nsg1",
#   ]
# }


# resource "azurerm_network_security_group" "nsg2" {
#   # az network nsg create


#   name                = "${local.nsg2_name}"
#   resource_group_name = "${data.azurerm_resource_group.group.name}"
#   location            = "${data.azurerm_resource_group.group.location}"


#   security_rule {
#     name                       = "SSH"
#     priority                   = 1001
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "22"
#     source_address_prefix      = "*"
#     destination_address_prefix = "*"
#   }


#   security_rule {
#     name                       = "RDP"
#     priority                   = 1002
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "3389"
#     source_address_prefix      = "*"
#     destination_address_prefix = "*"
#   }


#   security_rule {
#     name                       = "HTTP"
#     priority                   = 1003
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "80"
#     source_address_prefix      = "VirtualNetwork"
#     destination_address_prefix = "*"
#   }


#   security_rule {
#     name                       = "HTTPS"
#     priority                   = 1004
#     direction                  = "Inbound"
#     access                     = "Allow"
#     protocol                   = "Tcp"
#     source_port_range          = "*"
#     destination_port_range     = "443"
#     source_address_prefix      = "VirtualNetwork"
#     destination_address_prefix = "*"
#   }
# }


# resource "azurerm_subnet" "subnet2" {
#   # az network vnet subnet create


#   name                      = "${local.subnet2_name}"
#   resource_group_name       = "${data.azurerm_resource_group.group.name}"
#   virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
#   address_prefix            = "${local.subnet2_prefix}"
#   network_security_group_id = "${azurerm_network_security_group.nsg2.id}"


#   depends_on = [
#     "azurerm_network_security_group.nsg2",
#   ]
# }


#########################################################
# OUTPUT
#########################################################
# output "vnet_id" {
#   value = "${azurerm_virtual_network.vnet.id}"
# }


# output "subnet1_id" {
#   value = "${azurerm_subnet.subnet1.id}"
# }


# output "subnet2_id" {
#   value = "${azurerm_subnet.subnet2.id}"
# }

