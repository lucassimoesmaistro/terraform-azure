# Configure the Azure provider
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 2.65"
    }
  }

  required_version = ">= 0.14.9"
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "example" {
  name     = "rsg-terraform"
  location = var.location
}
resource "azurerm_network_ddos_protection_plan" "example" {
  name                = "ddospplan1"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
}
resource "azurerm_network_security_group" "example" {
  name                = "secgrp-terraform"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  security_rule {
    name                       = "HTTP"
    priority                   = 900
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule { //Here opened https port
    name                       = "HTTPS"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule { //Here opened WinRMport
    name                       = "winrm"
    priority                   = 1010
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule { //Here opened https port for outbound
    name                       = "winrm-out"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "5985"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule { //Here opened remote desktop port
    name                       = "RDP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_virtual_network" "example" {
  name                = "vnet1"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["${var.vnets[0]}"]

  ddos_protection_plan {
    id     = azurerm_network_ddos_protection_plan.example.id
    enable = true
  }

  tags = {
    environment = "Production"
  }
}

# Create subnet
resource "azurerm_subnet" "exampleSubnetA" {
  name                 = "subnetA"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["${var.subnets[0]}"]
}

# Create subnet
resource "azurerm_subnet" "exampleSubnetB" {
  name                 = "subnetB"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example.name
  address_prefixes     = ["${var.subnets[1]}"]
}


resource "azurerm_public_ip" "example" { //Here defined the public IP
  name                         = "publicip"
  location                     = azurerm_resource_group.example.location
  resource_group_name          = azurerm_resource_group.example.location
  allocation_method            = "Dynamic"
  idle_timeout_in_minutes      = 30
  domain_name_label            = "mindcrackvm" //Here defined the dns name

}

resource "azurerm_network_interface" "example" {
  name                      = "nicv1"
  location                  = azurerm_resource_group.example.location
  resource_group_name       = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.exampleSubnetA.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example.id

  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.example.id
    network_security_group_id = azurerm_network_security_group.example.id
}

resource "azurerm_storage_account" "example" { //Here defined a storage account for disk
  name                     = "mindcrackstoacc"
  resource_group_name      = azurerm_resource_group.example.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "GRS"
}

resource "azurerm_storage_container" "storagecont" { //Here defined a storage account container for disk
  name                  = "mindcrackstoragecont"
  storage_account_name  = azurerm_storage_account.example.name
  container_access_type = "private"
}

resource "azurerm_managed_disk" "example" { //Here defined data disk structure
  name                 = "mindcrackdatadisk"
  location             = var.location
  resource_group_name  = azurerm_resource_group.example.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1023"
}

resource "azurerm_virtual_machine" "vm" { //Here defined virtual machine
  name                  = "mindcrackvm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.example.name
  network_interface_ids = ["${azurerm_network_interface.example.id}"]
  vm_size               = "Standard_A2" //Here defined virtual machine size

  storage_image_reference { //Here defined virtual machine OS
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk { //Here defined OS disk
    name              = "mindcrackosdisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_data_disk { //Here defined actual data disk by referring to above structure
    name            = azurerm_managed_disk.example.name
    managed_disk_id = azurerm_managed_disk.example.id
    create_option   = "Attach"
    lun             = 1
    disk_size_gb    = azurerm_managed_disk.example.disk_size_gb
  }

  os_profile { //Here defined admin uid/pwd and also comupter name
    computer_name  = "server01"
    admin_username = var.user
    admin_password = var.pass
  }

  os_profile_windows_config { //Here defined autoupdate config and also vm agent config
    enable_automatic_upgrades = true
    provision_vm_agent        = true

  }
}  