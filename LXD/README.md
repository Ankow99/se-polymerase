# Transcript: LXD

## Description
A streamlined, purely LXD-focused environment. This Transcript synthesizes a primary host node (`node-0`) that securely configures the LXD client/daemon and orchestrates a fleet of Ubuntu virtual machines. It serves as a lightweight, fast reproducer for base operating system testing, LXD clustering, or general-purpose virtual machine scaling without the overhead of MAAS or Juju.

## Architecture Overview
This reproducer deploys a lightweight LXD management node and a scalable fleet of Ubuntu virtual machines:

### Cluster Architecture:
- Primary Node (`node-0`): Serves as the jump host and LXD control point, pre-configured with client certificates, SSH keys for accessing child nodes, and automatic LXD remote/project switching on login.
- Child Virtual Machines (`node-1` through `node-N`): A fleet of Ubuntu virtual machines (defaulting to 5 nodes running `ubuntu:22.04`) provisioned with cloud-init and injected with both the primary node's Ed25519 public key and your own SSH keys.

### Network Architecture:
- Primary Bridge (`lbr0` / `lxd_cidr`): Uses a single NAT-enabled, DHCP-managed LXD bridge providing IPv4 addressing and outbound internet access for the primary node and all child virtual machines.

### Provisioning Pipeline
The primary node establishes LXD client certificate trust (either against the host's bare-metal LXD daemon or a local nested LXD daemon), switches to the isolated LXD project, generates an internal Ed25519 SSH key pair, and initializes and starts the entire fleet of child virtual machines directly via the LXD API.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the *default* topology.
- CPU: 19 cores
- RAM: 48 GiB
- Disk: 180 GiB
- Network: Outbound internet access for LXD image downloads and package installations

## Usage
Deploy this Transcript using the `se-polymerase` orchestrator. The orchestrator isolates all generated files into a dedicated `[DEPLOY_ID]` directory and automatically handles headless background execution.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth LXD/lxd.yaml -y
```

Prompt for all variables interactively and assign a specific case number as the deployment ID:
```bash
./synth LXD/lxd.yaml 00426900
```

Deploy bypassing prompts by passing a pre-generated configuration file from a previous run:
```bash
./synth LXD/lxd.yaml -yc LXD/00426900/config-lxd-00426900.yaml
```

### Configuration Files and "Dry Runs"
Every time you execute `synth` interactively, it automatically records your answers and generates a reusable YAML configuration file (e.g., `config-[PROJECT].yaml`). You can pass this file to the `-c` flag in future runs to perfectly replicate a specific environment without having to manually answer the prompts again.

#### How to perform a "Dry Run" (Generate a config without deploying):
If you want to build a configuration file to review, share, or edit *before* actually spinning up any resources, you can use `synth` as a configuration generator:

1. Run `synth` interactively (do **not** use the `-y` flag):
   ```bash
   ./synth LXD/lxd.yaml
   ```
2. Answer all the prompts to configure your environment.
3. At the final resource confirmation prompt (`Proceed with deployment using these resources and networks? [y/N]:`), answer `n` to abort.
4. The script will catch the abort and ask: `Keep generated config file 'config-[PROJECT].yaml' for your next run? [y/N]:`. Answer `y`.

You now have a fully populated configuration file inside the generated deployment directory that you can safely tweak and deploy later using:
```bash
./synth LXD/lxd.yaml -y -c LXD/[DEPLOY_ID]/config-[PROJECT].yaml
```

## Access and Cleanup
Because the deployment is executed in the background, you can detach your terminal at any time. Check active labs with `./synth list` and monitor live progress using the lab's numeric ID or deploy ID:
```bash
./synth monitor 00426900
```

Once the payload finishes executing, `synth` will automatically drop you into an SSH shell connected to the primary node (`node-0`). You can reconnect at any time using:
```bash
./synth shell 00426900
```

View all SSH tunneling commands, LXD Web UI details, and cluster IPs stored in `access-[PROJECT].txt`:
```bash
./synth info 00426900
```

Once connected to `node-0`, you can immediately inspect and manage the running fleet with `lxc`:
```bash
lxc list
```

To completely wipe this environment and release its resources (pass `-a` / `--all` to also remove the saved configuration file):
```bash
./synth destroy 00426900
```

## Modular Execution and Recovery
To make debugging and recovery effortless, the entire cloud-init deployment pipeline is broken down into discrete, numbered executable scripts located in `/usr/local/bin/` on the primary node (`node-0`).

If a specific phase of the deployment fails or times out, you do not need to destroy the environment and start over. Connect to the primary node and execute the failed step manually to retry it. Every script automatically escalates privileges and sources the `/etc/repro-env` state file.

| Script | Description |
| :--- | :--- |
| `00-generate-env` | Initializes the persistent state file `/etc/repro-env` with runtime IP, interface, and LXD connection variables |
| `01-verify-deps` | Verifies core CLI dependencies (`lxc`, `jq`) |
| `02-lxd-setup` | Establishes LXD client certificate trust (local nested or remote `host-lxd`) and switches to the target project |
| `03-vm-creation` | Generates an Ed25519 SSH key pair, builds the child cloud-init userdata, and initializes all child VMs in LXD |
| `04-vm-start` | Starts all provisioned child virtual machines |

### Why is this useful?

If a deployment fails at step `03` due to a transient LXD image download error, you **do not** need to destroy the lab and start over. Connect to the primary node with `./synth shell <id>` (which automatically falls back to `lxc shell` if SSH is not up yet) and re-run the specific script:

```bash
ubuntu@node-0:~$ 03-vm-creation
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
| hostname | None | Custom hostname for the primary node |
| tld | None | Top Level Domain for the local environment |
| timezone | America/New_York | System timezone |
| lxd_channel | 5.21/stable | Snap channel for the LXD installation |
| lxd_pool | default | Target LXD storage pool for the deployment |
| lxd_bridge | lbr0 | Name of the primary LXD network bridge |
| lxd_cidr | 10.10.0.0/22 | Subnet CIDR for the LXD network |
| primary_cpu | 4 | CPU cores allocated to the primary host VM |
| primary_ram | 8GiB | RAM allocated to the primary host VM |
| primary_disk | 30GiB | Root disk size for the primary host VM |
| node_ha | 5 | Total number of child virtual machines to provision |
| node_cpu | 3 | CPU cores allocated to each child virtual machine |
| node_ram | 8GiB | RAM allocated to each child virtual machine |
| node_disk | 30GiB | Root disk size for each child virtual machine |
| node_image | ubuntu:22.04 | Base operating system image for each child virtual machine |
