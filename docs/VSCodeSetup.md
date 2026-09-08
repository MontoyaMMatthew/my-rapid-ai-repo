# JHU Production AI - Module 01: Setup VSCode IDE

## 1. Install Visual Studio Code
- Go to the [VS Code download page](https://code.visualstudio.com/).
- Download the installer for your respective Operating System

## 2. Install the Remote - SSH Extension

Once installed, open VSCode and click on the Extensions icon (icon with 4 boxes) in the Activity Bar on the left, then search for **Remote - SSH** by Microsoft (`ms-vscode-remote.remote-ssh`) and install it.

### 2a. Configure and Connect to a Remote Host via SSH
#### PREREQUISITE: you __MUST__ have your student Virtual Machine deployed. Please follow the [Virtual Machine Instructions](VirtualMachine.md) if you have not done so.

1. **Get Your Virtual Machine IP**

   `terraform apply` printed it as the `public_ip` output, along with a ready-to-paste
   `ssh_command`. You can also find it in the Azure Portal on your VM's Connect tab.

2. **Create Your Remote Host Connection**

   The VM accepts your SSH key only, so the connection has to be told which key to use.
   Add this block to your local `~/.ssh/config` (create the file if it does not exist), and
   replace `<YOUR_VM_IP>` with your public IP:

   ```
   Host jhu-lab
       HostName <YOUR_VM_IP>
       User azureuser
       IdentityFile ~/.ssh/azure_lab
       ServerAliveInterval 60
   ```

   `IdentityFile` is the **private** key you generated in the prerequisites, the one without
   the `.pub` extension.

3. **Connect to your Azure VM with VSCode**

   Press `Ctrl + Shift + P` (`F1` also works), type and select **Remote-SSH: Connect to Host...**,
   then select `jhu-lab`. A new VS Code window opens connected to the VM.

   If you set a passphrase on your key, VS Code asks for it: the prompt says
   **Enter passphrase for key** and is normal. Load the key into `ssh-agent` (see the
   [module README](../README.md#prerequisites)) and it stops asking.

   A prompt for a **password** is different and means SSH did not find your key. The VM has
   no password to give. Check the `IdentityFile` path in `~/.ssh/config`.

   Open a terminal inside VS Code with ``Ctrl + ` `` (backtick). Type `exit` at any time to
   close the SSH session. To open a new VS Code session rooted at a different directory,
   change to that directory and type `code .` in the terminal.

4. **Confirm provisioning finished**

   The toolchain installs in the background for 15-25 minutes after the VM boots. In the
   VS Code terminal on the VM:

   ```bash
   cloud-init status --wait          # blocks until provisioning is done
   cat /var/log/provision-summary.txt # every line should read OK
   ```

## 3. Install Azure Tools Extension

Click on the Extensions icon (icon with 4 boxes) in the Activity Bar on the left, then search for "Azure Tools" by Microsoft and install the extension.

Install extensions **on the remote host**, not just locally. When you are connected over
Remote - SSH, the extension page shows an *Install in SSH: jhu-lab* button for that.

## 4. API Keys

Your API keys are yours and are not installed by the VM provisioning. Put them in a `.env`
file in your project directory on the VM, and make sure `.env` is in `.gitignore`.

**Never commit API keys to git.**
