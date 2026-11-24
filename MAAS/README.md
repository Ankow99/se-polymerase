# Transcript: MAAS

## Description
A fully automated, highly scalable MAAS environment. This Transcript synthesizes a primary MAAS controller that dynamically provisions, PXE boots, and commissions empty LXD virtual machines acting as bare-metal nodes across MAAS Availability Zones. It serves as a foundational reproducer for hardware provisioning, networking, and storage tagging workflows.

## Architecture Overview
This reproducer implements a standalone Canonical MAAS bare-metal provisioning environment backed by LXD virtual machines:

### Cluster Architecture:
- MAAS Controller (`maas-1`): Hosts the PostgreSQL database, MAAS region and rack controllers, local LXD client configuration, and the `maas` / `maast` CLIs for managing the fleet.
- Bare-Metal Nodes (`node-*`): A dynamic fleet of empty virtual machines (defaulting to 5 nodes) attached to the MAAS network bridge, enlisted via PXE, commissioned into the `Ready` state, and tagged with `machine`.

### Network Architecture:
- Provisioning Network (`mbr0` / `maas_cidr`): Uses a single NAT-enabled LXD bridge mapped to the `maasspace` MAAS network space. MAAS provides DHCP and DNS on this subnet to handle PXE booting, enlistment, and node resolution.

### Availability Zones:
- Availability Zones: Provisioned nodes are automatically distributed across MAAS Availability Zones (`AZ1` through `AZn`) matching their replica index, with the primary rack controller assigned to `AZ1`.

### Provisioning Pipeline
Compute nodes are created natively via the LXD API, powered on, and PXE booted into MAAS. The pipeline oversees their enlistment, assigns hostnames, domains, Availability Zones, and LXD power controls, commissions them into a `Ready` state, and tags their primary disks as SSDs with a flat storage layout. An optional `11-maas-deploy` helper script is also staged on the controller if you want to deploy all `Ready` nodes immediately.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the *default* topology.
- CPU: 19 cores
- RAM: 48 GiB
- Disk: 180 GiB
- Network: Outbound internet access for LXD image downloads and MAAS image synchronization

## Usage
Deploy this Transcript using the `se-polymerase` orchestrator. The orchestrator isolates all generated files into a dedicated `[DEPLOY_ID]` directory and automatically handles headless background execution.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth MAAS/maas.yaml -y
```

Deploy using deb MAAS, prompt for all variables interactively, and assign a specific case number as the deployment ID:
```bash
./synth MAAS/maas.yaml -d 00426900
```

Deploy bypassing prompts by passing a pre-generated configuration file from a previous run:
```bash
./synth MAAS/maas.yaml -yc MAAS/00426900/config-maas-00426900.yaml
```

### Configuration Files and "Dry Runs"
Every time you execute `synth` interactively, it automatically records your answers and generates a reusable YAML configuration file (e.g., `config-[PROJECT].yaml`). You can pass this file to the `-c` flag in future runs to perfectly replicate a specific environment without having to manually answer the prompts again.

#### How to perform a "Dry Run" (Generate a config without deploying):
If you want to build a configuration file to review, share, or edit *before* actually spinning up any resources, you can use `synth` as a configuration generator:

1. Run `synth` interactively (do **not** use the `-y` flag):
   ```bash
   ./synth MAAS/maas.yaml
   ```
2. Answer all the prompts to configure your environment.
3. At the final resource confirmation prompt (`Proceed with deployment using these resources and networks? [y/N]:`), answer `n` to abort.
4. The script will catch the abort and ask: `Keep generated config file 'config-[PROJECT].yaml' for your next run? [y/N]:`. Answer `y`.

You now have a fully populated configuration file inside the generated deployment directory that you can safely tweak and deploy later using:
```bash
./synth MAAS/maas.yaml -y -c MAAS/[DEPLOY_ID]/config-[PROJECT].yaml
```

## Access and Cleanup
Because the deployment is executed in the background, you can detach your terminal at any time. Check active labs with `./synth list` and monitor live progress using the lab's numeric ID or deploy ID:
```bash
./synth monitor 00426900
```

Once the payload finishes executing, `synth` will automatically drop you into an SSH shell connected to the primary MAAS controller. You can reconnect at any time using:
```bash
./synth shell 00426900
```

View all SSH tunneling commands, dashboard URLs, and credentials stored in `access-[PROJECT].txt`:
```bash
./synth info 00426900
```

Once connected, you can inspect the commissioned fleet directly with `maast`:
```bash
maast admin machines read
```

To completely wipe this environment and release its resources (pass `-a` / `--all` to also remove the saved configuration file):
```bash
./synth destroy 00426900
```

## Modular Execution and Recovery
To make debugging and recovery effortless, the entire cloud-init deployment pipeline is broken down into discrete, numbered executable scripts located in `/usr/local/bin/` on the primary MAAS controller.

If a specific phase of the deployment fails or times out, you do not need to destroy the environment and start over. Connect to the primary controller and execute the failed step manually to retry it. Every script automatically escalates privileges and sources the `/etc/repro-env` state file, ensuring it has all the correct environment variables and dynamically calculated IPs needed to resume the deployment exactly where it left off.

| Script | Description |
| :--- | :--- |
| `00-generate-env` | Initializes the persistent state file `/etc/repro-env` and calculates dynamic IP allocations |
| `01-verify-deps` | Installs deb MAAS (if selected) and verifies core CLI dependencies (`lxc`, `jq`, `maas`) |
| `02-maas-init` | Configures PostgreSQL, initializes MAAS, creates the admin user, and uploads SSH keys |
| `03-maas-networking` | Configures subnets, DHCP ranges, VLANs, spaces, and DNS settings in MAAS |
| `04-maas-images` | Triggers and monitors the synchronization of required OS boot images |
| `05-lxd-setup` | Establishes certificate trust between MAAS and the LXD provider |
| `06-vm-creation` | Provisions the empty bare-metal virtual machines in LXD |
| `07-maas-enlist` | Boots the machines and monitors their automatic enlistment into MAAS |
| `08-maas-configure` | Assigns availability zones, hostnames, and LXD power controls |
| `09-maas-commission` | Triggers the commissioning phase and waits for hardware discovery |
| `10-maas-tagging` | Applies the `machine` tag, tags primary disks as SSDs, and configures flat storage layouts |
| `11-maas-deploy` | Optional script (disabled by default) to deploy all `Ready` machines into a `Deployed` state |

### Why is this useful?

If commissioning fails at step `09` due to a transient PXE error, or if you want to deploy all `Ready` nodes after the lab finishes, you **do not** need to destroy the lab and start over. Connect to the primary machine with `./synth shell <id>` (which automatically falls back to `lxc shell` if SSH is not up yet) and run the specific script:

```bash
ubuntu@maas-1:~$ 11-maas-deploy
```

## Variables
When launching this Transcript, `synth` will parse the payload and optionally prompt for the following configuration values.

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| update_n_upgrade | True | Auto Update & Upgrade base packages |
| vm_image | ubuntu:24.04 | Base operating system image for the primary MAAS controller |
| sys_user | ubuntu | Default system user for SSH access |
| password | ubuntu | Password for the default system user |
| pro_token | None | Optional Ubuntu Pro token for extended packages |
| hostname | None | Custom hostname for the MAAS controller |
| tld | None | Top Level Domain for the MAAS environment |
| timezone | America/New_York | System timezone |
| lxd_channel | 5.21/stable | Snap channel for the LXD installation |
| maas_channel | 3.7/stable | Snap channel for the MAAS installation |
| lxd_pool | default | Target LXD storage pool for the deployment |
| maas_user | admin | Web UI and API admin username for MAAS |
| maas_password | admin | Web UI and API admin password for MAAS |
| maas_email | admin@email.com | Admin email address for MAAS |
| maas_images | noble jammy | Space separated list of Ubuntu releases to sync |
| maas_space | maasspace | Logical network space name mapped in MAAS |
| maas_dns | 8.8.8.8 | Upstream DNS forwarder for the MAAS network |
| maas_bridge | mbr0 | Name of the primary MAAS network bridge |
| maas_cidr | 10.10.0.0/22 | Subnet CIDR for the MAAS network |
| maas_ip_count | 30 | Number of IPs to reserve for the MAAS dynamic DHCP pool |
| maas_cpu | 4 | CPU cores allocated to the MAAS controller |
| maas_ram | 8GiB | RAM allocated to the MAAS controller |
| maas_disk | 30GiB | Root disk size for the MAAS controller |
| node_ha | 5 | Total number of empty compute machines to provision |
| node_cpu | 3 | CPU cores allocated to each compute machine |
| node_ram | 8GiB | RAM allocated to each compute machine |
| node_disk | 30GiB | Root disk size for each compute machine |

