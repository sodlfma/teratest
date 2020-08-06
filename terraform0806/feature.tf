provider "azurerm" {
  # The "feature" block is required for AzureRM provider 2.x.
  # If you're using version 1.x, the "features" block isn't allowed.
  version = "~>2.0"
  features {}
}