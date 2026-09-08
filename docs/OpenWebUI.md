# JHU Production AI - Module 01: Optional - Open WebUI and Ollama

**This page is optional.** It is not part of the Lab 1 deliverable, and nothing in Module 01
depends on it. It gives you a local chat interface, backed by open-weight models running on
your own VM, that you can use to experiment from week one. Module 10 covers inference servers
such as Ollama properly; this is a preview.

Everything below runs on the CPU. The course subscription has no GPU SKUs, so your VM is a
4 vCPU / 16 GB CPU machine for the whole semester. That is enough for a 7-8B quantized model.
It is not fast.

## 1. Run it

In a VS Code terminal on the VM (see [Setup VSCode](./VSCodeSetup.md)):

```bash
docker run -d \
  -p 3000:8080 \
  -v ollama:/root/.ollama \
  -v open-webui:/app/backend/data \
  --name open-webui \
  --restart always \
  ghcr.io/open-webui/open-webui:ollama
```

The `:ollama` image bundles Ollama and Open WebUI in one container. The two named volumes keep
your models and your chat history across container restarts. `--restart always` brings it back
up whenever the VM boots.

Do **not** add `--gpus=all`. There is no GPU, and Docker refuses to start the container with
`could not select device driver "" with capabilities: [[gpu]]`.

If `docker` reports `permission denied`, log out of the VM and back in. Provisioning added you to
the `docker` group, but that takes effect on your next login.

The first pull is about 4-5 GB and takes a few minutes. Check on it with:

```bash
docker ps                       # STATUS should read Up
docker logs -f open-webui       # Ctrl+C to stop following
```

## 2. Reach it without opening a port

Port 3000 is **not** open in the network security group, and it must stay that way. Open WebUI
makes whoever creates the first account the administrator. An internet-facing port 3000 with
`--restart always` is a race that anyone scanning Azure address space can win before you do.

You do not need the port open. SSH carries the traffic for you over port 22, which is already
the one way in.

**From VS Code (easiest).** When you are connected over Remote - SSH, VS Code notices the
container listening on 3000 and forwards it automatically. Open the **Ports** panel (next to
the Terminal tab) and click the globe icon next to port 3000, or just open
<http://localhost:3000> in the browser on your laptop. If 3000 is not listed, click
**Forward a Port** and type `3000`.

**From a plain terminal on your laptop.** Using the `jhu-lab` host from
[Setup VSCode](./VSCodeSetup.md):

```bash
ssh -L 3000:localhost:3000 jhu-lab
```

Leave that session open and browse to <http://localhost:3000>. Closing the session closes the
tunnel.

Either way, the browser talks to `localhost` on your laptop, SSH carries it to the VM, and
nothing about the VM is reachable from the internet that was not reachable before.

## 3. First run

1. Open <http://localhost:3000>. The first screen asks you to create an account. **Do it now.**
   That first account is the administrator.
2. Pull a model. In the chat window, open the model selector, type a model name, and choose
   **Pull**. Or from the VM terminal:

   ```bash
   docker exec open-webui ollama pull llama3.1:8b
   ```

3. Pick something that fits in 16 GB. A 7-8B model at the default 4-bit quantization needs
   about 5 GB of RAM and works. Anything much larger will swap, run at a crawl, or be killed
   for running out of memory. Expect a few words per second on the CPU.

## 4. Disk and cost

- The image is about 4-5 GB, and each model is another 4-5 GB, all under `/var/lib/docker` in
  the two named volumes. Your 128 GB OS disk has room for several models.
- An idle container costs nothing extra. The VM bills the same whether or not it is running.
  Deallocate the VM between sessions exactly as before; the container comes back with it.
- The daily auto-shutdown (`autoShutdownTime`) applies here too. A model pull still running at
  that time is cut off; start big pulls well before it, or use the postpone link in the
  warning email if you set `autoShutdownNotificationEmail`.
- `docker system df` shows what the images and volumes are using.

## 5. Stop or remove it

```bash
docker stop open-webui                   # stop it, keep everything
docker start open-webui                  # bring it back

docker rm -f open-webui                  # remove the container
docker volume rm ollama open-webui       # and the models and chat history
docker rmi ghcr.io/open-webui/open-webui:ollama   # and the image
```

## A note for maintainers

Port 3000 is deliberately absent from `VirtualMachine/terraform/network.tf`. Do not add it.
If a port ever does have to open on this VM, it goes in as a Terraform variable next to
`allowedSSHSource`, never as a rule added by hand in the portal: the inline `security_rule`
blocks in `network.tf` are authoritative, and the next `terraform apply` deletes anything
added outside them.
