#!/bin/bash

if [ ! -z $1 ]; then ResourceGroup=$1; fi

# Go into the Source Folder and Build the Image
cd src/azure-vote
Registry=$(az acr list -g $ResourceGroup --query [].name -otsv)
az acr build --registry $Registry --image azure-vote-front .
cd ../..

# Go into the Source Folder and Build the Image

RegistryServer=$(az acr show -g $ResourceGroup -n $Registry --query loginServer -otsv)

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


echo 'kubectl get service azure-vote-front --watch'