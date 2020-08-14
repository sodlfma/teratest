# Configure the Microsoft Azure Provider
provider "azurerm" {
    # The "feature" block is required for AzureRM provider 2.x. 
    # If you're using version 1.x, the "features" block is not allowed.
    version = "~>2.0"
    features {}
}

#variables definitions
variable "location" {
 description = "The location where resources will be created"
 default     = "eastus"
}

variable "tags" {
 description = "A map of the tags to use for the resources that are deployed"
 type        = map(string)

 default = {
     environment = "codelab"
     creator = "10146"
 }
}

variable "resource_group_name" {
 description = "The name of the resource group in which the resources will be created"
 default     = "10146"
}


variable "application_port" {
   description = "The port that you want to expose to the external load balancer"
   default     = 80
}

variable "admin_user" {
   description = "User name to use as the admin account on the VMs that will be part of the VM Scale Set"
   default     = "ds10146"
}

variable "admin_password" {
   description = "Default password for admin account"
   default  = "abcd1234"
}




#output definitions
output "vmss_public_ip" {
     value = azurerm_public_ip.vmss.fqdn
 }


#network infrastructure
#VMSS를 생성할 리소스 그룹 생성
#  resource "azurerm_resource_group" "vmss" {
#  name     = var.resource_group_name
#  location = var.location
#  tags     = var.tags
# } 

#랜덤스트링 생성
resource "random_string" "fqdn" {
 length  = 6
 special = false
 upper   = false
 number  = false
}

#VMSS-Vnet 생성
resource "azurerm_virtual_network" "vmss" {
 name                = "vmss-vnet"
 address_space       = ["10.0.0.0/16"]
 location            = var.location
 resource_group_name = "10146"
 tags                = var.tags
}

#VMSS-서브넷 생성
resource "azurerm_subnet" "vmss" {
 name                 = "vmss-subnet"
 resource_group_name  = "10146"
 virtual_network_name = azurerm_virtual_network.vmss.name
 address_prefixes       = ["10.0.2.0/24"]
}

#VMSS-퍼블릭IP 생성
resource "azurerm_public_ip" "vmss" {
 name                         = "vmss-public-ip"
 location                     = var.location
 resource_group_name          = "10146"
 allocation_method = "Static"
 domain_name_label            = random_string.fqdn.result
 tags                         = var.tags
}



#VMSS셋 설정 만들기
#loadbalancer 생성
resource "azurerm_lb" "vmss" {
 name                = "vmss-lb"
 location            = var.location
 resource_group_name = "10146"

 frontend_ip_configuration {
   name                 = "PublicIPAddress"
   public_ip_address_id = azurerm_public_ip.vmss.id
 }

 tags = var.tags
}

#백앤드풀 생성
resource "azurerm_lb_backend_address_pool" "bpepool" {
 resource_group_name = "10146"
 loadbalancer_id     = azurerm_lb.vmss.id
 name                = "BackEndAddressPool"
}

#상태 프로브 설정
resource "azurerm_lb_probe" "vmss" {
 resource_group_name = "10146"
 loadbalancer_id     = azurerm_lb.vmss.id
 name                = "ssh-running-probe"
 port                = var.application_port
}

#로드발란싱 룰 생성
resource "azurerm_lb_rule" "lbnatrule" {
    resource_group_name            = "10146"
    loadbalancer_id                = azurerm_lb.vmss.id
    name                           = "http"
    protocol                       = "Tcp"
    frontend_port                  = var.application_port
    backend_port                   = var.application_port
    backend_address_pool_id        = azurerm_lb_backend_address_pool.bpepool.id
    frontend_ip_configuration_name = "PublicIPAddress"
    probe_id                       = azurerm_lb_probe.vmss.id
}

#VM 셋 설정
resource "azurerm_virtual_machine_scale_set" "vmss" {
    name                = "vmscaleset"
     location            = var.location
     resource_group_name = "10146"
     upgrade_policy_mode = "Manual"

 #VM 스펙
 sku {
     name     = "Standard_DS1_v2"
     tier     = "Standard"
     capacity = 2
 }
 
 #VM이미지: 이미 생성된 이미지를 붙이려면 여기서 설정
#  storage_profile_image_reference {
#    publisher = "Canonical"
#    offer     = "UbuntuServer"
#    sku       = "16.04-LTS"
#    version   = "latest"
#  }

#VM이미지 경로 
 storage_profile_image_reference {
     id="/subscriptions/3ac347d8-a75f-4611-8ca8-161a69189283/resourceGroups/10146/providers/Microsoft.Compute/images/myVM-image-nginx01"
    #  id="data.azurerm_image.image.id"
  }
 
 #OS디스크 선택
 storage_profile_os_disk {
     name              = ""
     caching           = "ReadWrite"
     create_option     = "FromImage"
     managed_disk_type = "Standard_LRS"
 }
 
 #스토리지 디스크 설정
 storage_profile_data_disk {
   lun          = 0
   caching        = "ReadWrite"
   create_option  = "Empty"
   disk_size_gb   = 10
 }
 
 #os 관련 설정
 os_profile {
   computer_name_prefix = "vmlab"
   admin_username       = "ds10146"
   admin_password       = "abcd1234"
#    custom_data          = file("web.conf")
 }


#  os_profile_linux_config {
#    disable_password_authentication = false
#  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/ds10146/.ssh/authorized_keys" #새로 생성할 리소스 내에서 지정될 path(고치지 말것)
      key_data = file("/home/ds10146/.ssh/id_rsa.pub") #ssh 파일 
    }
  }


 #네트워크 설정
 network_profile {
   name    = "terraformnetworkprofile"
   primary = true

   ip_configuration {
     name                                   = "IPConfiguration"
     subnet_id                              = azurerm_subnet.vmss.id
     load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bpepool.id]
     primary = true
   }
 }

 tags = var.tags
}
