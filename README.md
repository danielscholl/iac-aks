# Azure Kubernetes Service (AKS)

This repository is built for the purpose of understanding how to deploy a Kubernetes Clusters with Terraform.


## Deploy the Infrastructure

__Clone the Github repository__

```bash
git clone https://github.com/danielscholl/azure-terraform-aks.git
```

__Prerequisites__

* [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) installed.

  >Assumes CLI Version = azure-cli (2.0.43)  ** Required for RBAC changes

* HashiCorp [Terraform](https://terraform.io/downloads.html) installed.

  ```bash
  export VER="0.11.8"
  wget https://releases.hashicorp.com/terraform/${VER}/terraform_${VER}_linux_amd64.zip
  unzip terraform_${VER}_linux_amd64.zip
  sudo mv terraform /usr/local/bin/
  ```

__Setup Terraform Environment Variables__

Generate Azure client id and secret.

> After creating a Service Principal you __MUST__ add API access for _Windows Azure Active Directory_ and enable the following permissions
> - Read and write all applications
> - Sign in and read user profile

```bash
# Create a Service Principal
Subscription=$(az account show --query id -otsv)
az ad sp create-for-rbac --name "Terraform-Principal" --role="Owner" --scopes="/subscriptions/$Subscription"

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

>A great tool to do this automatically with is [direnv](https://direnv.net/).

```bash
export ARM_SUBSCRIPTION_ID="YOUR_SUBSCRIPTION_ID"
export ARM_TENANT_ID="TENANT_ID"
export ARM_CLIENT_ID="CLIENT_ID"
export ARM_CLIENT_SECRET="CLIENT_SECRET"
export TF_VAR_client_id=${ARM_CLIENT_ID}
export TF_VAR_client_secret=${ARM_CLIENT_SECRET}
```

__Run Terraform init and plan.__

```bash
# Provision the infrastructure
terraform init
terraform plan
terraform apply
```

__Pull the Configuration Credentials and Validate the Cluster.__

```bash
# or pull the credential context
ResourceGroup="demo-cluster"
Cluster=$(az aks list -g $ResourceGroup --query [].name -otsv)
az aks get-credentials -n $Cluster -g $ResourceGroup 

# Validate the cluster
kubectl get nodes
kubectl get pods --all-namespaces
```


## Deploy a Sample Application to the Cluster

Build the docker images and push it to the private registry and deploy a k8s manifest.


__Build the application__

> Follow this process to build using Azure. (ie: cloudshell)

```bash
# Move to the directory where the source code exists
cd src/azure-vote

# Set the variable to your resource group where ACR exists.
ResourceGroup="demo-cluster"

# Retrieve the Registry Name
Registry=$(az acr list -g $ResourceGroup --query [].name -otsv)

# Build and push the Image
az acr build --registry $Registry --image azure-vote-front .
```

__Build the application using Docker__

> Follow this process to build using docker.

```bash
# Set the variable to your resource group where ACR exists.
ResourceGroup="demo-cluster"

# Login to the Registry
Registry=$(az acr list -g $ResourceGroup --query [].name -otsv)
az acr login -g $ResourceGroup -n $Registry

# Get the FQDN to be used
RegistryServer=$(az acr show -g $RegistryGroup -n $Registry --query loginServer -otsv)

# Create a Compose File for the App
cat > docker-compose.yaml <<EOF
version: '3'
services:

  azure-vote-back:
    image: redis
    container_name: azure-vote-back
    ports:
        - "6379:6379"

  azure-vote-front:
    build: ./src/azure-vote
    image: ${RegistryServer}/azure-vote-front
    container_name: azure-vote-front
    environment:
      REDIS: azure-vote-back
    ports:
        - "8080:80"
EOF


# Build and push the Docker Images
docker-compose build
docker-compose push
```


__Deploy the application__

```bash
# Retrieve the Registry Server FQDN
RegistryServer=$(az acr show -g $ResourceGroup -n $Registry --query loginServer -otsv)

# Create a k8s manifest file for the App
cat > deployment.yaml <<EOF
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
        image: ${RegistryServer}/azure-vote-front
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
EOF
```


__Deploy the Application__

```bash
kubectl apply -f deployment.yaml
kubectl get service azure-vote-front --watch  # Wait for the External IP to come live


# Set the variable to your resource group where ACR exists.
ResourceGroup="demo-cluster"
Cluster=$(az aks list -g $ResourceGroup --query [].name -otsv)

# Open the dashboard
az aks browse -n $Cluster -g $ResourceGroup 
```





## Detailed CLI vs Terraform Comparison

### Create a Resource Group
This resource group will be used to hold all our resources

__*CLI Commands*__
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


__*Terraform Resources*__
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

__*CLI Commands*__
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


__*Terraform Resources*__
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

  lifecycle {
    ignore_changes = ["end_date"]
  }
}
```




### Create a Container Registry

The private Container Registry hosts images to be used by the cluster.

__*CLI Commands*__
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
az acr login \
  --name $Registry
```

__*Terraform Resources*__
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

__*CLI Commands*__
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
SubnetId=$(az network vnet subnet show \
  --resource-group $ResourceGroup \
  --vnet-name $VNet \
  --name ContainerTier \
  --query id -otsv)

az role assignment create \
  --assignee $PrincipalId \
  --scope $SubnetId \
  --role Contributor
```


__*Terraform Resources*__
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
  rg              = "${var.prefix}-cluster"
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


### Create a Managed Kubernetes Cluster (AKS)

The managed kubernetes cluster to be created.

__*CLI Commands*__
```bash
NodeSize="Standard_D3_v2"
Cluster="aks-${Unique}"
DockerBridgeCidr="172.17.0.1/16"
ServiceCidr="10.3.0.0/24"
DNSServiceIP="10.3.0.10"

# Create the Cluster
az aks create --name $Cluster \
  --resource-group $ResourceGroup \
  --location $Location \
  --generate-ssh-keys \
  --node-vm-size $NodeSize \
  --node-count 1 \
  --service-principal $PrincipalId \
  --client-secret $PrincipalSecret \
  --disable-rbac \
  --network-plugin azure \
  --docker-bridge-address $DockerBridgeCidr \
  --service-cidr $ServiceCidr \
  --dns-service-ip $DNSServiceIP \
  --vnet-subnet-id $SubnetId \
  --enable-addons http_application_routing

# Pull the cluster admin context
az aks get-credentials --name $Cluster \
  --resource-group $ResourceGroup \
  --admin

# Validate the cluster
kubectl get nodes
kubectl get pods --all-namespaces
```


__*Terraform Resources*__
```
provider "azurerm" {
  version = "=1.10.0"
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

locals {
  cluster_name = "aks-${local.unique}"
}

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
    vnet_subnet_id = "${azurerm_subnet.subnet1.id}"
  }

  service_principal {
    client_id     = "${azurerm_azuread_service_principal.ad_sp.application_id}"
    client_secret = "${random_string.ad_sp_password.result}"
  }

  network_profile {
    network_plugin = "azure"
  }

  tags = {
    environment = "dev"
    contact  = "${var.owner_initials}"
  }

  depends_on = [
    "azurerm_azuread_service_principal.ad_sp",
    "azurerm_role_assignment.aks_network",
  ]
}
```



