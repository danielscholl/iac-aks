# Introduction
Infrastructure as Code using CLI - Azure Kubernetes Clusters

## Getting Started

1. Create a Resource Group

```bash
Prefix="demo"
ResourceGroup="$Prefix-cluster"
Location="eastus"

# Create a resource group.
az group create \
  --name $ResourceGroup \
  --location $Location

# Get Unique ID
Unique=$(cat /dev/urandom | tr -dc '0-9' | fold -w 256 | head -n 1 | sed -e 's/^0*//' | head --bytes 3)
```

2. Create a Service Principal

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

3. Create a Container Registry

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

4. Create a Virtual Network

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

4. Create a Managed Kubernetes Cluster (AKS)

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