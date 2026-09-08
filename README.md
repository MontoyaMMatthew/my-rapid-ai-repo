# JHU Production AI - Module 01:

In this module we are setting up our Azure Virtual Machine and VSCode to enable us to complete the upcoming projects for this semester!

## Prerequisites

Before starting this module, ensure you have the following installed on your local machine:

- **[Visual Studio Code](https://code.visualstudio.com/)** - Code editor for development and remote SSH access, with the **Remote - SSH** extension (`ms-vscode-remote.remote-ssh`)
- **[Terraform](https://developer.hashicorp.com/terraform/install)** - Infrastructure as Code tool for deploying Azure resources (version 1.9.0 or newer)
- **[Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)** - Command-line tool for authenticating and managing Azure resources
- **[Git](https://git-scm.com/downloads)** - to clone this repository

You also need an **SSH key pair**. The VM is key-only, password login is disabled, and
`terraform apply` will not run without a public key to install:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/azure_lab -C "jhu-ai-lab"
```

It asks two questions:

```
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
```

**Set a passphrase.** The private key is the only credential for a VM whose SSH port faces
the internet. If your laptop is lost or the file is copied, the passphrase is what stops
whoever has it from logging in as you. Pick something you can type from memory; it is not
recoverable, and losing it means generating a new key pair and re-deploying.

Pressing Enter twice for an empty passphrase also works, and the deployment does not care
either way. You are trading the protection above for never being prompted.

With a passphrase, SSH asks for it every time it uses the key, and VS Code Remote - SSH
connects several times per session. Load the key into `ssh-agent` once per login and it
stops asking:

```bash
# macOS / Linux
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/azure_lab
```

```powershell
# Windows, in PowerShell (one-time setup, then ssh-add on each login)
Get-Service ssh-agent | Set-Service -StartupType Automatic
Start-Service ssh-agent
ssh-add $HOME\.ssh\azure_lab
```

That gives you `~/.ssh/azure_lab` (your private key, which never leaves your machine) and
`~/.ssh/azure_lab.pub` (the public half, which Terraform installs on the VM). Keep the
default path unless you change `sshPublicKeyPath` in your variables file to match.

## Your Azure Subscription

Terraform deploys into whichever Azure subscription you point it at, and it has no default.
Before you deploy anything you have to fill in the `studentSubscriptionId` parameter in
[`VirtualMachine/terraform/student.tfvars.json`](./VirtualMachine/terraform/student.tfvars.json),
which ships with a placeholder:

```json
"studentSubscriptionId": "REPLACE-WITH-YOUR-SUBSCRIPTION-ID",
```

<!--
NOTE(instructor): both Azure Subscription pages exist but were unpublished as of
2026-08-31 (604: course 135329, page id 3447899; 704: course 135509, page id 3444190),
so the links below 404 for students until each course's Module 0 is released.

INSTRUCTOR SETUP, once per subscription, before any student deploys: register the
resource providers. providers.tf sets resource_provider_registrations = "none", so
Terraform will not do it and students cannot (needs subscription-level rights).
  az provider register --namespace Microsoft.Network    --subscription <id>
  az provider register --namespace Microsoft.Compute    --subscription <id>
  az provider register --namespace Microsoft.Storage    --subscription <id>
  az provider register --namespace Microsoft.DevTestLab --subscription <id>
Microsoft.DevTestLab is for the VM auto-shutdown schedule (autoshutdown.tf), added
2026-09-01; a subscription registered before then needs that one added on its own.
Skipping any of these fails every deployment with 409 MissingSubscriptionRegistration.

student.tfvars.json is tracked in git. Restore the placeholders in it before committing,
so students never receive a real subscription ID or someone else's resource names.
Status (checked 2026-09-01): all four namespaces show Registered on both
        8738094a (RAPIDAI) and 454f8f24 (PRODUCTIONAI). Microsoft.DevTestLab was
        registered on 2026-09-01 after an apply on RAPIDAI hit the 409 for it.
-->

**The subscription name and ID for your course are on the Azure Subscription page in
Module 0 on Canvas.** This repository serves two courses that deploy into two different
subscriptions, so use the page for the course you are enrolled in:

| Your course | Subscription page | Subscription name |
|---|---|---|
| EN.705.604 (Production AI) | <https://jhu.instructure.com/courses/135329/pages/azure-subscription> | `JH-WSE-CLASS-EP-PRODUCTIONAI` |
| EN.705.704 (Rapid AI Systems) | <https://jhu.instructure.com/courses/135509/pages/azure-subscription> | `JH-WSE-CLASS-EP-RAPIDAI` |

Copy the subscription ID from your course's page into `student.tfvars.json`, then confirm
your Azure CLI is pointed at the same subscription before you run Terraform. The
subscription name from `az account show` must match the name in the table for your course:

```bash
az login
az account show --output table                     # which subscription am I in?
az account list --output table                     # which ones can I see?
az account set --subscription <SUBSCRIPTION-ID>    # switch to the course subscription
```

Running `terraform apply` against the wrong subscription is the expensive kind of mistake:
the resources land somewhere nobody is watching, and they keep billing after you have
forgotten they exist.

## Editing student.tfvars.json

[`VirtualMachine/terraform/student.tfvars.json`](./VirtualMachine/terraform/student.tfvars.json)
is the only file you edit to deploy. Terraform validates every value in it and refuses to
plan until the placeholders are gone, naming the exact key that is still wrong.

| Key | Ships as | Change it to |
|---|---|---|
| `studentSubscriptionId` | `REPLACE-WITH-YOUR-SUBSCRIPTION-ID` | The subscription ID from your course's Azure Subscription page, see [above](#your-azure-subscription). |
| `studentRGName`, `studentVNETName`, `studentIPName`, `studentNSGName`, `studentNICName`, `studentVMName`, `studentVMDiskName` | `dev-jhu-example-...-use` | The same string with `example` replaced by your name or initials. The subscription is shared with the whole class, so names must be unique and it must be obvious which resources are yours. |
| `studentVMUsername` | `azureuser` | Leave it. |
| `autoShutdownTime` | `REPLACE-WITH-HHMM` | The time of day the VM shuts itself down, every day. 24-hour clock, `2300` for 11 PM. Eastern time unless you add `autoShutdownTimezone`. |
| `autoShutdownNotificationEmail` | `""` | Optional. Your email address if you want a warning 30 minutes before each shutdown, with a link to postpone it. Leave `""` for no email. |

A completed file, for a student named J. Smith who wants the VM off at 11 PM Eastern:

```json
{
	"_comment": "...leave this line as it is...",

	"studentSubscriptionId": "12345678-abcd-4ef0-9876-0123456789ab",

	"studentRGName": "dev-jhu-jsmith-rg-use",
	"studentVNETName": "dev-jhu-jsmith-vnet-use",
	"studentIPName": "dev-jhu-jsmith-ip-use",
	"studentNSGName": "dev-jhu-jsmith-nsg-use",
	"studentNICName": "dev-jhu-jsmith-nic-use",
	"studentVMName": "dev-jhu-jsmith-linuxvm-use",
	"studentVMDiskName": "dev-jhu-jsmith-linuxvmdisk-use",

	"studentVMUsername": "azureuser",

	"autoShutdownTime": "2300",
	"autoShutdownNotificationEmail": "jsmith@jh.edu"
}
```

The `_comment` line is only a note. Leave it or delete it; Terraform ignores it either way.

Every other setting has a default and is not in the file. Add a key only if you want to
override it. The full list with defaults is in the
[deployment guide](./docs/VirtualMachine.md#1-configure-variables):

- `autoShutdownTimezone`, default `Eastern Standard Time`. Use a Windows time-zone name such
  as `Pacific Standard Time` or `UTC` if you are not on Eastern time.
- `autoShutdownEnabled`, default `true`. Set it to `false` to switch the daily shutdown off.
- `studentVMSize`, `diskSizeGB`, `allowedSSHSource`, `sshPublicKeyPath`: machine size, disk
  size, who can reach port 22, and where your public key is.

About the auto-shutdown: at `autoShutdownTime` every day Azure deallocates the VM, so a
machine you forgot about stops billing for compute by the next morning. Nothing is deleted,
and the VM never starts itself; the
[deployment guide](./docs/VirtualMachine.md#3-auto-shutdown) has the start command. Pick a
time after you would normally have stopped for the night.

### Already deployed? Add the auto-shutdown to your existing VM

If you ran `terraform apply` before the auto-shutdown existed, your VM has no schedule yet.
Adding one does not touch the VM:

1. Save a copy of your current `student.tfvars.json` values somewhere, then `git pull` in
   the cloned repository to pick up the new Terraform files.
2. Open your `student.tfvars.json` and add the two new keys after `studentVMUsername`. Note
   the comma that now ends the `studentVMUsername` line:

   ```json
   "studentVMUsername": "azureuser",

   "autoShutdownTime": "2300",
   "autoShutdownNotificationEmail": ""
   ```

3. Plan, from `VirtualMachine/terraform`:

       $ terraform plan -var-file="student.tfvars.json"

   The last line must read exactly **`Plan: 1 to add, 0 to change, 0 to destroy.`** and the
   one addition is `azurerm_dev_test_global_vm_shutdown_schedule`. Anything else means a
   name in the file no longer matches what you deployed. Stop, fix the file, and plan again.
   Never apply a plan that destroys or replaces anything.
4. Apply:

       $ terraform apply -var-file="student.tfvars.json"

   The VM keeps running; only the schedule is created.
5. If the plan fails with `409 MissingSubscriptionRegistration` mentioning
   `Microsoft.DevTestLab`, the subscription has not been set up for this yet. You cannot fix
   that yourself; tell the instructor.

To change the time later, edit `autoShutdownTime` and run `terraform apply` again. The plan
then shows `0 to add, 1 to change, 0 to destroy`.

## What Comes Installed on the VM

You install nothing by hand. At first boot the VM runs
[`VirtualMachine/scripts/custom_data.sh`](./VirtualMachine/scripts/custom_data.sh), which
installs the toolchain for the whole semester - that script is the source of truth, and
this section is the readable summary of it.

**The install runs in the background for 15-25 minutes after `terraform apply` finishes.**
A VM that looks empty right after deployment is still provisioning. Check it from a
terminal on the VM:

```bash
cloud-init status --wait               # blocks until provisioning is done
cat /var/log/provision-summary.txt     # every line should read OK
```

### System tools

| Tool | Used from |
|---|---|
| `git`, `unzip`, `jq`, `build-essential`, `tmux`, `htop`, `vim` | Module 01 |
| `python3.12` (alongside the system Python 3.10, which is deliberately left alone) | Module 01 |
| `az` - Azure CLI | Module 01 |
| `func` - Azure Functions Core Tools 4 | Azure Functions work |
| `docker` with the buildx and compose plugins | Module 08 |
| `kubectl`, `helm`, `terraform` | Module 09 |
| `node` 22 via nvm, installed in your home directory | tooling |
| `claude` - Claude Code CLI, in `~/.local/bin` | AI-assisted development, all modules |

### Python environment

A virtual environment at `~/ai-dev`, built on Python 3.12, **activated automatically on
login** - your prompt shows `(ai-dev)`. It contains:

- **AI clients:** `anthropic`, `openai`
- **Frameworks (CPU builds - the course subscription has no GPU SKUs):** `torch`,
  `torchvision`, `torchaudio`, `tensorflow-cpu`, `scikit-learn`
- **Hugging Face:** `transformers`, `datasets`, `huggingface_hub`, `accelerate`, `peft`,
  `tokenizers`, `evaluate`
- **LangChain:** `langchain`, `langchain-anthropic`, `langchain-openai`, `langchain-community`
- **Data science:** `numpy`, `pandas`, `scipy`, `matplotlib`, `seaborn`, `plotly`,
  `jupyter`, `ipykernel`, `ipywidgets`
- **MLOps:** `mlflow`, `wandb`, `dvc`
- **Azure SDKs:** `azure-identity`, `azure-mgmt-compute`, `azure-storage-blob`
- **Utilities:** `python-dotenv`, `tqdm`, `rich`, `httpx`, `requests`, `pydantic`

### What the provisioning leaves behind

| File on the VM | What it is |
|---|---|
| `/var/log/provision-summary.txt` | Self-check: one `OK`/`FAIL` line per tool and package, then a final `RESULT:` line |
| `~/requirements.txt` | `pip freeze` of the exact environment you were handed |
| `/var/log/cloud-init-output.log` | The full install log, for troubleshooting |

Two things that only take effect on your **next** login after provisioning finishes:
running `docker` without `sudo`, and the `(ai-dev)` prompt if you were logged in during the
install. If either is missing, log out and back in before assuming something failed.

**Not installed:** your API keys and your Claude sign-in. Keys are yours; put them in a
`.env` file that git ignores, and never commit them. For Claude Code, run `claude` once on
the VM and log in with your own account.

## Topics

This module contains the following topics that are recommended to be completed in the following order:

1. [Deploy Virtual Machine](./docs/VirtualMachine.md)
2. [Setup VSCode](./docs/VSCodeSetup.md)
3. [Optional: Open WebUI and Ollama](./docs/OpenWebUI.md)
