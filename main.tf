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

resource "azurerm_resource_group" "rg" {                              //luo RG
  name     = var.resource_group_name
  location = "westeurope"

   tags = {
     Environment = "Terraform Getting Started"
     Team = "DevOps"
   }
}
resource "azurerm_virtual_network" "vnet" {                         //Virtual network
    name                = "myTFVnet"
    address_space       = ["10.0.0.0/16"]
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.rg.name
}
resource "azurerm_subnet" "scubnet" {                               //subnet
  name                 = "TFscubanet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
resource "azurerm_storage_account" "villeformstorage" {             //storage account
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
resource "azurerm_storage_container" "kontti" {                     //container blöb
  name                  = "blobsuli"
  storage_account_name  = azurerm_storage_account.villeformstorage.name
  container_access_type = "blob"
}
resource   "azurerm_public_ip"   "TFlip"   {                        //public IP
  name   =   "TFlip" 
  location   =   "westeurope" 
  resource_group_name   =   azurerm_resource_group.rg.name 
  allocation_method   =   "Dynamic" 
  sku   =   "Basic" 
}
resource   "azurerm_network_interface"   "TFnic"   {                //network interface card 
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
resource "azurerm_network_security_group" "myterraformnsg" {      //NSG
    name                = "myNetworkSecurityGroup"
    location            = "westeurope"
    resource_group_name = azurerm_resource_group.rg.name

    security_rule {
        name                       = "HTTP"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "80"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }

    tags = {
        environment = "Terraform Demo"
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
output "public_ip_address" {

    value = azurerm_public_ip.TFlip.*.ip_address

}
resource "azurerm_linux_virtual_machine" "myterraformvm" {                      //LinuxVm
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
    resource "azurerm_virtual_machine_extension" "vme" {

    virtual_machine_id         = azurerm_linux_virtual_machine.myterraformvm.id
    name                       = "vme"
    publisher                  = "Microsoft.Azure.Extensions"
    type                       = "CustomScript"
    type_handler_version       = "2.0"
    auto_upgrade_minor_version = true
      settings = <<SETTINGS
  
    {

    "commandToExecute": "sudo apt-get update && apt-get install -y apache2 && echo 'hello world' > /var/www/html/index.html"

    }

    SETTINGS

  }
    resource "azurerm_postgresql_server" "postistressi" {
    name                = "tfpostistressi"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name

    sku_name = "B_Gen5_2"

    storage_mb                   = 5120
    backup_retention_days        = 7
    geo_redundant_backup_enabled = false
    auto_grow_enabled            = true

    administrator_login          = var.administrator_login
    administrator_login_password = var.administrator_login_password
    version                      = "11"
    ssl_enforcement_enabled      = true
  }

  resource "azurerm_postgresql_database" "example" {
    name                = "academy"
    resource_group_name = azurerm_resource_group.rg.name
    server_name         = azurerm_postgresql_server.postistressi.name
    charset             = "UTF8"
    collation           = "English_United States.1252"
}
    