# Create a 2 Tier Network in Azure

This Terraform modules deploys a Virtual Network in Azure with 2 subnets and specific security rules on the subnet.

## Usage

```bash
module "virtual-network" {
    source              = "virtual_network"
    resource_group_name = "my-terraform-test"
    address_space       = "10.0.0.0/16"
    subnet_prefixes     = ["10.0.0.0/20", "10.0.16.0/24"]
    subnet_names        = ["containertier", "backendtier"]

    tags                = {
                            environment = "dev"
                            costcenter  = "sandbox"
                          }
}
```
