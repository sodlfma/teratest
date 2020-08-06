resource "azurerm_resource_group" "rg" {
  name     = "QuickstartTerraformTest-rg"
  location = "eastus"
  
  tags = {
        environment = "Terraform Demo"
    }
}

#name = "리소스 그룹명"