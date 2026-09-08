
resource "azurerm_network_interface" "student-nic" {
  name                = var.studentNICName
  location            = azurerm_resource_group.studentRG.location
  resource_group_name = azurerm_resource_group.studentRG.name

  ip_configuration {
    name                          = "student_configuration"
    subnet_id                     = azurerm_subnet.vm-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.student-public-ip.id
  }
}

resource "azurerm_network_interface_security_group_association" "associate-nsg-nic" {
  network_interface_id      = azurerm_network_interface.student-nic.id
  network_security_group_id = azurerm_network_security_group.student-nsg.id
}

resource "azurerm_linux_virtual_machine" "student-vm" {
  name                  = var.studentVMName
  location              = azurerm_resource_group.studentRG.location
  resource_group_name   = azurerm_resource_group.studentRG.name
  network_interface_ids = [azurerm_network_interface.student-nic.id]

  # 4 vCPU / 16 GB. The AI stack (PyTorch + TensorFlow + transformers) does not fit
  # comfortably in the 8 GB of a D2s_v3. The course subscription has no GPU SKUs, so
  # this stays a CPU machine for the whole semester.
  size = var.studentVMSize

  # Key-only authentication. Port 22 is internet-facing (see network.tf), so a
  # password — especially a shared classroom one — is not an acceptable credential.
  disable_password_authentication = true

  # pathexpand, not a bare file(): Terraform's file() does not expand "~", so the
  # default "~/.ssh/azure_lab.pub" fails at plan time with "no file exists at
  # ~/.ssh/azure_lab.pub" on every machine.
  admin_ssh_key {
    username   = var.studentVMUsername
    public_key = file(pathexpand(var.sshPublicKeyPath))
  }

  os_disk {
    name                 = var.studentVMDiskName
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.diskSizeGB
  }

  # filebase64, NOT templatefile: templatefile would interpolate every ${...} in the
  # provisioning script and break it. The script derives the admin user from uid 1000
  # at runtime, so it needs no substitution.
  custom_data = filebase64("${path.module}/../scripts/custom_data.sh")

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }
  computer_name  = "hostname"
  admin_username = var.studentVMUsername
}