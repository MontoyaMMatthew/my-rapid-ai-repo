#!/bin/bash
# =============================================================================
# JHU AI Systems — Module 01 VM provisioning
#
# Runs ONCE, as root, at first boot, via cloud-init (Azure `custom_data`).
# Installs the complete course toolchain so no student installs anything by hand.
#
#   Watch it:      sudo tail -f /var/log/cloud-init-output.log
#   Wait for it:   cloud-init status --wait
#   Result:        cat /var/log/provision-summary.txt
#
# Covers the whole semester, not just week 1:
#   Module 01  Python + AI/ML stack, Azure CLI, Claude Code CLI
#   Module 08  Docker
#   Module 09  kubectl, Helm, Terraform
#
# NOT handled here: API keys, and the Claude Code sign-in (the student runs `claude`
# once and logs in with their own account). Those are the student's own and are
# created after boot — see the Lab 1 page.
#
# NOTE FOR MAINTAINERS: this file is consumed with filebase64(), NOT templatefile().
# Do not switch back to templatefile() — Terraform would try to interpolate every
# ${...} in this script and the build would break.
# =============================================================================

set -uo pipefail   # NOT -e: one failed package must not abandon the whole build.

PYTHON_VERSION="3.12"
VENV_DIR="ai-dev"
NODE_VERSION="22"
LOG_TAG="[provision]"
SUMMARY="/var/log/provision-summary.txt"
FAILURES=0

# cloud-init runs as root long before anyone logs in. Everything student-owned must be
# created AS the admin user, or they inherit a home directory full of root-owned files
# and every later pip install dies with EACCES. uid 1000 is the Azure admin user.
TARGET_USER="$(getent passwd 1000 | cut -d: -f1)"
TARGET_HOME="$(getent passwd 1000 | cut -d: -f6)"

if [ -z "$TARGET_USER" ]; then
    echo "$LOG_TAG FATAL: no uid 1000; cannot determine the admin user." >&2
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

log()  { echo "$LOG_TAG $*"; }
step() { echo ""; echo "$LOG_TAG ===== $* ====="; }

# Record what worked and what did not, so a partial build is visible rather than silent.
check() {
    local label="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  OK    $label" >> "$SUMMARY"
    else
        echo "  FAIL  $label" >> "$SUMMARY"
        FAILURES=$((FAILURES + 1))
        log "WARNING: $label did not verify"
    fi
}

# Azure images run unattended-upgrades at boot and hold the apt lock for minutes.
# Without this wait the first apt-get races it and dies on "could not get lock".
wait_for_apt() {
    local i
    for i in $(seq 1 60); do
        if ! fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
           && ! fuser /var/lib/apt/lists/lock >/dev/null 2>&1; then
            return 0
        fi
        log "apt is locked by another process; waiting (${i}/60)"
        sleep 10
    done
    log "WARNING: apt still locked after 10 minutes; continuing anyway"
}

# Transient DNS/network failures are common during early boot. Retry rather than
# silently lose a package.
retry() {
    local n=0
    until "$@"; do
        n=$((n + 1))
        if [ "$n" -ge 3 ]; then
            log "WARNING: command failed after 3 attempts: $*"
            return 1
        fi
        log "retry ${n}/3: $*"
        sleep 15
    done
}

# pip must run as the student, inside their venv — never as root.
venv_pip() {
    sudo -u "$TARGET_USER" -H bash -lc \
        "source '$TARGET_HOME/$VENV_DIR/bin/activate' && pip install --no-input $*"
}

echo "$LOG_TAG started $(date -Is) for user '$TARGET_USER'" | tee "$SUMMARY"

# -----------------------------------------------------------------------------
step "1/10  Base system packages"
# -----------------------------------------------------------------------------
wait_for_apt
retry apt-get update
retry apt-get upgrade -y
retry apt-get install -y \
    software-properties-common ca-certificates curl wget gnupg \
    lsb-release apt-transport-https \
    git unzip jq build-essential libssl-dev libffi-dev \
    tmux htop vim

# -----------------------------------------------------------------------------
step "2/10  Python ${PYTHON_VERSION}"
# -----------------------------------------------------------------------------
# Ubuntu 22.04 (jammy) ships Python 3.10; newer interpreters come from deadsnakes.
# Installed ALONGSIDE the system python3 on purpose — changing the default python3
# breaks Ubuntu's own utilities (apt, unattended-upgrades, cloud-init itself).
retry add-apt-repository -y ppa:deadsnakes/ppa
wait_for_apt
retry apt-get update
retry apt-get install -y \
    "python${PYTHON_VERSION}" \
    "python${PYTHON_VERSION}-dev" \
    "python${PYTHON_VERSION}-venv"

# -----------------------------------------------------------------------------
step "3/10  Virtual environment (~/${VENV_DIR})"
# -----------------------------------------------------------------------------
sudo -u "$TARGET_USER" -H bash -lc \
    "python${PYTHON_VERSION} -m venv '$TARGET_HOME/$VENV_DIR'"

# Auto-activate on login so students never wonder which python they are running.
if ! grep -q "$VENV_DIR/bin/activate" "$TARGET_HOME/.bashrc" 2>/dev/null; then
    echo "source \$HOME/$VENV_DIR/bin/activate" >> "$TARGET_HOME/.bashrc"
fi

venv_pip --upgrade pip setuptools wheel

# -----------------------------------------------------------------------------
step "4/10  AI API clients"
# -----------------------------------------------------------------------------
venv_pip anthropic openai

# -----------------------------------------------------------------------------
step "5/10  Deep learning frameworks (CPU builds)"
# -----------------------------------------------------------------------------
# The course subscription has no GPU SKUs, so the VM is a CPU machine for the whole
# semester and CPU builds are the right ones. They also keep the image small.
venv_pip torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cpu
venv_pip tensorflow-cpu
venv_pip scikit-learn

# -----------------------------------------------------------------------------
step "6/10  Hugging Face, LangChain, data science, MLOps"
# -----------------------------------------------------------------------------
venv_pip transformers datasets huggingface_hub accelerate peft tokenizers evaluate
venv_pip langchain langchain-anthropic langchain-openai langchain-community
venv_pip numpy pandas scipy matplotlib seaborn plotly \
         jupyter ipykernel ipywidgets \
         python-dotenv tqdm rich httpx requests pydantic
venv_pip mlflow wandb dvc
venv_pip azure-identity azure-mgmt-compute azure-storage-blob

# -----------------------------------------------------------------------------
step "7/10  Azure CLI and Functions Core Tools"
# -----------------------------------------------------------------------------
retry bash -c 'curl -sL https://aka.ms/InstallAzureCLIDeb | bash'

retry bash -c 'curl -fsSL https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg'
echo "deb [arch=amd64] https://packages.microsoft.com/repos/microsoft-ubuntu-$(lsb_release -cs)-prod $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/dotnetdev.list
wait_for_apt
retry apt-get update
retry apt-get install -y azure-functions-core-tools-4

# -----------------------------------------------------------------------------
step "8/10  Docker  (required from Module 08)"
# -----------------------------------------------------------------------------
install -m 0755 -d /etc/apt/keyrings
retry bash -c 'curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
    -o /etc/apt/keyrings/docker.asc'
chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
    > /etc/apt/sources.list.d/docker.list
wait_for_apt
retry apt-get update
retry apt-get install -y docker-ce docker-ce-cli containerd.io \
    docker-buildx-plugin docker-compose-plugin

# Lets the student run docker without sudo. Takes effect on their NEXT login.
usermod -aG docker "$TARGET_USER"
systemctl enable --now docker

# -----------------------------------------------------------------------------
step "9/10  kubectl, Helm, Terraform, Node  (Modules 09+)"
# -----------------------------------------------------------------------------
KUBECTL_VERSION="$(curl -Ls https://dl.k8s.io/release/stable.txt)"
retry curl -fsSLo /tmp/kubectl \
    "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
install -o root -g root -m 0755 /tmp/kubectl /usr/local/bin/kubectl
rm -f /tmp/kubectl

retry bash -c 'curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash'

retry bash -c 'wget -qO- https://apt.releases.hashicorp.com/gpg \
    | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg'
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
    > /etc/apt/sources.list.d/hashicorp.list
wait_for_apt
retry apt-get update
retry apt-get install -y terraform

# Node via nvm, installed into the student's home so they own it.
sudo -u "$TARGET_USER" -H bash -lc \
    'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash'
sudo -u "$TARGET_USER" -H bash -lc \
    "export NVM_DIR=\"\$HOME/.nvm\" && . \"\$NVM_DIR/nvm.sh\" && nvm install ${NODE_VERSION}"

# Claude Code CLI, via the native installer, as the student so it lands in their
# ~/.local/bin and they own it. Installing it is all we can do here: the student
# signs in with their own account the first time they run `claude`.
retry sudo -u "$TARGET_USER" -H bash -lc \
    'curl -fsSL https://claude.ai/install.sh | bash'

# -----------------------------------------------------------------------------
step "10/10  Verification"
# -----------------------------------------------------------------------------
echo "" >> "$SUMMARY"
echo "Toolchain:" >> "$SUMMARY"
check "python${PYTHON_VERSION}"  "python${PYTHON_VERSION}" --version
check "docker"                   docker --version
check "kubectl"                  kubectl version --client
check "helm"                     helm version
check "terraform"                terraform version
check "az"                       az version
check "claude"                   test -x "$TARGET_HOME/.local/bin/claude"

echo "" >> "$SUMMARY"
echo "Python packages (in ~/${VENV_DIR}):" >> "$SUMMARY"
for pkg in anthropic openai torch tensorflow sklearn transformers datasets \
           huggingface_hub peft accelerate langchain langchain_anthropic \
           langchain_openai mlflow wandb dotenv pydantic; do
    check "$pkg" sudo -u "$TARGET_USER" -H bash -lc \
        "source '$TARGET_HOME/$VENV_DIR/bin/activate' && python -c 'import $pkg'"
done

# Freeze the manifest so students have the exact environment they were handed.
sudo -u "$TARGET_USER" -H bash -lc \
    "source '$TARGET_HOME/$VENV_DIR/bin/activate' && pip freeze > '$TARGET_HOME/requirements.txt'"

# Belt and braces: nothing in the student's home should be root-owned.
chown -R "$TARGET_USER:$TARGET_USER" "$TARGET_HOME"

echo "" >> "$SUMMARY"
if [ "$FAILURES" -eq 0 ]; then
    echo "RESULT: all checks passed — environment is ready." >> "$SUMMARY"
else
    echo "RESULT: $FAILURES check(s) FAILED — see /var/log/cloud-init-output.log" >> "$SUMMARY"
fi
echo "finished $(date -Is)" >> "$SUMMARY"

cat "$SUMMARY"
log "complete with $FAILURES failure(s)"
exit 0
