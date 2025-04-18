# Import Current User Credentials
data "azurerm_client_config" "current" {
  provider = azurerm
}

# Import Existing Resource Group created using the Azure CLI
data "azurerm_resource_group" "rg" {
  name = "rg_${var.initials}${var.random_string}"
}