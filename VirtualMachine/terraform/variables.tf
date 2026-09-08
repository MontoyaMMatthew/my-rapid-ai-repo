# The student*Name variables below ship with "example" in them, and a student who deploys
# without editing them creates resources nobody can attribute in a subscription shared by
# the whole class. Each one therefore carries a validation block that rejects "example".
#
# Validation runs during `terraform plan`, so a missed name fails immediately and names the
# variable that is wrong, rather than surfacing later as a duplicate-name error from Azure
# or, worse, as a successful deployment of resources with somebody else's name on them.

# JSON has no comment syntax, so the note at the top of student.tfvars.json has to be a real
# key. Declaring it here is what stops Terraform warning "value for undeclared variable" on
# every single plan. Nothing reads it.
variable "_comment" {
  type    = string
  default = ""
}

variable "studentSubscriptionId" {
  type        = string
  description = "Course Azure subscription ID, from the Module 0 Azure Subscription page on Canvas. See the module README."

  validation {
    condition     = var.studentSubscriptionId != "REPLACE-WITH-YOUR-SUBSCRIPTION-ID"
    error_message = "studentSubscriptionId is still the placeholder. Put the course subscription ID from the Module 0 Azure Subscription page on Canvas into student.tfvars.json, then run 'az account show' to confirm your CLI is pointed at the same subscription."
  }

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.studentSubscriptionId))
    error_message = "studentSubscriptionId is not a valid Azure subscription ID. It is a GUID of the form 12345678-abcd-4ef0-9876-0123456789ab. Run 'az account show --query id -o tsv' to print the one you are logged in to."
  }
}

variable "studentLocation" {
  type    = string
  default = "East US"
}

variable "studentRGName" {
  type        = string
  description = "Resource group name. Replace 'example' with your own name or initials."

  validation {
    condition     = !can(regex("(?i)example", var.studentRGName))
    error_message = "studentRGName still contains 'example'. Replace 'example' with your own name or initials in student.tfvars.json, for example 'dev-jhu-jsmith-rg-use'. The subscription is shared with the whole class, so resource names must be unique and it must be obvious which resources are yours."
  }
}

variable "studentVNETName" {
  type        = string
  description = "Virtual network name. Replace 'example' with your own name or initials."

  validation {
    condition     = !can(regex("(?i)example", var.studentVNETName))
    error_message = "studentVNETName still contains 'example'. Replace 'example' with your own name or initials in student.tfvars.json, for example 'dev-jhu-jsmith-vnet-use'."
  }
}

variable "studentIPName" {
  type        = string
  description = "Public IP name. Replace 'example' with your own name or initials."

  validation {
    condition     = !can(regex("(?i)example", var.studentIPName))
    error_message = "studentIPName still contains 'example'. Replace 'example' with your own name or initials in student.tfvars.json, for example 'dev-jhu-jsmith-ip-use'."
  }
}

variable "studentNSGName" {
  type        = string
  description = "Network security group name. Replace 'example' with your own name or initials."

  validation {
    condition     = !can(regex("(?i)example", var.studentNSGName))
    error_message = "studentNSGName still contains 'example'. Replace 'example' with your own name or initials in student.tfvars.json, for example 'dev-jhu-jsmith-nsg-use'."
  }
}

variable "studentNICName" {
  type        = string
  description = "Network interface name. Replace 'example' with your own name or initials."

  validation {
    condition     = !can(regex("(?i)example", var.studentNICName))
    error_message = "studentNICName still contains 'example'. Replace 'example' with your own name or initials in student.tfvars.json, for example 'dev-jhu-jsmith-nic-use'."
  }
}

variable "studentVMName" {
  type        = string
  description = "Virtual machine name. Replace 'example' with your own name or initials."

  validation {
    condition     = !can(regex("(?i)example", var.studentVMName))
    error_message = "studentVMName still contains 'example'. Replace 'example' with your own name or initials in student.tfvars.json, for example 'dev-jhu-jsmith-linuxvm-use'."
  }
}

variable "studentVMDiskName" {
  type        = string
  description = "OS disk name. Replace 'example' with your own name or initials."

  validation {
    condition     = !can(regex("(?i)example", var.studentVMDiskName))
    error_message = "studentVMDiskName still contains 'example'. Replace 'example' with your own name or initials in student.tfvars.json, for example 'dev-jhu-jsmith-linuxvmdisk-use'."
  }
}

variable "studentVMUsername" {
  type = string
}

variable "studentVMSize" {
  type        = string
  description = "Azure VM SKU. Course baseline is 4 vCPU / 16 GB. The course subscription only permits the v7 x86 generation (v3-v6 return SkuNotAvailable); Standard_D4as_v7 is the cheaper AMD equivalent."
  default     = "Standard_D4s_v7"
}

variable "sshPublicKeyPath" {
  type        = string
  description = "Path to your SSH public key, generated in the Lab 1 prerequisites."
  default     = "~/.ssh/azure_lab.pub"

  # Caught here rather than as a confusing file() error deeper in the plan. The private
  # half is the same path without .pub, so pointing at it by mistake is an easy slip.
  validation {
    condition     = endswith(var.sshPublicKeyPath, ".pub")
    error_message = "sshPublicKeyPath must point at your PUBLIC key, the file ending in .pub, not your private key. The default is ~/.ssh/azure_lab.pub."
  }

  validation {
    condition     = fileexists(pathexpand(var.sshPublicKeyPath))
    error_message = "No SSH public key was found at sshPublicKeyPath. Generate one first with: ssh-keygen -t ed25519 -f ~/.ssh/azure_lab -C \"jhu-ai-lab\". The VM is key-only, so the deployment cannot proceed without it."
  }
}

variable "allowedSSHSource" {
  type        = string
  description = "Source IP or CIDR permitted to reach port 22. '*' means anywhere; narrow it to your own address if you can."
  default     = "*"
}

variable "diskSizeGB" {
  type        = number
  description = "VM Disk size value that represents 'powers of two' in the form 2^n"
  default     = 128
}

# Auto-shutdown. The VM deallocates itself every day at autoShutdownTime (see
# autoshutdown.tf), so a machine somebody forgot about stops billing for compute by the
# next morning. The time is deliberately required: the placeholder is rejected so that
# every student picks a time that suits their own schedule rather than inheriting one
# that cuts them off mid-session.
variable "autoShutdownTime" {
  type        = string
  description = "Daily shutdown time for the VM, 24-hour clock, as HHmm or HH:mm (for example \"2300\" or \"23:00\" for 11 PM, \"0130\" for 1:30 AM). Read in autoShutdownTimezone."

  validation {
    condition     = var.autoShutdownTime != "REPLACE-WITH-HHMM"
    error_message = "autoShutdownTime is still the placeholder. Put the time of day you want the VM to shut itself down into student.tfvars.json, 24-hour clock, for example \"2300\" for 11 PM. The time is read in autoShutdownTimezone, which defaults to Eastern."
  }

  validation {
    condition     = var.autoShutdownTime == "REPLACE-WITH-HHMM" || can(regex("^([01][0-9]|2[0-3]):?[0-5][0-9]$", var.autoShutdownTime))
    error_message = "autoShutdownTime is not a valid time. Use the 24-hour clock as HHmm or HH:mm: \"2300\" or \"23:00\" for 11 PM, \"0130\" for 1:30 AM, \"1800\" for 6 PM. Hours run 00-23 and minutes 00-59."
  }
}

variable "autoShutdownTimezone" {
  type        = string
  description = "Time zone autoShutdownTime is read in, as a Windows time-zone ID, which is what Azure expects. The 'Standard Time' names also cover daylight saving. Examples: \"Eastern Standard Time\", \"Central Standard Time\", \"Mountain Standard Time\", \"Pacific Standard Time\", \"UTC\"."
  default     = "Eastern Standard Time"

  validation {
    condition     = length(trimspace(var.autoShutdownTimezone)) > 0
    error_message = "autoShutdownTimezone cannot be empty. Use a Windows time-zone ID such as \"Eastern Standard Time\" (the default), \"Pacific Standard Time\" or \"UTC\"."
  }
}

variable "autoShutdownNotificationEmail" {
  type        = string
  description = "Optional. If set, Azure emails this address 30 minutes before the daily shutdown, with links to postpone or skip it. Leave empty for no warning."
  default     = ""

  validation {
    condition     = var.autoShutdownNotificationEmail == "" || can(regex("^[^@ ]+@[^@ ]+[.][^@ ]+$", var.autoShutdownNotificationEmail))
    error_message = "autoShutdownNotificationEmail does not look like an email address. Either leave it empty (no warning email) or set it to an address such as jsmith@jh.edu."
  }
}

variable "autoShutdownEnabled" {
  type        = bool
  description = "Set to false to keep the schedule but switch the daily shutdown off. Leave true unless you have a reason."
  default     = true
}
