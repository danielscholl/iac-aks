# Azure Kubernetes Service (AKS)

This repository is built for the purpose of understanding how to deploy a Kubernetes Clusters in different manners.

_[Issue Tracking](https://github.com/danielscholl/azure-terraform-aks/blob/master/Issues.md)_

__Clone the Github repository__

```bash
git clone https://github.com/danielscholl/azure-terraform-aks.git
```

__Deploy Infrastructure__

1. __[Azure CLI](https://github.com/danielscholl/azure-terraform-aks/blob/master/cli/README.md)__

1. __[Terraform Sample](https://github.com/danielscholl/azure-terraform-aks/blob/master/terraform/README.md)__

1. __[Resource Manager](https://github.com/danielscholl/azure-terraform-aks/blob/master/arm/README.md)__

1. __[Ansible](https://github.com/danielscholl/azure-terraform-aks/blob/master/ansible/README.md)__


> [Compare](https://github.com/danielscholl/azure-terraform-aks/blob/master/Terraform-CLI.md) CLI vs Terraform.

__Deploy a Sample Application to the Cluster__

1. Ensure the proper AKS Credentials have been retrieved

```bash
ResourceGroup="<your_resource_group>"
Cluster="<your_cluster>"
# Pull the cluster admin context
az aks get-credentials --name <your_cluster> \
  --resource-group $ResourceGroup \
  --admin

# Validate the cluster
kubectl get nodes
kubectl get pods --all-namespaces

```

1. Build the Docker Images and Deploy using the Azure CLI

```bash
## Ensure kubectl is using the appropriate configuration!!
#--------------------------------------------------------

ResourceGroup="<your_resource_group>"
deploy.sh $ResourceGroup

# Watch to see the app come alive
kubectl get service azure-vote-front --watch
```

2. Build and Deploy a Sample Application using Docker

_Build the application_

```bash
## Ensure kubectl is using the appropriate configuration!!
#--------------------------------------------------------

# Set the variable to your resource group where ACR exists.
ResourceGroup="<your_resource_group>"

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


_Deploy the application_

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

kubectl apply -f deployment.yaml
kubectl get service azure-vote-front --watch  # Wait for the External IP to come live


# Set the variable to your resource group where ACR exists.
ResourceGroup="demo-cluster"
Cluster=$(az aks list -g $ResourceGroup --query [].name -otsv)

# Open the dashboard
az aks browse -n $Cluster -g $ResourceGroup 
```