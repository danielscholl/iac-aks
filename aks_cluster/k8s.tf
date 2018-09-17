/*
.Synopsis
   Create a Kubernetes Cluster and Registry.
.DESCRIPTION
   This module is responsible for creating a container registry
   and the AKS cluster.
*/

#########################################################
# VARIABLES
#########################################################

variable "group" {}
variable "client_id" {}
variable "client_secret" {}

locals {
  unique       = "${random_integer.unique.result}"
  cluster_name = "aks-${local.unique}"
}

data "azurerm_resource_group" "group" {
  name = "${var.group}"
}

#########################################################
# RESOURCES
#########################################################

resource "random_integer" "unique" {
  # 3 Digit Random Number Generator
  min = 100
  max = 999
}

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

resource "azurerm_kubernetes_cluster" "cluster" {
  # az aks create

  name                = "${local.cluster_name}"
  resource_group_name = "${data.azurerm_resource_group.group.name}"
  location            = "${data.azurerm_resource_group.group.location}"
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
  }

  service_principal {
    client_id     = "${var.client_id}"
    client_secret = "${var.client_secret}"
  }

  tags {
    Environment = "Production"
  }
}

#########################################################
# OUTPUT
#########################################################
output "id" {
  value = "${azurerm_kubernetes_cluster.cluster.id}"
}

output "client_key" {
  value = "${azurerm_kubernetes_cluster.cluster.kube_config.0.client_key}"
}

output "client_certificate" {
  value = "${azurerm_kubernetes_cluster.cluster.kube_config.0.client_certificate}"
}

output "cluster_ca_certificate" {
  value = "${azurerm_kubernetes_cluster.cluster.kube_config.0.cluster_ca_certificate}"
}

output "kube_config" {
  value = "${azurerm_kubernetes_cluster.cluster.kube_config_raw}"
}

output "host" {
  value = "${azurerm_kubernetes_cluster.cluster.kube_config.0.host}"
}
