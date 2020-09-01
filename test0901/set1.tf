#resource Group
variable "resource_group_name" {
 description = "The name of the resource group in which the resources will be created"
 default     = "user02rg"
}


# resource "azurerm_resource_group" "user02rg" {
#     name     = var.resource_group_name
#     location = "koreacentral"

#     tags = {
#         environment = "Terraform Demo"
#     }
# }


resource "random_string" "fqdn" {
 length  = 6
 special = false
 upper   = false
 number  = false
}

resource "random_id" "randomId" {
keepers = {
# Generate a new ID only when a new resource group is defined
resource_group = var.resource_group_name
}
byte_length = 8
}


resource "azurerm_storage_account" "mystorageaccount" {
name = "diag${random_id.randomId.hex}"
resource_group_name = var.resource_group_name
location = "koreacentral"
account_replication_type = "LRS"
account_tier = "Standard"

}


#Vnet, subnet
resource "azurerm_virtual_network" "zone1" {
name = "Vnetzone1"
address_space = ["2.0.0.0/16"]
location = "koreacentral"
resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "zone1" {
name = "subnetzone1"
resource_group_name = var.resource_group_name
virtual_network_name = azurerm_virtual_network.zone1.name
address_prefix = "2.0.1.0/24"
}


#public ip
resource "azurerm_public_ip" "zone1" {
 name                         = "pipzone180"
 location                     = "koreacentral"
#  sku                 = "Standard"
 resource_group_name          = var.resource_group_name
 allocation_method = "Static"
 domain_name_label            = "pipzone180"
 
}

resource "azurerm_public_ip" "zone18080" {
 name                         = "pipzone18080"
 location                     = "koreacentral"
#  sku                 = "Standard"
 resource_group_name          = var.resource_group_name
 allocation_method = "Static"
 domain_name_label            = "pipzone18080"
 
}


#Load Balancer
resource "azurerm_lb" "zone1" {
name = "lbzone180"
location = "koreacentral"
resource_group_name = var.resource_group_name
frontend_ip_configuration {
name = "pipzone180"
public_ip_address_id = azurerm_public_ip.zone1.id
}
}

resource "azurerm_lb_backend_address_pool" "bpepool" {
resource_group_name = var.resource_group_name
loadbalancer_id = azurerm_lb.zone1.id
name = "Bpoolzone180"
}


resource "azurerm_lb_nat_pool" "lbnatpool" {
resource_group_name = var.resource_group_name
name = "ssh"
loadbalancer_id = azurerm_lb.zone1.id
protocol = "Tcp"
frontend_port_start = 50000
frontend_port_end = 50119
backend_port = 22
frontend_ip_configuration_name = "pipzone180"
}


resource "azurerm_lb_probe" "zone1" {
resource_group_name = var.resource_group_name
loadbalancer_id = azurerm_lb.zone1.id
name = "http-probe"
protocol = "Http"
request_path = "/"
port = 80
}


resource "azurerm_lb_rule" "lbnatrule" {
resource_group_name = var.resource_group_name
loadbalancer_id = azurerm_lb.zone1.id
name = "http"
protocol = "Tcp"
frontend_port = 80
backend_port = 80
backend_address_pool_id = azurerm_lb_backend_address_pool.bpepool.id
frontend_ip_configuration_name = "pipzone180"
probe_id = azurerm_lb_probe.zone1.id
}




#Load Balancer8080
resource "azurerm_lb" "zone18080" {
name = "lbzone18080"
location = "koreacentral"
resource_group_name = var.resource_group_name
frontend_ip_configuration {
name = "zone18080"
public_ip_address_id = azurerm_public_ip.zone18080.id
}
}

resource "azurerm_lb_backend_address_pool" "zone18080" {
resource_group_name = var.resource_group_name
loadbalancer_id = azurerm_lb.zone18080.id
name = "Bpoolzone18080"
}


resource "azurerm_lb_nat_pool" "zone18080" {
resource_group_name = var.resource_group_name
name = "ssh"
loadbalancer_id = azurerm_lb.zone18080.id
protocol = "Tcp"
frontend_port_start = 50000
frontend_port_end = 50119
backend_port = 22
frontend_ip_configuration_name = "zone18080"
}


resource "azurerm_lb_probe" "zone18080" {
resource_group_name = var.resource_group_name
loadbalancer_id = azurerm_lb.zone18080.id
name = "http-probe2"
# protocol = "Tcp"
# request_path = "/"
port = 8080
}


resource "azurerm_lb_rule" "zone18080" {
resource_group_name = var.resource_group_name
loadbalancer_id = azurerm_lb.zone18080.id
name = "http"
protocol = "Tcp"
frontend_port = 8080
backend_port = 8080
backend_address_pool_id = azurerm_lb_backend_address_pool.zone18080.id
frontend_ip_configuration_name = "zone18080"
probe_id = azurerm_lb_probe.zone18080.id
}




#vmss
resource "azurerm_virtual_machine_scale_set" "exuser02" {
name = "zone180"
location = "koreacentral"
resource_group_name = var.resource_group_name
upgrade_policy_mode = "Manual"


sku {
name = "Standard_B2ms"
tier = "Standard"
capacity = 2
}

storage_profile_image_reference {
publisher = "Canonical"
offer = "UbuntuServer"
sku = "16.04-LTS"
version = "latest"
}


storage_profile_os_disk {
name = ""
caching = "ReadWrite"
create_option = "FromImage"
managed_disk_type = "Standard_LRS"
}

storage_profile_data_disk {
lun = 0
caching = "ReadWrite"
create_option = "Empty"
disk_size_gb = 10
}

os_profile {
computer_name_prefix = "testvm"
admin_username = "user02"
custom_data = file("~/web.sh")
}



os_profile_linux_config {
disable_password_authentication = true
ssh_keys {
path = "/home/user02/.ssh/authorized_keys"
key_data = file("~/.ssh/id_rsa.pub")  ## ssh-keygen 으로 생성 
}
}
network_profile {
name = "terraformnetworkprofile"
primary = true
ip_configuration {
name = "TestIPConfiguration"
primary = true
subnet_id = azurerm_subnet.zone1.id
load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
load_balancer_inbound_nat_rules_ids = [azurerm_lb_nat_pool.lbnatpool.id]
}
}
tags = {
environment = "staging"
}
}



#vmss
resource "azurerm_virtual_machine_scale_set" "zone18080" {
name = "zone18080"
location = "koreacentral"
resource_group_name = var.resource_group_name
upgrade_policy_mode = "Manual"


sku {
name = "Standard_B2ms"
tier = "Standard"
capacity = 2
}

storage_profile_image_reference {
publisher = "Canonical"
offer = "UbuntuServer"
sku = "16.04-LTS"
version = "latest"
}


storage_profile_os_disk {
name = ""
caching = "ReadWrite"
create_option = "FromImage"
managed_disk_type = "Standard_LRS"
}

storage_profile_data_disk {
lun = 0
caching = "ReadWrite"
create_option = "Empty"
disk_size_gb = 10
}

os_profile {
computer_name_prefix = "testvm"
admin_username = "user02"
custom_data = file("~/web2.sh")
}



os_profile_linux_config {
disable_password_authentication = true
ssh_keys {
path = "/home/user02/.ssh/authorized_keys"
key_data = file("~/.ssh/id_rsa.pub")  ## ssh-keygen 으로 생성 
}
}
network_profile {
name = "terraformnetworkprofile"
primary = true
ip_configuration {
name = "TestIPConfiguration"
primary = true
subnet_id = azurerm_subnet.zone1.id
load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.zone18080.id]
load_balancer_inbound_nat_rules_ids = [azurerm_lb_nat_pool.zone18080.id]
}
}
tags = {
environment = "staging"
}
}

