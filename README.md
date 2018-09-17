# Azure Kubernetes Service (AKS)

This repository is for the purpose of understanding how to deploy a Kubernetes Cluster with Terraform.

__Clone the Github repository__

```bash
git clone https://github.com/danielscholl/azure-terraform-aks.git
```

__Prerequisites__

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) installed.

  >Note: Assumes CLI Version = azure-cli (2.0.43)  ** Required for RBAC changes

* HashiCorp [Terraform](https://terraform.io/downloads.html) installed.

  _For Linux_
  ```bash
  export VER="0.11.8"
  wget https://releases.hashicorp.com/terraform/${VER}/terraform_${VER}_linux_amd64.zip
  unzip terraform_${VER}_linux_amd64.zip
  sudo mv terraform /usr/local/bin/
  ```

__Setup Terraform Environment Variables__

Generate Azure client id and secret.

> Note: After creating a Service Principal you __MUST__ add API access for _Windows Azure Active Directory_ and enable the following permissions
> - Read and write all applications
> - Sing in and read user profile

```bash
# Create a Service Principal

Subscription=$(az account show --query id -otsv)
az ad sp create-for-rbac --name "Terraform-Principal" --role="Contributor" --scopes="/subscriptions/$Subscription"

# Expected Result

{
  "appId": "00000000-0000-0000-0000-000000000000",
  "displayName": "Terraform-Principal",
  "name": "http://Terraform-Principal",
  "password": "0000-0000-0000-0000-000000000000",
  "tenant": "00000000-0000-0000-0000-000000000000"
}
```

`appId` -> Client id.
`password` -> Client secret.
`tenant` -> Tenant id.

Export environment variables to configure the [Azure](https://www.terraform.io/docs/providers/azurerm/index.html) Terraform provider.

>Note: A great tool to do this automatically with is [direnv](https://direnv.net/).

```bash
export ARM_SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"
export ARM_TENANT_ID="TENANT_ID"
export ARM_CLIENT_ID="CLIENT_ID"
export ARM_CLIENT_SECRET="CLIENT_SECRET"
export TF_VAR_client_id=${ARM_CLIENT_ID}
export TF_VAR_client_secret=${ARM_CLIENT_SECRET}
```


## Deploy using Terraform

Run Terraform init and plan.

```bash
# Run the following terraform commands.

$ terraform init
$ terraform plan
$ terraform apply
```




## Detailed Breakdown Instructions

### Create a Resource Group
This resource group will be used to hold all our resources

__*Manual CLI Commands*__
```bash
Prefix="my"
ResourceGroup="$Prefix-cluster"
Location="eastus"

# Create a resource group.
az group create \
  --name $ResourceGroup \
  --location $Location

# Get Unique ID
Unique=$(cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | sed -e 's/^0*//' | head --bytes 3)
```


__*Terraform Resource Sample*__
```
provider "azurerm" {
  version = "=1.10.0"
}

variable "prefix" {
  type        = "string"
  description = "Unique Prefix."
}

variable "location" {
  type        = "string"
  description = "Location for the resource groups."
  default     = "eastus"
}

locals {
  rg          = "${var.prefix}-cluster"
}

resource "azurerm_resource_group" "rg" {
  name     = "${local.rg}"
  location = "${var.location}"
}
```





### Create a Service Principal

The Service Principal is used by the cluster to control access to Azure Resources such as registry and Network.

__*Manual CLI Commands*__
```bash
PrincipalName="$Prefix-Principal"

PrincipalSecret=$(az ad sp create-for-rbac \
                  --name $PrincipalName \
                  --skip-assignment \
                  --query password -otsv)

PrincipalId=$(az ad sp list \
              --display-name $PrincipalName \
              --query [].appId -otsv)
```


__*Terraform Resource Sample*__
```
provider "azurerm" {
  version = "=1.10.0"
}

variable "prefix" {
  type        = "string"
  description = "Unique Prefix."
}

locals {
  sp_name = "${var.prefix}-Principal"
}

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
```




### Create a Container Registry

The private Container Registry hosts images to be used by the cluster.

__*Manual CLI Commands*__
```bash
Registry="${Prefix}registry${Unique}"

# Create the Registry
RegistryServer=$(az acr create \
                --name $Registry \
                --resource-group $ResourceGroup \
                --sku Basic \
                --query loginServer -otsv)

RegistryId=$(az acr show \
            --name $Registry \
            --resource-group $ResourceGroup \
            --query id -otsv)

# Grant Service Principal Read Access to the Registry
## CLI USER MUST HAVE OWNER RIGHTS ON THE SUBSCRIPTION TO DO THIS
az role assignment create \
  --assignee $PrincipalId \
  --scope $RegistryId \
  --role Reader

# Login to the Registry
az acr login `
  --name $Registry
```

__*Terraform Resource Sample*__
```
provider "azurerm" {
  version = "=1.10.0"
}

variable "prefix" {
  type        = "string"
  description = "Unique Prefix."
}

variable "sp_least_privilidge" {
  description = "K8s Service Principle Limited Role Feature"
  default     = false
}

locals {
  unique          = "${random_integer.unique.result}"
  registry_name   = "${var.prefix}registry${local.unique}"
}

resource "random_integer" "unique" {
  # 3 Digit Random Number Generator
  min = 100
  max = 999
}

resource "azurerm_container_registry" "aks" {
  name                = "${local.registry_name}"
  resource_group_name = "${azurerm_resource_group.rg.name}"
  location            = "${azurerm_resource_group.rg.location}"
  admin_enabled       = true
  sku                 = "Basic"
}

resource "azurerm_role_assignment" "aks_registry" {

  count                = "${var.sp_least_privilidge}"
  scope                = "${azurerm_container_registry.aks.primary.id}"
  role_definition_name = "aks_sp_role}"
  principal_id         = "${azurerm_azuread_service_principal.ad_sp.id}"

  depends_on = [
    "azurerm_role_definition.aks_sp_role_rg",
  ]
}
```



### Create a Virtual Network

The virtual network to be used by the Cluster for Advanced Networking.

__*Manual CLI Commands*__
```bash
#
# - Azure VNET can be as large as /8 but a cluster may only have 16,000 configured IP addresses
# - Subnet must be large enough to accomodate the nodes, pods, and all k8s and Azure resources
#  that might be provisioned in the cluster.  ie: Load Balancer(s)
#
#  (number of nodes) + (number of nodes * pods per node)
#         (3)        +                (3*30)  = 93 IP Addresses
#>

# Create a virtual network with a Container subnet.
VNet="$ResourceGroup-vnet"
AddressPrefix="10.0.0.0/16"    # 65,536 Addresses
ContainerTier="10.0.0.0/20"    # 4,096  Addresses

az network vnet create \
    --name $VNet \
    --resource-group $ResourceGroup \
    --location $Location \
    --address-prefix $AddressPrefix \
    --subnet-name ContainerTier \
    --subnet-prefix $ContainerTier


# Create a virtual network with a Backend subnet.
BackendTier="10.0.16.0/24"      # 254 Addresses

az network vnet subnet create \
    --name BackendTier \
    --address-prefix $BackendTier \
    --resource-group $ResourceGroup \
    --vnet-name $VNet

#
# - ServiceCidr must be smaller then /12 and not used by any network element nor connected to VNET
# - DNSServiceIP used by kube-dns  typically .10 in the ServiceCIDR range.
# - DockerBridgeCidr used as the docker bridge IP address on nodes.  Default is typically used.

#  MAX PODS PER NODE for advanced networking is 30!!
#

# Allow Service Principal Owner Access to the Network
$SubnetId=$(az network vnet subnet show `
  --resource-group $ResourceGroup `
  --vnet-name $VNet `
  --name ContainerTier `
  --query id -otsv)

az role assignment create `
  --assignee $PrincipalId `
  --scope $SubnetId `
  --role Contributor
```


__*Terraform Resource Sample*__
```
provider "azurerm" {
  version = "=1.10.0"
}

variable "prefix" {
  type        = "string"
  description = "Unique Prefix."
}

variable "sp_least_privilidge" {
  description = "K8s Service Principle Limited Role Feature"
  default     = false
}

locals {
  vnet_name       = "${local.rg}-vnet"
  address_space   = "10.0.0.0/16"
  subnet1_name    = "containerTier"
  subnet1_address = "10.0.0.0/20"
  subnet2_name    = "backendTier"
  subnet2_address = "10.0.16.0/24"
}

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
    costcenter  = "it"
  }
}

resource "azurerm_subnet" "subnet1" {

  name                      = "${local.subnet1_name}"
  resource_group_name       = "${azurerm_resource_group.rg.name}"
  virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
  address_prefix            = "${local.subnet1_address}"
}

resource "azurerm_subnet" "subnet2" {

  name                      = "${local.subnet2_name}"
  resource_group_name       = "${azurerm_resource_group.rg.name}"
  virtual_network_name      = "${azurerm_virtual_network.vnet.name}"
  address_prefix            = "${local.subnet2_address}"
}

resource "azurerm_role_assignment" "aks_network" {

  count                = "${var.sp_least_privilidge}"
  scope                = "${azurerm_subnet.subnet1.id}"
  role_definition_name = "aks_sp_role}"
  principal_id         = "${azurerm_azuread_service_principal.ad_sp.id}"

  depends_on = [
    "azurerm_role_definition.aks_sp_role_rg",
  ]
}
```








### Containerize and push an application to the registry

_Download an application, build the docker images, push it to the private registry then deploy a k8s manifest._

```powershell
# Clone a Sample Application
git clone https://github.com/Azure-Samples/azure-voting-app-redis.git src

# Create a Compose File for the App
@"
version: '3'
services:

  azure-vote-back:
    image: redis
    container_name: azure-vote-back
    ports:
        - "6379:6379"

  azure-vote-front:
    build: ./src/azure-vote
    image: $RegistryServer/azure-vote-front
    container_name: azure-vote-front
    environment:
      REDIS: azure-vote-back
    ports:
        - "8080:80"
"@ | Out-file docker-compose.yaml

# Build and push the Docker Images
docker-compose build
docker-compose push

# Create a k8s manifest file for the Ap;p
@"
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: azure-vote-back
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: azure-vote-back
    spec:
      containers:
      - name: azure-vote-back
        image: redis
        ports:
        - containerPort: 6379
          name: redis
---
apiVersion: v1
kind: Service
metadata:
  name: azure-vote-back
spec:
  ports:
  - port: 6379
  selector:
    app: azure-vote-back
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: azure-vote-front
spec:
  replicas: 1
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  minReadySeconds: 5
  template:
    metadata:
      labels:
        app: azure-vote-front
    spec:
      containers:
      - name: azure-vote-front
        image: $RegistryServer/azure-vote-front
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 250m
          limits:
            cpu: 500m
        env:
        - name: REDIS
          value: "azure-vote-back"
---
apiVersion: v1
kind: Service
metadata:
  name: azure-vote-front
spec:
  type: LoadBalancer
  ports:
  - port: 80
  selector:
    app: azure-vote-front
"@ | Out-file deployment.yaml
```




### Create a Kubernetes Cluster


#### Option A -- _Create a Basic Kubernetes Cluster_

_This is a bare bones kubernetes cluster with an application deployed and has RBAC enabled by default._


>Note: A Basic Kubernetes Cluster has RBAC enabled by default.
>[Burstable](https://azure.microsoft.com/en-us/blog/introducing-burstable-vm-support-in-aks/) machine types are great for saving money on non-prod clusters.

```powershell
$Cluster="k8s-cluster"
$NodeSize="Standard_B2s"

# Create the Registry
az aks create `
  --name $Cluster `
  --resource-group $ResourceGroup `
  --location $Location `
  --generate-ssh-keys `
  --node-vm-size $NodeSize `
  --node-count 1 `
  --service-principal $PrincipalId `
  --client-secret $PrincipalSecret

# Pull the credential context
az aks get-credentials `
  --name $Cluster `
  --resource-group $ResourceGroup

# Validate the cluster
kubectl get nodes
kubectl get pods --all-namespaces

# Deploy to the cluster
kubectl apply -f deployment.yaml
kubectl get service azure-vote-front --watch  # Wait for the External IP to come live

# Expand the dashboard access rights
kubectl create clusterrolebinding kubernetes-dashboard `
  -n default `
  --clusterrole=cluster-admin `
  --serviceaccount=kube-system:kubernetes-dashboard

# Open the dashboard
az aks browse `
  --name $Cluster `
  --resource-group $ResourceGroup

# ---------------------------------- #
#  THIS IS NOT WORKING RIGHT NOW!!!  #
# ---------------------------------- #

# Alternately Enable Token Login Access for Dashboard **More Secure  (No Access via Dashboard to Pods)

# Create a Dashboard Service Account
kubectl create serviceaccount dashboard -n default
kubectl create clusterrolebinding dashboard-admin -n default --clusterrole=cluster-admin --serviceaccount=default:dashboard

# Startup the Dashboard Proxy and open the dashboard login
Start-Process kubectl proxy
Start http://localhost:8001/api/v1/namespaces/kube-system/services/kubernetes-dashboard/proxy/#!/login


# Get a Login Token and Copy it to clipboard
$data = kubectl get secret $(kubectl get serviceaccount dashboard -o jsonpath="{.secrets[0].name}") -o jsonpath="{.data.token}"
[System.Text.Encoding]::ASCII.GetString([System.Convert]::FromBase64String($data)) | clip
```



#### Option B -- _Create a Kubernetes Cluster with RBAC AAD integration_

_Create a .env.ps1 file with the following settings as defined in the Tutorial Document_

[https://docs.microsoft.com/en-us/azure/aks/aad-integration](https://docs.microsoft.com/en-us/azure/aks/aad-integration)


>NOTE: Track the Open Issue:  [RBAC AAD access error](https://github.com/Azure/AKS/issues/478)

1. Follow the instructions "VERY" carefully.
2. Ensure you select Grant Permissions on both the Server Principal and the Client Principal
3. Only "Member" users will be supported and not "Guest" users


_Create a private environment file_

```powershell
## Sample Environment File  (.env.ps1)
$Env:AZURE_AKSAADServerId = ""         # Desired Service Principal Server Id
$Env:AZURE_AKSAADServerSecret = ""     # Desired Service Princiapl Server Key
$Env:AZURE_AKSAADClientId = ""         # Desired Service Princiapl Client Id
$Env:AZURE_TENANT = ""                 # Desired Tenant Id
```

_Deploy and validate the Kubernetes Cluster_

```powershell
$Cluster="k8s-cluster-aad"
$NodeSize="Standard_B2s"

# Source the Private Environment File
. ./.env.ps1

# Create the Cluster
az aks create `
  --name $Cluster `
  --resource-group $ResourceGroup `
  --location $Location `
  --generate-ssh-keys `
  --node-vm-size $NodeSize `
  --node-count 1 `
  --service-principal $PrincipalId `
  --client-secret $PrincipalSecret `
  --aad-server-app-id $env:AZURE_AKSAADServerId  `
  --aad-server-app-secret $env:AZURE_AKSAADServerSecret  `
  --aad-client-app-id $env:AZURE_AKSAADClientId  `
  --aad-tenant-id $env:AZURE_TENANT

# Pull the cluster admin context
az aks get-credentials `
  --name $Cluster `
  --resource-group $ResourceGroup `
  --admin

# Give the k8s dashboard Admin Rights by expanding the service account authorization
kubectl create clusterrolebinding kubernetes-dashboard `
    -n default `
    --clusterrole=cluster-admin `
    --serviceaccount=kube-system:kubernetes-dashboard

# AD User Assignment
kubectl create -f aduser-cluster-admin.yaml
kubectl create -f cluster-admin-group.yaml


# Pull the cluster context
az aks get-credentials `
  --name $Cluster `
  --resource-group $ResourceGroup

# Excercise commands
kubectl get pods --all-namespaces   # Allowed for the user
kubectl get nodes                   # Rejected by the user

# Deploy the application to the cluster
kubectl apply -f deployment.yaml
kubectl get service azure-vote-front --watch  # Wait for the External IP to come live

# Open the dashboard
az aks browse `
  --name $Cluster `
  --resource-group $ResourceGroup
```



#### Option C -- _Create an Advanced Network Kubernetes Cluster_

_Create a Virtual Network_

```powershell
<#
- Azure VNET can be as large as /8 but a cluster may only have 16,000 configured IP addresses
- Subnet must be large enough to accomodate the nodes, pods, and all k8s and Azure resources
  that might be provisioned in the cluster.  ie: Load Balancer(s)

  (number of nodes) + (number of nodes * pods per node)
         (3)        +                (3*30)  = 93 IP Addresses
#>

# Create a virtual network with a Container subnet.
$VNet="k8s-vnet"
$AddressPrefix="10.0.0.0/16"    # 65,536 Addresses
$ContainerTier="10.0.0.0/20"    # 4,096  Addresses

az network vnet create `
    --name $VNet `
    --resource-group $ResourceGroup `
    --location $Location `
    --address-prefix $AddressPrefix `
    --subnet-name ContainerTier `
    --subnet-prefix $ContainerTier


# Create a virtual network with a Backend subnet.
$BackendTier="10.0.16.0/24"      # 254 Addresses

az network vnet subnet create `
    --name BackendTier `
    --address-prefix $BackendTier `
    --resource-group $ResourceGroup `
    --vnet-name $VNet

<#
- ServiceCidr must be smaller then /12 and not used by any network element nor connected to VNET
- DNSServiceIP used by kube-dns  typically .10 in the ServiceCIDR range.
- DockerBridgeCidr used as the docker bridge IP address on nodes.  Default is typically used.

MAX PODS PER NODE for advanced networking is 30!!
#>

# Allow Service Principal Owner Access to the Network
$SubnetId=$(az network vnet subnet show `
  --resource-group $ResourceGroup `
  --vnet-name $VNet `
  --name ContainerTier `
  --query id -otsv)

az role assignment create `
  --assignee $PrincipalId `
  --scope $SubnetId `
  --role Contributor
```

_Create the integrated Cluster_

```powershell
$NodeSize="Standard_D3_v2"
$Cluster="k8s-cluster-network"
$DockerBridgeCidr="172.17.0.1/16"
$ServiceCidr="10.3.0.0/24"
$DNSServiceIP="10.3.0.10"

# Create the Cluster
az aks create --name $Cluster `
    --resource-group $ResourceGroup `
    --location $Location `
    --generate-ssh-keys `
    --node-vm-size $NodeSize `
    --node-count 1 `
    --service-principal $PrincipalId `
    --client-secret $PrincipalSecret `
    --disable-rbac `
    --network-plugin azure `
    --docker-bridge-address $DockerBridgeCidr `
    --service-cidr $ServiceCidr `
    --dns-service-ip $DNSServiceIP `
    --vnet-subnet-id $SubnetId `
    --enable-addons http_application_routing

# Pull the cluster admin context
az aks get-credentials --resource-group $ResourceGroup --name $Cluster --admin

# Deploy an internal Load Balancer
@"
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: azure-vote-back
spec:
  replicas: 1
  template:
    metadata:
      labels:
        app: azure-vote-back
    spec:
      containers:
      - name: azure-vote-back
        image: redis
        ports:
        - containerPort: 6379
          name: redis
---
apiVersion: v1
kind: Service
metadata:
  name: azure-vote-back
spec:
  ports:
  - port: 6379
  selector:
    app: azure-vote-back
---
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: azure-vote-front
spec:
  replicas: 1
  strategy:
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 1
  minReadySeconds: 5
  template:
    metadata:
      labels:
        app: azure-vote-front
    spec:
      containers:
      - name: azure-vote-front
        image: registrymmpknpadipove.azurecr.io/azure-vote-front
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 250m
          limits:
            cpu: 500m
        env:
        - name: REDIS
          value: "azure-vote-back"
---
apiVersion: v1
kind: Service
metadata:
  name: azure-vote-front
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-internal: "true"
spec:
  type: LoadBalancer
  ports:
  - port: 80
  selector:
    app: azure-vote-front
"@ | Out-file deployment.yaml

# Deploy it to the cluster
kubectl apply -f deployment.yaml
kubectl get service azure-vote-front --watch  # Wait for the External IP to come live

az aks browse --resource-group $ResourceGroup --name $Cluster  # Open the dashboard
```




## Azure Terraform provider

### Prerequisites

* HashiCorp [Terraform](https://terraform.io/downloads.html) installed.

### Tutorial

Generate Azure client id and secret.

>Note: This is assumed performing with a bash shell.

```bash
# Create a Service Principal

$ $Subscription=$(az account show --query id -otsv)
$ az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/$Subscription"

# Expected Result

{
  "appId": "00000000-0000-0000-0000-000000000000",
  "displayName": "azure-cli-2017-06-05-10-41-15",
  "name": "http://azure-cli-2017-06-05-10-41-15",
  "password": "0000-0000-0000-0000-000000000000",
  "tenant": "00000000-0000-0000-0000-000000000000"
}
```

`appId` - Client id.
`password` - Client secret.
`tenant` - Tenant id.

Export environment variables to configure the [Azure](https://www.terraform.io/docs/providers/azurerm/index.html) Terraform provider.

>Note: A great tool to do this automatically with is [direnv](https://direnv.net/).

```bash
export ARM_SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"
export ARM_TENANT_ID="TENANT_ID"
export ARM_CLIENT_ID="CLIENT_ID"
export ARM_CLIENT_SECRET="CLIENT_SECRET"
export TF_VAR_client_id=${ARM_CLIENT_ID}
export TF_VAR_client_secret=${ARM_CLIENT_SECRET}
```

Run Terraform init and plan.

```bash
# Run the following terraform commands.

$ terraform init
$ terraform plan
$ terraform apply
```

> *Creating an Azure AKS cluster can take up to 15 minutes.*

Configure kubeconfig

Instructions can be obtained by running the following command

```bash
$ terraform output configure

# Run the following commands to configure kubernetes client:

$ terraform output -module=aks_cluster kube_config > ~/.kube/aksconfig
$ export KUBECONFIG=~/.kube/aksconfig

# Test configuration using kubectl

$ kubectl get nodes
```

Save kubernetes config file to `~/.kube/aksconfig`

```bash
terraform output kube_config > ~/.kube/aksconfig
```

Set `KUBECONFIG` environment variable to the kubernetes config file

```bash
export KUBECONFIG=~/.kube/aksconfig
```

Test configuration.

```bash
kubectl get nodes
```

```bash
NAME                     STATUS    ROLES     AGE       VERSION
aks-default-75135322-0   Ready     agent     23m       v1.9.6
aks-default-75135322-1   Ready     agent     23m       v1.9.6
aks-default-75135322-2   Ready     agent     23m       v1.9.6
```
