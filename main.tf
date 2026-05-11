resource "azurerm_resource_group" "rg" {
  name     = "JayanthRGNEW"
  location = "West US 2"
}

# Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = "multi-vm-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Subnet
resource "azurerm_subnet" "subnet" {
  name                 = "multi-vm-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP for Bastion VM
resource "azurerm_public_ip" "publicip" {
  name                = "bastion-public-ip"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}

# Network Security Group
resource "azurerm_network_security_group" "nsg" {
  name                = "multi-vm-nsg"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Bastion NIC
resource "azurerm_network_interface" "bastion_nic" {
  name                = "bastion-nic"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

# Private NICs
resource "azurerm_network_interface" "private_nic" {
  count               = 3
  name                = "private-nic-${count.index}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Associate NSG to Bastion NIC
resource "azurerm_network_interface_security_group_association" "bastion_assoc" {
  network_interface_id      = azurerm_network_interface.bastion_nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Associate NSG to Private NICs
resource "azurerm_network_interface_security_group_association" "private_assoc" {
  count                     = 3
  network_interface_id      = azurerm_network_interface.private_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Bastion VM
resource "azurerm_linux_virtual_machine" "bastion_vm" {
  name                = "bastion-vm"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"

  admin_username = "azureuser"
  admin_password = "Admin@12345"

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.bastion_nic.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Private VMs
resource "azurerm_linux_virtual_machine" "private_vm" {
  count               = 3
  name                = "private-vm-${count.index}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  size                = "Standard_B1s"

  admin_username = "azureuser"
  admin_password = "Admin@12345"

  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.private_nic[count.index].id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

output "bastion_public_ip" {
  value = azurerm_public_ip.publicip.ip_address
}