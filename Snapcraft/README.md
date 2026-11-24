# Transcript: Snapcraft

## Description
A dedicated environment tailored specifically for building and testing snaps. This Transcript synthesizes a lightweight, isolated LXD virtual machine pre-configured with Snapcraft and a local LXD daemon. It securely injects your base64-encoded store credentials directly into the build environment, allowing for immediate, automated snap packaging and publishing.

## Architecture Overview
This reproducer deploys a single, isolated build host tailored for Snapcraft workflows:

### Host Architecture:
- Build VM (`snapcraft`): A standalone Ubuntu virtual machine pre-installed with `snapcraft` (classic confinement) and a local `lxd` snap initialized automatically (`lxd init --auto`) to serve as Snapcraft's build provider without requiring Multipass.
- Credential Injection: Automatically writes your base64-encoded store credentials to `~/.snapcraft-credentials` (permissions `0600`) and exports `SNAPCRAFT_STORE_CREDENTIALS` in `~/.bashrc`.

### Network Architecture:
- Primary Bridge (`lbr0` / `lxd_cidr`): Uses a single NAT-enabled, DHCP-managed LXD bridge for outbound internet access, snap package downloads, and Snap Store communication.

### Provisioning Pipeline
The virtual machine is provisioned with `lxd`, `snapcraft`, `git`, `neovim`, and `jq`. The cloud-init pipeline generates the runtime environment, verifies CLI dependencies, secures the Snapcraft store credentials file, and initializes the local LXD daemon so the host is immediately ready to build snaps.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the *default* topology.
- CPU: 4 cores
- RAM: 10 GiB
- Disk: 50 GiB
- Network: Outbound internet access for snap downloads and Snap Store communication

## Usage
Deploy this Transcript using the `se-polymerase` orchestrator. The orchestrator isolates all generated files into a dedicated `[DEPLOY_ID]` directory and automatically handles headless background execution.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth Snapcraft/snapcraft.yaml -y
```

Prompt for all variables interactively and assign a specific case number as the deployment ID:
```bash
./synth Snapcraft/snapcraft.yaml 00426900
```

Deploy bypassing prompts by passing a pre-generated configuration file from a previous run:
```bash
./synth Snapcraft/snapcraft.yaml -yc Snapcraft/00426900/config-snapcraft-00426900.yaml
```

### Configuration Files and "Dry Runs"
Every time you execute `synth` interactively, it automatically records your answers and generates a reusable YAML configuration file (e.g., `config-[PROJECT].yaml`). You can pass this file to the `-c` flag in future runs to perfectly replicate a specific environment without having to manually answer the prompts again.

#### How to perform a "Dry Run" (Generate a config without deploying):
If you want to build a configuration file to review, share, or edit *before* actually spinning up any resources, you can use `synth` as a configuration generator:

1. Run `synth` interactively (do **not** use the `-y` flag):
   ```bash
   ./synth Snapcraft/snapcraft.yaml
   ```
2. Answer all the prompts to configure your environment.
3. At the final resource confirmation prompt (`Proceed with deployment using these resources and networks? [y/N]:`), answer `n` to abort.
4. The script will catch the abort and ask: `Keep generated config file 'config-[PROJECT].yaml' for your next run? [y/N]:`. Answer `y`.

You now have a fully populated configuration file inside the generated deployment directory that you can safely tweak and deploy later using:
```bash
./synth Snapcraft/snapcraft.yaml -y -c Snapcraft/[DEPLOY_ID]/config-[PROJECT].yaml
```

## Access and Cleanup
Because the deployment is executed in the background, you can detach your terminal at any time. Check active labs with `./synth list` and monitor live progress using the lab's numeric ID or deploy ID:
```bash
./synth monitor 00426900
```

Once the payload finishes executing, `synth` will automatically drop you into an SSH shell connected to the Snapcraft machine. You can reconnect at any time using:
```bash
./synth shell 00426900
```

View all SSH commands and LXD Web UI details stored in `access-[PROJECT].txt`:
```bash
./synth info 00426900
```

Your base64 credentials are automatically written to `~/.snapcraft-credentials` and exported in `~/.bashrc`. You can immediately verify your store login:
```bash
snapcraft whoami
```

To completely wipe this environment and release its resources (pass `-a` / `--all` to also remove the saved configuration file):
```bash
./synth destroy 00426900
```

## Modular Execution and Recovery
To make debugging and recovery effortless, the entire cloud-init deployment pipeline is broken down into discrete, numbered executable scripts located in `/usr/local/bin/` on the Snapcraft machine.

If a specific phase of the deployment fails or times out, you do not need to destroy the environment and start over. Connect to the machine and execute the failed step manually to retry it. Every script automatically escalates privileges and sources the `/etc/repro-env` state file.

| Script | Description |
| :--- | :--- |
| `00-generate-env` | Initializes the persistent state file `/etc/repro-env` with runtime IP and interface details |
| `01-verify-deps` | Verifies core CLI dependencies (`lxc`, `jq`, `snapcraft`) |
| `02-snapcraft-configure` | Writes `~/.snapcraft-credentials`, exports `SNAPCRAFT_STORE_CREDENTIALS` in `~/.bashrc`, and runs `lxd init --auto` |

### Why is this useful?

If step `02` fails due to a transient LXD initialization issue, you **do not** need to destroy the lab and start over. Connect to the machine with `./synth shell <id>` (which automatically falls back to `lxc shell` if SSH is not up yet) and re-run the specific script:

```bash
ubuntu@snapcraft:~$ 02-snapcraft-configure
```

## Variables
When launching this Transcript, `synth` will parse the payload and optionally prompt for the following configuration values.

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| update_n_upgrade | True | Auto Update & Upgrade base packages |
| vm_image | ubuntu:24.04 | Base operating system image for the primary virtual machine |
| sys_user | ubuntu | Default system user for SSH access |
| password | ubuntu | Password for the default system user |
| pro_token | None | Optional Ubuntu Pro token for extended packages |
| hostname | None | Custom hostname for the Snapcraft machine |
| tld | None | Top Level Domain for the local environment |
| timezone | America/New_York | System timezone |
| lxd_channel | 5.21/stable | Snap channel for the local LXD installation |
| snapcraft_channel | latest/stable | Snap channel for the Snapcraft installation |
| snapcraft_creds_b64 | None | Base64 encoded Snapcraft login credentials |
| lxd_pool | default | Target LXD storage pool for the deployment |
| lxd_bridge | lbr0 | Name of the primary LXD network bridge |
| lxd_cidr | 10.10.0.0/22 | Subnet CIDR for the LXD network |
| primary_cpu | 4 | CPU cores allocated to the primary host VM |
| primary_ram | 10GiB | RAM allocated to the primary host VM |
| primary_disk | 50GiB | Root disk size for the primary host VM |
