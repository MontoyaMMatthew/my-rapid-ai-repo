# JHU Production AI - Module 01: Virtual Machine Infrastructure

This module contains Terraform configurations for deploying a Linux virtual machine infrastructure on Microsoft Azure. The infrastructure is designed for educational purposes in the Johns Hopkins University Production AI course.

## Prerequisites

The tool installs, the SSH key you have to generate, and the subscription ID you have to fill
in are all in the [module README](../README.md). Do that first. In particular, **the
deployment will not run until `studentSubscriptionId` in `student.tfvars.json` holds the
course subscription ID from the Module 0 Azure Subscription page on Canvas.**

## Project Organization

```
module01/
├── README.md                           # Prerequisites, SSH key, subscription setup
├── docs/
│   ├── VirtualMachine.md               # This documentation file
│   ├── VSCodeSetup.md                  # Connecting VS Code to the VM
│   └── OpenWebUI.md                    # Optional: Open WebUI and Ollama on the VM
└── VirtualMachine/                     # Virtual machine deployment directory
    ├── scripts/
    │   └── custom_data.sh              # VM initialization script (cloud-init)
    └── terraform/                      # Terraform configuration files
        ├── autoshutdown.tf             # Daily auto-shutdown schedule for the VM
        ├── linuxvm.tf                  # Virtual machine and NIC resource definitions
        ├── network.tf                  # Networking components (VNet, subnet, NSG, public IP)
        ├── outputs.tf                  # Public IP, SSH command, resource group
        ├── providers.tf                # Azure provider configuration
        ├── resource-group.tf           # Resource group definition
        ├── student.tfvars.json         # Variable values for deployment - you edit this
        ├── variables.tf                # Variable declarations
        ├── terraform.tfstate           # Terraform state file (managed automatically)
        └── terraform.tfstate.backup    # Terraform state backup
```

## Terraform Deployment Instructions

### 1. Configure Variables

Open the cloned folder in Visual Studio Code and edit
`VirtualMachine/terraform/student.tfvars.json`. The
[module README](../README.md#editing-studenttfvarsjson) walks through every key with a
completed example:

| Variable | What to set it to |
|---|---|
| `studentSubscriptionId` | The course subscription ID, from the Module 0 Azure Subscription page. See the [module README](../README.md#your-azure-subscription). |
| `studentRGName` and every other `student*Name` | Replace `example` with your own name. Names must be unique in the shared subscription. |
| `studentVMUsername` | Leave as `azureuser` unless you have a reason to change it. |
| `autoShutdownTime` | The time of day the VM shuts itself down, every day. 24-hour clock as `HHmm` or `HH:mm`, so `2300` or `23:00` is 11 PM. Eastern time unless you set `autoShutdownTimezone`. See [Auto-shutdown](#3-auto-shutdown). |
| `autoShutdownNotificationEmail` | Optional. Your email address if you want a warning 30 minutes before each shutdown, with a link to postpone it. Leave it `""` for no email. |

**Terraform will refuse to plan until you have done all three.** The variables are validated,
so a subscription ID left as the placeholder, a resource name still containing `example`, or a
shutdown time left as the placeholder, stops the deployment with a message naming the exact
variable and the line in `student.tfvars.json`.
This is deliberate: the subscription is shared with the whole class, and a resource nobody can
attribute is a resource nobody will clean up. Terraform reports every offending variable at
once, so you can fix them in a single pass.

These variables are declared in `variables.tf` and already have sensible defaults, so they
are not in `student.tfvars.json` unless you want to override one:

| Variable | Default | Purpose |
|---|---|---|
| `studentLocation` | `East US` | Azure region for every resource. |
| `studentVMSize` | `Standard_D4s_v7` | 4 vCPU / 16 GB. The course subscription only permits the v7 generation of x86 sizes, and has no GPU SKUs, so this is a CPU machine all semester. |
| `sshPublicKeyPath` | `~/.ssh/azure_lab.pub` | The public key installed on the VM. |
| `allowedSSHSource` | `*` | Source IP or CIDR allowed to reach port 22. Narrow it to your own address if you can. |
| `diskSizeGB` | `128` | OS disk size in GB. |
| `autoShutdownTimezone` | `Eastern Standard Time` | Time zone `autoShutdownTime` is read in, as a Windows time-zone ID. The "Standard Time" names also cover daylight saving. Others: `Central Standard Time`, `Mountain Standard Time`, `Pacific Standard Time`, `UTC`. |
| `autoShutdownEnabled` | `true` | Set to `false` to switch the daily shutdown off without removing it. |

### 2. Deploy Infrastructure

Use the terminal in Visual Studio Code.

Navigate to the Terraform configuration directory:

    $ cd VirtualMachine/terraform

Initialize Terraform:

    $ terraform init

Review the deployment plan:

    $ terraform plan -var-file="student.tfvars.json"

Apply the configuration:

    $ terraform apply -var-file="student.tfvars.json"

Type `yes` when prompted to confirm the deployment.

When it finishes, Terraform prints your VM's public IP and a ready-to-paste SSH command.
Save both, you need them for [VS Code setup](./VSCodeSetup.md).

### 3. Auto-shutdown

The VM shuts itself down every day at `autoShutdownTime`. "Shuts down" here means Azure
**deallocates** it: the machine stops, compute billing stops, and the disk, your files and the
public IP all stay exactly as they were. Nothing is deleted. It is the safety net for the day
you forget; a VM that is already deallocated when the time comes is left alone.

Two things it does not do:

- **It never starts the VM.** Before each session, start it yourself:

      $ az vm start --resource-group <your-rg> --name <your-vm>

  or use the Start button on the VM's page in the Azure portal. `terraform output` prints the
  exact command for your names.
- **It only runs once a day.** Deallocating when you finish for the day is still the cheapest
  habit; the schedule just catches the times you do not.

If you set `autoShutdownNotificationEmail`, Azure emails you 30 minutes before, and the email
carries links to postpone or skip that night's shutdown. That is the escape hatch for a long
job. The same controls are on the VM's page in the portal under **Auto-shutdown**. To change
the time, edit `autoShutdownTime` in `student.tfvars.json` and run `terraform apply` again;
only the schedule changes, the VM is untouched.

### 4. Deallocate and Destroy (for your information - keep the VM)

To stop paying for compute between sessions without waiting for the schedule:

    $ az vm deallocate --resource-group <your-rg> --name <your-vm>
    $ az vm start      --resource-group <your-rg> --name <your-vm>

To remove everything:

    $ terraform destroy -var-file="student.tfvars.json"

**Do not destroy this VM during the semester.** It is your development machine for the whole
course, and rebuilding it costs you another provisioning cycle. Deallocate instead.

## Azure Components Deployed

### 1. Resource Group (`azurerm_resource_group`)
- **Purpose**: Logical container that holds related Azure resources
- **Configuration**: Single resource group to organize all VM-related resources
- **Location**: Configurable via `studentLocation` variable (defaults to "East US")

### 2. Virtual Network (VNet) (`azurerm_virtual_network`)
- **Purpose**: Provides isolated network environment for Azure resources
- **Address Space**: 10.0.0.0/16 (65,536 IP addresses)
- **Function**: Enables secure communication between Azure resources

### 3. Subnet (`azurerm_subnet`)
- **Purpose**: Subdivides the virtual network for better organization and security
- **Address Range**: 10.0.1.0/24 (256 IP addresses)
- **Name**: "vmSubnet"
- **Function**: Hosts the virtual machine and its network interface

### 4. Public IP Address (`azurerm_public_ip`)
- **Purpose**: Provides internet connectivity to the virtual machine
- **SKU**: Standard. Basic SKU public IPs were retired on 30 September 2025 and can no longer be created.
- **Allocation**: Static, which Standard SKU requires. The IP survives a deallocate, so your `~/.ssh/config` keeps working between sessions.
- **Function**: Enables SSH access from the internet

### 5. Network Security Group (NSG) (`azurerm_network_security_group`)
- **Purpose**: Acts as a virtual firewall controlling network traffic
- **Rules**:
  - SSH (port 22) inbound, priority 1001, TCP
  - Source is the `allowedSSHSource` variable, which defaults to `*` so the VM stays reachable from campus, home, and other networks
- **Function**: Port 22 is the only way in. What makes an internet-facing SSH port acceptable is that authentication is key-only, see below.

### 6. Network Interface (`azurerm_network_interface`)
- **Purpose**: Connects the virtual machine to the virtual network
- **Configuration**:
  - Dynamic private IP allocation
  - Associated with public IP and subnet
- **Function**: Handles network communication for the VM

### 7. Network Interface Security Group Association
- **Purpose**: Links the network security group to the network interface
- **Function**: Applies firewall rules to the VM's network traffic

### 8. Linux Virtual Machine (`azurerm_linux_virtual_machine`)
- **Size**: Standard_D4s_v7 (4 vCPUs, 16 GB RAM). The AI stack does not fit comfortably in 8 GB. The course subscription only permits the v7 x86 generation, and has no GPU SKUs, so this is a CPU machine for the whole semester and the CPU builds of PyTorch and TensorFlow are what is installed.
- **Operating System**: Ubuntu Server 22.04 LTS (gen2)
- **Authentication**: SSH public key only. Password authentication is disabled.
- **Storage**: Premium SSD, size set by `diskSizeGB` (default 128 GB)
- **Initialization**: Runs `custom_data.sh` at first boot to install the toolchain

### 9. Custom Data Script (`custom_data.sh`)
- **Purpose**: Installs the entire course toolchain at first boot, so nobody installs anything by hand
- **Installs**: the full list is in the [module README](../README.md#what-comes-installed-on-the-vm); the script itself is the source of truth
- **Execution**: Runs once, as root, during first boot via cloud-init
- **Result**: Writes a pass/fail summary to `/var/log/provision-summary.txt` and freezes the environment to `~/requirements.txt`

### 10. Auto-shutdown Schedule (`azurerm_dev_test_global_vm_shutdown_schedule`)
- **Purpose**: Deallocates the VM every day at `autoShutdownTime`, so a forgotten machine stops billing for compute
- **Configuration**: Time from `autoShutdownTime`, time zone from `autoShutdownTimezone`, optional 30-minute warning email to `autoShutdownNotificationEmail`, switched off with `autoShutdownEnabled = false`
- **Function**: The same feature as the **Auto-shutdown** blade on the VM's portal page. It stops and deallocates; it never starts the VM, and it deletes nothing. The OS disk and public IP keep billing while the VM is stopped.
- **Requires**: The `Microsoft.DevTestLab` resource provider registered on the subscription, which the instructor does once for the class. See Troubleshooting.

## VM Access Information

After a successful deployment, Terraform prints:

- `public_ip` - the VM's public IP address
- `ssh_command` - a ready-to-paste SSH command
- `resource_group` - the resource group holding every resource in this deployment
- `auto_shutdown` - when the VM shuts itself down each day, and the `az vm start` command for your names

Connect with your private key:

```bash
ssh -i ~/.ssh/azure_lab azureuser@<public-ip-address>
```

If you set a passphrase on the key, SSH asks for it (`Enter passphrase for key`); that is
expected. There is no **password**. If you are prompted for one, SSH did not find your key:
check the `-i` path and that it matches the `sshPublicKeyPath` you deployed with.

## Important Notes

- **The VM is not ready when `terraform apply` finishes.** The machine exists, but the toolchain installs in the background for a further 15-25 minutes.
- Watch it with `sudo tail -f /var/log/cloud-init-output.log`, or block until it is done with `cloud-init status --wait`
- When it reports `status: done`, read `cat /var/log/provision-summary.txt` and check nothing says FAIL
- Docker without `sudo` takes effect on your **next** login, not the one where the install finished
- Ensure your Azure subscription has sufficient quota for the VM size
- Deallocate the VM when you finish for the day. The daily auto-shutdown at `autoShutdownTime` is the safety net, not the routine: it fires once a day, and the VM bills until then
- The VM does not start itself after the daily shutdown. Run `az vm start` (or use the portal) before each session

## Security Considerations

- Authentication is SSH-key-only by design. Do not re-enable password authentication.
- Your private key (`~/.ssh/azure_lab`) never leaves your local machine and is never committed.
- Narrow `allowedSSHSource` from `*` to your own IP or CIDR if your address is stable.
- Never commit API keys. Put them in a `.env` file that git ignores.
- Monitor Azure costs and set up billing alerts
- Follow principle of least privilege for Azure permissions

## Troubleshooting

- **`still contains 'example'`**: you have not put your own name into every resource name in `student.tfvars.json`. The message names the variable.
- **`studentSubscriptionId is still the placeholder`**: fill in the course subscription ID, see the [module README](../README.md#your-azure-subscription)
- **`No SSH public key was found at sshPublicKeyPath`**: you have not generated the key pair yet, see the [module README](../README.md#prerequisites)
- **`autoShutdownTime is still the placeholder`**: set the time of day the VM should shut itself down in `student.tfvars.json`, 24-hour clock, for example `2300`. See [Auto-shutdown](#3-auto-shutdown)
- **`autoShutdownTime is not a valid time`**: use `HHmm` or `HH:mm` on the 24-hour clock, hours `00`-`23`, minutes `00`-`59`. `11pm` and `11:00 PM` are not accepted; `2300` is
- **`409 MissingSubscriptionRegistration` mentioning `Microsoft.DevTestLab`**: the subscription has not been set up for the auto-shutdown schedule yet. You cannot fix this yourself; tell the instructor, who registers the provider once for the whole class
- **Terraform Init Issues**: Ensure Azure CLI is authenticated (`az login`)
- **Deployment lands in the wrong subscription**: check `studentSubscriptionId` in `student.tfvars.json` against the Module 0 Azure Subscription page, and `az account show`
- **Deployment Failures**: Check Azure subscription limits and permissions
- **SSH Connection Issues**: Verify NSG rules, the public IP, and that you passed `-i ~/.ssh/azure_lab`
- **A tool reports "not found" after provisioning**: check `/var/log/provision-summary.txt` and `/var/log/cloud-init-output.log`
- **VM Not Responding**: Check Azure portal for VM status and boot diagnostics
