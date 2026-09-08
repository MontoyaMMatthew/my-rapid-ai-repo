output "public_ip" {
  value       = azurerm_public_ip.student-public-ip.ip_address
  description = "VM public IP address"
}

output "ssh_command" {
  value       = "ssh -i ${replace(var.sshPublicKeyPath, ".pub", "")} ${var.studentVMUsername}@${azurerm_public_ip.student-public-ip.ip_address}"
  description = "Ready-to-paste SSH command"
}

output "resource_group" {
  value       = azurerm_resource_group.studentRG.name
  description = "Resource group holding every resource in this deployment"
}

output "provisioning_note" {
  value       = "GIVE THE VM 20 MINUTES: all course tools install in the background after this completes. Check progress with 'cloud-init status --wait' on the VM, then confirm with 'cat /var/log/provision-summary.txt' (every line should read OK)."
  description = "Reminder that the VM is not ready the instant Terraform finishes"
}

output "auto_shutdown" {
  value       = "Your VM deallocates every day at ${substr(local.auto_shutdown_hhmm, 0, 2)}:${substr(local.auto_shutdown_hhmm, 2, 2)} ${var.autoShutdownTimezone}${var.autoShutdownEnabled ? "" : " (currently DISABLED by autoShutdownEnabled)"}. It never starts itself: before each session run 'az vm start --resource-group ${azurerm_resource_group.studentRG.name} --name ${azurerm_linux_virtual_machine.student-vm.name}'."
  description = "When the VM shuts itself down, and how to start it again"
}
