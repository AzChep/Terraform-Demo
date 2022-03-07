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
resource "azurerm_subnet" "scubnet" {
  name                 = "TFscubanet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
resource "azurerm_storage_account" "villeformstorage" {
  name                     = "villeformstorage"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = true

  tags = {
    environment = "staging"
  }
}
resource "azurerm_storage_container" "kontti" {
  name                  = "blobsuli"
  storage_account_name  = azurerm_storage_account.villeformstorage.name
  container_access_type = "blob"
}
resource   "azurerm_public_ip"   "TFlip"   { 
  name   =   "TFlip" 
  location   =   "westeurope" 
  resource_group_name   =   azurerm_resource_group.rg.name 
  allocation_method   =   "Dynamic" 
  sku   =   "Basic" 
}
resource   "azurerm_network_interface"   "TFnic"   { 
  name   =   "myvm1-nic" 
  location   =   "westeurope" 
  resource_group_name   =   azurerm_resource_group.rg.name 

  ip_configuration   { 
    name   =   "ipconfig1" 
    subnet_id   =   azurerm_subnet.scubnet.id 
    private_ip_address_allocation   =   "Dynamic" 
    public_ip_address_id   =   azurerm_public_ip.TFlip.id
  } 
}
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}
output "tls_private_key" { 
    value = tls_private_key.example_ssh.private_key_pem 
    sensitive = true
}
resource "azurerm_linux_virtual_machine" "myterraformvm" {
    name                  = "TFLNVM"
    location              = azurerm_resource_group.rg.location
    resource_group_name   = azurerm_resource_group.rg.name
    network_interface_ids = [azurerm_network_interface.TFnic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "debian"
        offer     = "debian-11"
        sku       = "11-gen2"
        version   = "latest"
    }

    computer_name  = "myvm"
    admin_username = "azureuser"
    disable_password_authentication = true

    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.example_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.villeformstorage.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Demo"
    }
}