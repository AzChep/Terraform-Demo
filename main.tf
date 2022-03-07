terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 1.1.0"
}

provider "azurerm" {
  features {}
  subscription_id           = var.subscription_id
  tenant_id                 = var.subscription_tenant_id
}

resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = "westeurope"

   tags = {
     Environment = "Terraform Getting Started"
     Team = "DevOps"
   }
}
resource "azurerm_virtual_network" "vnet" {
    name                = "myTFVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.rg.name
}