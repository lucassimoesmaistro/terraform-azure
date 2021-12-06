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

##################################################################VM1 - VNet1###########################################
resource "azurerm_virtual_network" "example" {
  name                = "vnet1"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["${var.vnets[0]}"]

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
  name                         = "terraform-publicip1"
  location                     = azurerm_resource_group.example.location
  resource_group_name          = azurerm_resource_group.example.name
  allocation_method            = "Dynamic"
  idle_timeout_in_minutes      = 30
  domain_name_label            = "terraform-test" //Here defined the dns name

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
resource "azurerm_network_interface_security_group_association" "example1" {
    network_interface_id      = azurerm_network_interface.example.id
    network_security_group_id = azurerm_network_security_group.example.id
}

resource "azurerm_managed_disk" "example" { //Here defined data disk structure
  name                 = "terraform-datadisk1"
  location             = var.location
  resource_group_name  = azurerm_resource_group.example.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1023"
}

resource "azurerm_virtual_machine" "vm" { //Here defined virtual machine
  name                  = "terraform-vm1"
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
    name              = "terraform-osdisk1"
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

##################################################################VM2 - VNet1###########################################


resource "azurerm_public_ip" "examplevm2" { //Here defined the public IP
  name                         = "terraform-publicipvm2"
  location                     = azurerm_resource_group.example.location
  resource_group_name          = azurerm_resource_group.example.name
  allocation_method            = "Dynamic"
  idle_timeout_in_minutes      = 30
  domain_name_label            = "terraform-testvm2" //Here defined the dns name

}

resource "azurerm_network_interface" "examplevm2" {
  name                      = "nicvm2"
  location                  = azurerm_resource_group.example.location
  resource_group_name       = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "testconfigurationvm2"
    subnet_id                     = azurerm_subnet.exampleSubnetB.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.examplevm2.id

  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "examplevm2" {
    network_interface_id      = azurerm_network_interface.examplevm2.id
    network_security_group_id = azurerm_network_security_group.example.id
}

resource "azurerm_managed_disk" "examplevm2" { //Here defined data disk structure
  name                 = "terraform-datadiskvm2"
  location             = var.location
  resource_group_name  = azurerm_resource_group.example.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1023"
}

resource "azurerm_virtual_machine" "vm2snetB" { //Here defined virtual machine
  name                  = "terraform-vm2snetB"
  location              = var.location
  resource_group_name   = azurerm_resource_group.example.name
  network_interface_ids = ["${azurerm_network_interface.examplevm2.id}"]
  vm_size               = "Standard_A2" //Here defined virtual machine size

  storage_image_reference { //Here defined virtual machine OS
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk { //Here defined OS disk
    name              = "terraform-osdiskvm2"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_data_disk { //Here defined actual data disk by referring to above structure
    name            = azurerm_managed_disk.examplevm2.name
    managed_disk_id = azurerm_managed_disk.examplevm2.id
    create_option   = "Attach"
    lun             = 1
    disk_size_gb    = azurerm_managed_disk.examplevm2.disk_size_gb
  }

  os_profile { //Here defined admin uid/pwd and also comupter name
    computer_name  = "serverB01"
    admin_username = var.user
    admin_password = var.pass
  }

  os_profile_windows_config { //Here defined autoupdate config and also vm agent config
    enable_automatic_upgrades = true
    provision_vm_agent        = true

  }
}  

##################################################################VM1 - VNet2###########################################
resource "azurerm_virtual_network" "example2" {
  name                = "vnet2"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["${var.vnets[1]}"]

  tags = {
    environment = "Production"
  }
}

# Create subnet
resource "azurerm_subnet" "exampleSubnetC" {
  name                 = "subnetC"
  resource_group_name  = azurerm_resource_group.example.name
  virtual_network_name = azurerm_virtual_network.example2.name
  address_prefixes     = ["${var.subnets[2]}"]
}


resource "azurerm_public_ip" "example2" { //Here defined the public IP
  name                         = "terraform-publicip2"
  location                     = azurerm_resource_group.example.location
  resource_group_name          = azurerm_resource_group.example.name
  allocation_method            = "Dynamic"
  idle_timeout_in_minutes      = 30
  domain_name_label            = "terraform-test2" //Here defined the dns name

}

resource "azurerm_network_interface" "example2" {
  name                      = "nicv2"
  location                  = azurerm_resource_group.example.location
  resource_group_name       = azurerm_resource_group.example.name

  ip_configuration {
    name                          = "testconfiguration2"
    subnet_id                     = azurerm_subnet.exampleSubnetC.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.example2.id

  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example2" {
    network_interface_id      = azurerm_network_interface.example2.id
    network_security_group_id = azurerm_network_security_group.example.id
}

resource "azurerm_managed_disk" "example2" { //Here defined data disk structure
  name                 = "terraform-datadisk2"
  location             = var.location
  resource_group_name  = azurerm_resource_group.example.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = "1023"
}

resource "azurerm_virtual_machine" "vm2" { //Here defined virtual machine
  name                  = "terraform-vm2"
  location              = var.location
  resource_group_name   = azurerm_resource_group.example.name
  network_interface_ids = ["${azurerm_network_interface.example2.id}"]
  vm_size               = "Standard_A2" //Here defined virtual machine size

  storage_image_reference { //Here defined virtual machine OS
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter"
    version   = "latest"
  }

  storage_os_disk { //Here defined OS disk
    name              = "terraform-osdisk2"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Standard_LRS"
  }

  storage_data_disk { //Here defined actual data disk by referring to above structure
    name            = azurerm_managed_disk.example2.name
    managed_disk_id = azurerm_managed_disk.example2.id
    create_option   = "Attach"
    lun             = 1
    disk_size_gb    = azurerm_managed_disk.example2.disk_size_gb
  }

  os_profile { //Here defined admin uid/pwd and also comupter name
    computer_name  = "server02"
    admin_username = var.user
    admin_password = var.pass
  }

  os_profile_windows_config { //Here defined autoupdate config and also vm agent config
    enable_automatic_upgrades = true
    provision_vm_agent        = true

  }
}  