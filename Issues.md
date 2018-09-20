# Known Issues

1. CLI Instructions don't use Network Security Groups yet

1. Terraform Provider _azurerm_kubernetes_cluster_ errors out when using Advanced Networking

1. Terraform Principal Create Timeout
    
    > There may be an issue if a Service Principal is created for the first time it takes a period of time before it can be used.
    > In the AKS resource it needs the principal to be created and might error out the first time it runs.

1. Ansible Instructions not started

1. ARM process still need to assign Roles to Service Principal for Network and Container
