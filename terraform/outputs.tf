/*
.Synopsis
   Terraform Output
.DESCRIPTION
   This file holds the outputs for the Terraform AKS Module.
*/


#########################################################
# OUTPUT
#########################################################

# output "kube_config" {
#   value = "${azurerm_kubernetes_cluster.aks.kube_config_raw}"
# }
# output "host" {
#   value = "${azurerm_kubernetes_cluster.aks.kube_config.0.host}"
# }
output "configure" {
  value = <<CONFIGURE

---------------------------------------------------------
Run the following commands to configure kubernetes client:

$ ResourceGroup="${local.rg}"
$ Cluster=$(az aks list -g $ResourceGroup --query [].name -otsv)
$ az aks get-credentials -n $Cluster -g $ResourceGroup 

Test configuration using kubectl


$ kubectl get nodes
$ kubectl get pods --all-namespaces
CONFIGURE
}