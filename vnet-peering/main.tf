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
  name     = "rg-az104-study"
  location = var.location
}

resource "azurerm_virtual_network" "example-1" {
  name                = "vnet-az104-study-1"
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["${var.vnets[0]}"]
  location            = var.location
}

resource "azurerm_virtual_network" "example-2" {
  name                = "vnet-az104-study-2"
  resource_group_name = azurerm_resource_group.example.name
  address_space       = ["${var.vnets[1]}"]
  location            = var.location
}

resource "azurerm_virtual_network_peering" "example-1" {
  name                      = "peer1to2"
  resource_group_name       = azurerm_resource_group.example.name
  virtual_network_name      = azurerm_virtual_network.example-1.name
  remote_virtual_network_id = azurerm_virtual_network.example-2.id
}

resource "azurerm_virtual_network_peering" "example-2" {
  name                      = "peer2to1"
  resource_group_name       = azurerm_resource_group.example.name
  virtual_network_name      = azurerm_virtual_network.example-2.name
  remote_virtual_network_id = azurerm_virtual_network.example-1.id
}