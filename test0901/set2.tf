# resource Group
variable "resource_group_name_set2" {
 description = "The name of the resource group in which the resources will be created"
 default     = "user02rg_2"
}

resource "azurerm_resource_group" "user02rg_2" {
    name     = var.resource_group_name_set2
    location = "koreacentral"

    tags = {
        environment = "Terraform Demo"
    }
}


#Vnet, subnet
resource "azurerm_virtual_network" "zone2" {
name = "vnetzone2"
address_space = ["102.0.0.0/16"]
location = "koreasouth"
resource_group_name = var.resource_group_name_set2
}

resource "azurerm_subnet" "zone2" {
name = "subnetzone2"
resource_group_name = var.resource_group_name_set2
virtual_network_name = azurerm_virtual_network.zone2.name
address_prefix = "102.0.1.0/24"
}


#public ip
resource "azurerm_public_ip" "zone2" {
 name                         = "pipzone280"
 location                     = "koreasouth"
#  sku                 = "Standard"
 resource_group_name          = var.resource_group_name_set2
 allocation_method = "Static"
 domain_name_label            = "pipzone280"
 
}

resource "azurerm_public_ip" "zone28080" {
 name                         = "pipzone28080"
 location                     = "koreasouth"
#  sku                 = "Standard"
 resource_group_name          = var.resource_group_name_set2
 allocation_method = "Static"
 domain_name_label            = "pipzone28080"
 
}


#Load Balancer
resource "azurerm_lb" "zone2" {
name = "lbzone280"
location = "koreasouth"
resource_group_name = var.resource_group_name_set2
frontend_ip_configuration {
name = "lbzone280"
public_ip_address_id = azurerm_public_ip.zone2.id
}
}

resource "azurerm_lb_backend_address_pool" "zone2" {
resource_group_name = var.resource_group_name_set2
loadbalancer_id = azurerm_lb.zone2.id
name = "Bpoolzone280"
}


resource "azurerm_lb_nat_pool" "zone2" {
resource_group_name = var.resource_group_name_set2
name = "ssh"
loadbalancer_id = azurerm_lb.zone2.id
protocol = "Tcp"
frontend_port_start = 50000
frontend_port_end = 50119
backend_port = 22
frontend_ip_configuration_name = "lbzone280"
}


resource "azurerm_lb_probe" "zone2" {
resource_group_name = var.resource_group_name_set2
loadbalancer_id = azurerm_lb.zone2.id
name = "http-probe"
protocol = "Http"
request_path = "/"
port = 80
}

resource "azurerm_lb_rule" "zone2" {
resource_group_name = var.resource_group_name_set2
loadbalancer_id = azurerm_lb.zone2.id
name = "http"
protocol = "Tcp"
frontend_port = 80
backend_port = 80
backend_address_pool_id = azurerm_lb_backend_address_pool.zone2.id
frontend_ip_configuration_name = "lbzone280"
probe_id = azurerm_lb_probe.zone2.id
}




# Load Balancer8080
resource "azurerm_lb" "zone28080" {
name = "lbzone28080"
location = "koreasouth"
resource_group_name = var.resource_group_name_set2
frontend_ip_configuration {
name = "zone28080"
public_ip_address_id = azurerm_public_ip.zone28080.id
}
}

resource "azurerm_lb_backend_address_pool" "zone28080" {
resource_group_name = var.resource_group_name_set2
loadbalancer_id = azurerm_lb.zone28080.id
name = "Bpoolzone28080"
}


resource "azurerm_lb_nat_pool" "zone28080" {
resource_group_name = var.resource_group_name_set2
name = "ssh"
loadbalancer_id = azurerm_lb.zone28080.id
protocol = "Tcp"
frontend_port_start = 50000
frontend_port_end = 50119
backend_port = 22
frontend_ip_configuration_name = "zone28080"
}


resource "azurerm_lb_probe" "zone28080" {
resource_group_name = var.resource_group_name_set2
loadbalancer_id = azurerm_lb.zone28080.id
name = "http-probe2"
# protocol = "Tcp"
# request_path = "/"
port = 8080
}


resource "azurerm_lb_rule" "zone28080" {
resource_group_name = var.resource_group_name_set2
loadbalancer_id = azurerm_lb.zone28080.id
name = "http"
protocol = "Tcp"
frontend_port = 8080
backend_port = 8080
backend_address_pool_id = azurerm_lb_backend_address_pool.zone28080.id
frontend_ip_configuration_name = "zone28080"
probe_id = azurerm_lb_probe.zone28080.id
}




#vmss
resource "azurerm_virtual_machine_scale_set" "zone280" {
name = "zone280"
location = "koreasouth"
resource_group_name = var.resource_group_name_set2
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
subnet_id = azurerm_subnet.zone2.id
load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.zone2.id]
load_balancer_inbound_nat_rules_ids = [azurerm_lb_nat_pool.zone2.id]
}
}
tags = {
environment = "staging"
}
}





# vmss
resource "azurerm_virtual_machine_scale_set" "vmsszone28080" {
name = "zone28080"
location = "koreasouth"
resource_group_name = var.resource_group_name_set2
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
subnet_id = azurerm_subnet.zone2.id
load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.zone28080.id]
load_balancer_inbound_nat_rules_ids = [azurerm_lb_nat_pool.zone28080.id]
}
}
tags = {
environment = "staging"
}
}

