/*
.Synopsis
   Terraform Main Control
.DESCRIPTION
   This file holds the main control and resoures for the Terraform AKS Module.
*/

provider "azurerm" {
  version = "=1.10.0"
}

locals {
  unique          = "${random_integer.unique.result}"
  rg              = "${var.owner_initials}-cluster"
  sp_name         = "${var.owner_initials}-Principal"
  registry_name   = "${var.owner_initials}registry${local.unique}"
  vnet_name       = "${local.rg}-vnet"
  address_space   = "10.0.0.0/16"
  subnet1_name    = "containerTier"
  subnet1_address = "10.0.0.0/20"
  subnet2_name    = "backendTier"
  subnet2_address = "10.0.16.0/24"
  nsg1_name       = "${local.vnet_name}-${local.subnet1_name}-nsg"
  nsg2_name       = "${local.vnet_name}-${local.subnet2_name}-nsg"
  cluster_name    = "aks-${local.unique}"
  dns_ip          = "10.0.0.10"
  docker_cidr     = "172.17.0.1/16"
}


#########################################################
# RESOURCES
#########################################################

resource "random_integer" "unique" {
  # 3 Digit Random Number Generator
  min = 100
  max = 999
}

#-------------------------------
# Resource Group
#-------------------------------
resource "azurerm_resource_group" "rg" {
  name     = "${local.rg}"
  location = "${var.location}"

  tags = {
    environment = "dev"
    contact  = "${var.owner_initials}"
  }
}


#-------------------------------
# Cluster Service Principal
#-------------------------------
resource "azurerm_azuread_application" "ad_app" {
  name = "${local.sp_name}"
}
resource "azurerm_azuread_service_principal" "ad_sp" {
  application_id = "${azurerm_azuread_application.ad_app.application_id}"
}
resource "random_string" "ad_sp_password" {
  length  = 16
  special = true

  keepers = {
    service_principal = "${azurerm_azuread_service_principal.ad_sp.id}"
  }
}
resource "azurerm_azuread_service_principal_password" "ad_sp_password" {
  service_principal_id = "${azurerm_azuread_service_principal.ad_sp.id}"
  value                = "${random_string.ad_sp_password.result}"
  end_date             = "${timeadd(timestamp(), "8760h")}"

  # This stops be 'end_date' changing on each run and causing a new password to be set
  # to get the date to change here you would have to manually taint this resource...
  lifecycle {
    ignore_changes = ["end_date"]
  }
}
data "azurerm_subscription" "sub" {}  # Retrieve Azure Subscription
resource "azurerm_role_definition" "aks_sp_role_rg" {
  count       = "${var.sp_least_privilidge}"
  name        = "aks_sp_role"
  scope       = "${data.azurerm_subscription.sub.id}"
  description = "This role provides the required permissions needed by Kubernetes to: Manager VMs, Routing rules, Mount azure files and Read container repositories"

  permissions {
    actions = [
      "Microsoft.Compute/virtualMachines/read",
      "Microsoft.Compute/virtualMachines/write",
      "Microsoft.Compute/disks/write",
      "Microsoft.Compute/disks/read",
      "Microsoft.Network/loadBalancers/write",
      "Microsoft.Network/loadBalancers/read",
      "Microsoft.Network/routeTables/read",
      "Microsoft.Network/routeTables/routes/read",
      "Microsoft.Network/routeTables/routes/write",
      "Microsoft.Network/routeTables/routes/delete",
      "Microsoft.Storage/storageAccounts/fileServices/fileShare/read",
      "Microsoft.ContainerRegistry/registries/read",
      "Microsoft.Network/publicIPAddresses/read",
      "Microsoft.Network/publicIPAddresses/write",
    ]

    not_actions = [
      // Deny access to all VM actions, this includes Start, Stop, Restart, Delete, Redeploy, Login, Extensions etc
      "Microsoft.Compute/virtualMachines/*/action",
      "Microsoft.Compute/virtualMachines/extensions/*",
    ]
  }

  assignable_scopes = [
    "${data.azurerm_subscription.sub.id}",
  ]
}


#-------------------------------
# Cluster Container Registry
#-------------------------------
resource "azurerm_container_registry" "aks" {
  name                = "${local.registry_name}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  admin_enabled       = true
  sku                 = "Basic"

  tags = {
    environment = "dev"
    contact  = "${var.owner_initials}"
  }
}
resource "azurerm_role_assignment" "aks_registry" {
  scope                = "${azurerm_container_registry.aks.id}"
  role_definition_name = "Reader"
  principal_id         = "${azurerm_azuread_service_principal.ad_sp.id}"

  depends_on = [
    "azurerm_role_definition.aks_sp_role_rg",
  ]
}


#-------------------------------
# Network Security Groups
#-------------------------------
resource "azurerm_network_security_group" "nsg1" {
  name                = "${local.nsg1_name}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
    description                = "ssh-for-vm-management"
  }

  tags = {
    environment = "dev"
    contact  = "${var.owner_initials}"
  }

  depends_on = [
    "azurerm_resource_group.rg",
  ]
}

resource "azurerm_network_security_group" "nsg2" {
  name                = "${local.nsg2_name}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "ssh-for-vm-management"
  }

  security_rule {
    name                       = "RDP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
    description                = "rdp-for-vm-management"
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
    description                = "http-access-for-vnet"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 1004
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
    description                = "https-access-for-vnet"
  }

  tags = {
    environment = "dev"
    contact  = "${var.owner_initials}"
  }

  depends_on = [
    "azurerm_resource_group.rg",
  ]
}



#-------------------------------
# Virtual Network
#-------------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "${local.vnet_name}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  address_space       = [
    "${local.address_space}"
  ]
  dns_servers         = []

  tags = {
    environment = "dev"
    tsp  = "dks"
  }
}
resource "azurerm_subnet" "subnet1" {

  name                      = "${local.subnet1_name}"
  resource_group_name       = "${azurerm_resource_group.rg.name}"
  virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
  address_prefix            = "${local.subnet1_address}"
  network_security_group_id = "${azurerm_network_security_group.nsg1.id}"

  depends_on = [
    "azurerm_network_security_group.nsg1",
  ]
}
resource "azurerm_subnet" "subnet2" {
  name                      = "${local.subnet2_name}"
  resource_group_name       = "${azurerm_resource_group.rg.name}"
  virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
  address_prefix            = "${local.subnet2_address}"
  network_security_group_id = "${azurerm_network_security_group.nsg2.id}"

  depends_on = [
    "azurerm_network_security_group.nsg2",
  ]
}
resource "azurerm_role_assignment" "aks_network" {
  count                = "${var.sp_least_privilidge}"
  scope                = "${azurerm_subnet.subnet1.id}"
  role_definition_name = "Contributor"
  principal_id         = "${azurerm_azuread_service_principal.ad_sp.id}"

  depends_on = [
    "azurerm_role_definition.aks_sp_role_rg",
  ]
}


# #-------------------------------
# # SSH Keys
# #-------------------------------
resource "tls_private_key" "key" {
  algorithm = "RSA"
}
resource "null_resource" "save-key" {
  triggers {
    key = "${tls_private_key.key.private_key_pem}"
  }

  provisioner "local-exec" {
    command = <<EOF
      mkdir -p ${path.module}/.ssh
      echo "${tls_private_key.key.private_key_pem}" > ${path.module}/.ssh/id_rsa
      chmod 0600 ${path.module}/.ssh/id_rsa
EOF
  }
}


# #-------------------------------
# # AKS Cluster
# #-------------------------------
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "${local.cluster_name}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  dns_prefix          = "${local.cluster_name}"

  linux_profile {
    admin_username = "${var.linux_admin_username}"

    ssh_key {
      key_data = "${trimspace(tls_private_key.key.public_key_openssh)} ${var.linux_admin_username}@azure.com"
    }
  }

  agent_pool_profile {
    name            = "agentpool"
    count           = "${var.node_count}"
    vm_size         = "${var.vm_size}"
    os_type         = "Linux"
    os_disk_size_gb = 30

    #vnet_subnet_id = "${azurerm_subnet.subnet1.id}"
  }

  service_principal {
    client_id     = "${azurerm_azuread_service_principal.ad_sp.application_id}"
    client_secret = "${random_string.ad_sp_password.result}"
  }

  # network_profile {
  #   network_plugin     = "azure"
  #   dns_service_ip     = "${local.dns_ip}"
  #   docker_bridge_cidr = "${local.docker_cidr}"
  #   service_cidr       = "${local.address_space}"
  # }

  tags = {
    environment = "dev"
    contact  = "${var.owner_initials}"
  }

  depends_on = [
    "azurerm_azuread_service_principal.ad_sp",
    "azurerm_role_assignment.aks_network",
  ]
}