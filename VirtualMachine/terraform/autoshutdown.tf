# Daily auto-shutdown for the student VM.
#
# This is the same feature as the portal's VM > Operations > Auto-shutdown blade. At
# autoShutdownTime every day Azure DEALLOCATES the VM: compute billing stops, the disk
# and the static public IP survive, and nothing is deleted. It never starts the VM
# again - that is `az vm start` (or the portal Start button) before each session.
#
# The schedule is a Microsoft.DevTestLab resource, so that namespace has to be
# registered on the subscription. providers.tf sets resource_provider_registrations
# = "none" and students cannot register providers, so the INSTRUCTOR does it once per
# subscription (see the instructor note in the module README). Without it every apply
# fails with "409 MissingSubscriptionRegistration ... Microsoft.DevTestLab".

locals {
  # Students type "23:00" as readily as "2300"; Azure only accepts HHmm.
  auto_shutdown_hhmm   = replace(var.autoShutdownTime, ":", "")
  auto_shutdown_notify = var.autoShutdownNotificationEmail != ""
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "student-vm-shutdown" {
  virtual_machine_id = azurerm_linux_virtual_machine.student-vm.id
  location           = azurerm_resource_group.studentRG.location
  enabled            = var.autoShutdownEnabled

  daily_recurrence_time = local.auto_shutdown_hhmm
  timezone              = var.autoShutdownTimezone

  # With an email set, Azure sends a warning 30 minutes before the shutdown. The mail
  # carries links to postpone or skip that night's shutdown, which is the escape hatch
  # for a long-running job.
  notification_settings {
    enabled         = local.auto_shutdown_notify
    email           = local.auto_shutdown_notify ? var.autoShutdownNotificationEmail : null
    time_in_minutes = 30
  }
}
