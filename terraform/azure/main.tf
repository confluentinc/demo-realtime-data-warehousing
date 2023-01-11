terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.0.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "rt-dw-rg" {
  name     = "rt-dw-resources"
  location = "westus2"
  tags = {
    environment = "dev"
    created_by  = "terraform"
  }
}

resource "azurerm_virtual_network" "rt-dw-vn" {
  name                = "rt-dw-network"
  resource_group_name = azurerm_resource_group.rt-dw-rg.name
  location            = azurerm_resource_group.rt-dw-rg.location
  address_space       = ["10.123.0.0/16"]

  tags = {
    environment = "dev"
    created_by  = "terraform"
  }
}
resource "azurerm_subnet" "rt-dw-subnet" {
  name                 = "rt-dw-subnet"
  resource_group_name  = azurerm_resource_group.rt-dw-rg.name
  virtual_network_name = azurerm_virtual_network.rt-dw-vn.name
  address_prefixes     = ["10.123.1.0/24"]
}

resource "azurerm_network_security_group" "rt-dw-sg" {
  name                = "rt-dw-security-group"
  location            = azurerm_resource_group.rt-dw-rg.location
  resource_group_name = azurerm_resource_group.rt-dw-rg.name

  tags = {
    environment = "dev"
    created_by  = "terraform"
  }
}

resource "azurerm_network_security_rule" "rt-dw-sr" {
  name                        = "rt-dw-security-rule"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rt-dw-rg.name
  network_security_group_name = azurerm_network_security_group.rt-dw-sg.name
}

resource "azurerm_subnet_network_security_group_association" "rt-dw-sga" {
  subnet_id                 = azurerm_subnet.rt-dw-subnet.id
  network_security_group_id = azurerm_network_security_group.rt-dw-sg.id
}

resource "azurerm_public_ip" "rt-dw-ip" {
  name                = "rt-dw-ip-${format("%02d", count.index)}"
  count               = 2
  resource_group_name = azurerm_resource_group.rt-dw-rg.name
  location            = azurerm_resource_group.rt-dw-rg.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "dev"
    created_by  = "terraform"
  }
}

resource "azurerm_network_interface" "rt-dw-nic" {
  name                = "rt-dw-nic-${format("%02d", count.index)}"
  count               = 2
  location            = azurerm_resource_group.rt-dw-rg.location
  resource_group_name = azurerm_resource_group.rt-dw-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.rt-dw-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = element(azurerm_public_ip.rt-dw-ip.*.id, count.index)
  }
  tags = {
    environment = "dev"
    created_by  = "terraform"
  }
}

resource "azurerm_linux_virtual_machine" "postgres_customers" {
  name                = "rt-dwh-postgres-customers-instance"
  resource_group_name = azurerm_resource_group.rt-dw-rg.name
  location            = azurerm_resource_group.rt-dw-rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    element(azurerm_network_interface.rt-dw-nic.*.id, 0)
  ]
  custom_data = filebase64("../scripts/pg_customers.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/rtdwkey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_linux_virtual_machine" "postgres_products" {
  name                = "rt-dwh-postgres-products-instance"
  resource_group_name = azurerm_resource_group.rt-dw-rg.name
  location            = azurerm_resource_group.rt-dw-rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  network_interface_ids = [
    element(azurerm_network_interface.rt-dw-nic.*.id, 1)
  ]
  custom_data = filebase64("../scripts/pg_products.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/rtdwkey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

output "postgres_instance_customers_public_endpoint" {
  value = azurerm_linux_virtual_machine.postgres_customers.public_ip_address
}

output "postgres_instance_products_public_endpoint" {
  value = azurerm_linux_virtual_machine.postgres_products.public_ip_address
}