# Introduction
Infrastructure as Code using ARM - Azure Kubernetes Clusters

[![Build Status](https://cloudcodeit.visualstudio.com/DemoStuff/_apis/build/status/danielscholl.iac-aks)](https://cloudcodeit.visualstudio.com/DemoStuff/_build/latest?definitionId=26)


<a href="https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fdanielscholl%2Fazure-terraform-aks%2Fmaster%2Farm%2Fazuredeploy.json" target="_blank">
    <img src="http://azuredeploy.net/deploybutton.png"/>
</a>


## Getting Started

1. Run Install Script for ARM Process

> Requires manually copying in the SSH Key that is created at this time.

```bash
# Initialize the Modules
contact="<your_initials>"
install.sh $contact
```


# Build and Test 

>NOTE:  THIS CAN ONLY BE DONE FROM A LINUX SHELL!!

1. Manually run the test suite

```bash
npm install
npm test
```

2. Manually provision the infrastructure.

```bash
# Provision the infrastructure
npm run provision
```

# Azure Pipelines

1. Build Definition

    This project uses YAML builds.  A build would typically be created automatically but if not then a new Definition can be created and then import the `.vsts-ci.yml` YAML build file.

    - Ensure that the proper Project Level Service Connection exists to be able to utilize the desired Subscription

1. Release Definition

    This project uses imported releases. A release is created with by importing the `.vsts-cd.json` file.  Some manual steps are required  to complete a valid pipeline.

    - Ensure that the proper Project Level Service Connection exists to be able to utilize the desired Subscription
    - Link the Artifact to the Build Artifact
    - Select the Build Agent `Windows Containers`
  