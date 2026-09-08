resource "azurerm_virtual_network" "student-network" {
  name                = var.studentVNETName
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.studentRG.location
  resource_group_name = azurerm_resource_group.studentRG.name
}

# resource "time_sleep" "wait-30s-vnet-booting"{
# 	depends_on = [ azurerm_virtual_network.student-network ]
# 	create_duration = "30s"
# }

resource "azurerm_subnet" "vm-subnet" {
  depends_on = [
    azurerm_virtual_network.student-network
  ]
  name                 = "vmSubnet"
  resource_group_name  = azurerm_resource_group.studentRG.name
  virtual_network_name = azurerm_virtual_network.student-network.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_public_ip" "student-public-ip" {
  lifecycle {
    create_before_destroy = true
  }
  name                = var.studentIPName
  location            = azurerm_resource_group.studentRG.location
  resource_group_name = azurerm_resource_group.studentRG.name

  # Basic SKU public IPs were retired on 30 September 2025 and can no longer be
  # created. Standard SKU requires static allocation — which is also what we want,
  # since the IP now survives a deallocate and the student's ~/.ssh/config keeps
  # working between sessions.
  allocation_method = "Static"
  sku               = "Standard"
}

resource "azurerm_network_security_group" "student-nsg" {
  name                = var.studentNSGName
  location            = azurerm_resource_group.studentRG.location
  resource_group_name = azurerm_resource_group.studentRG.name
  # Port 22 is the only way in. `allowedSSHSource` defaults to "*" so the VM stays
  # reachable from campus, home, and coffee-shop networks during the labs — but that
  # does mean the SSH port is exposed to the internet for the whole semester.
  # Authentication is SSH-key-only (see linuxvm.tf), which is what makes that
  # acceptable. Set allowedSSHSource to your own IP/CIDR to narrow it.
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowedSSHSource
    destination_address_prefix = "*"
  }
}