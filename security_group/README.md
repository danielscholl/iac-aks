# Create a Network Security Group in Azure

This Terraform module deploys a Network Security Group (NSG) in Azure and optionally attach it to the specified vnets.

## Usage

```bash
module "network-security-group" {
    source              = "security_group"
    resource_group_name = "my-terraform-test"
    security_group_name        = "nsg"
    custom_rules               = [
      {
        name                   = "ssh"
        priority               = "200"
        direction              = "Inbound"
        access                 = "Allow"
        protocol               = "tcp"
        destination_port_range = "22"
        source_address_prefix  = ["VirtualNetwork"]
        description            = "ssh-for-vm-management"
      }
    ]
    tags                       = {
                                  environment = "dev"
                                  costcenter  = "it"
                                 }
}
```
