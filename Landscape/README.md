# Transcript: Landscape

## Description
A fully automated, highly available Landscape environment orchestrated by Juju on top of MAAS. This Transcript synthesizes a primary MAAS controller, bootstraps a Juju orchestration layer, and performs a dense deployment of Charmed Landscape. It provisions PostgreSQL directly on bare-metal nodes while placing HAProxy, RabbitMQ, and Landscape Server components into nested LXD containers, alongside separate client machines that automatically register themselves to the control plane.

## Architecture Overview
This reproducer implements a dense, high-availability Charmed Landscape architecture using Canonical MAAS as the bare-metal provider and Juju (`landscape-dense-maas` model) for service orchestration:

### Cloud Architecture (Dense HA):
Database services run directly on the bare-metal nodes for I/O performance, while application, messaging, and load-balancing tiers run in co-located LXD containers:
- MAAS Controller (`maas-1`): Hosts the MAAS region/rack controller, local LXD client configuration, and the `juju` CLI used to drive and manage the deployment.
- Juju Controller Nodes (`juju-controller-*`): Dedicated machines assigned the `juju-controller` tag to manage the `landscape-dense-maas` Juju model and charm lifecycle (scales to HA when `juju_ha > 1`).
- Core Landscape Nodes (`node-*`): Bare-metal nodes (defaulting to 3 for HA) hosting PostgreSQL directly on the metal, while co-hosting HAProxy (exposed with self-signed TLS), RabbitMQ Server, and Landscape Server inside LXD containers.
- Client Nodes (`client-*`): Dedicated Ubuntu machines (defaulting to 1) running the `ubuntu` and `landscape-client` charms, automatically configured against the HAProxy leader IP and registered to the Landscape Server cluster (with optional Ubuntu Pro attachment if `pro_token` is provided).

### Network Architecture:
- Provisioning & Management Network (`mbr0` / `maas_cidr`): Uses a single NAT-enabled LXD bridge mapped to the `landspace` MAAS network space. MAAS provides DHCP and DNS for PXE booting and node resolution across the cluster.

### High Availability & Availability Zones:
- Availability Zones: Juju controllers, core Landscape nodes, and client nodes are automatically distributed across MAAS Availability Zones (`AZ1` through `AZn`) matching their replica index.
- High Availability (HA): With the default of 3 core Landscape nodes (`node_ha = 3`), HAProxy, PostgreSQL, RabbitMQ, and Landscape Server are each deployed with 3 units across separate failure domains.

### Provisioning Pipeline
All nodes are created natively via the LXD API, enlisted and commissioned in MAAS using LXD power drivers, and tagged with their roles (`juju-controller`, `landscape`, `client`). After Juju bootstraps the controller and provisions the machines in the `landscape-dense-maas` model, the pipeline deploys HAProxy, PostgreSQL, RabbitMQ, and Landscape Server with all required integrations, then deploys the client Ubuntu machines and registers them via `landscape-client`.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the *default* topology.
- CPU: 22 cores
- RAM: 60 GiB
- Disk: 310 GiB
- Network: Outbound internet access for LXD image downloads, MAAS image synchronization, and Juju charm deployments

## Usage
Deploy this Transcript using the `se-polymerase` orchestrator. The orchestrator isolates all generated files into a dedicated `[DEPLOY_ID]` directory and automatically handles headless background execution.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth Landscape/landscape.yaml -y
```

Deploy using deb MAAS, prompt for all variables interactively, and assign a specific case number as the deployment ID:
```bash
./synth Landscape/landscape.yaml -d 00426900
```

Deploy bypassing prompts by passing a pre-generated configuration file from a previous run:
```bash
./synth Landscape/landscape.yaml -yc Landscape/00426900/config-landscape-00426900.yaml
```

### Configuration Files and "Dry Runs"
Every time you execute `synth` interactively, it automatically records your answers and generates a reusable YAML configuration file (e.g., `config-[PROJECT].yaml`). You can pass this file to the `-c` flag in future runs to perfectly replicate a specific environment without having to manually answer the prompts again.

#### How to perform a "Dry Run" (Generate a config without deploying):
If you want to build a configuration file to review, share, or edit *before* actually spinning up any resources, you can use `synth` as a configuration generator:

1. Run `synth` interactively (do **not** use the `-y` flag):
   ```bash
   ./synth Landscape/landscape.yaml
   ```
2. Answer all the prompts to configure your environment.
3. At the final resource confirmation prompt (`Proceed with deployment using these resources and networks? [y/N]:`), answer `n` to abort.
4. The script will catch the abort and ask: `Keep generated config file 'config-[PROJECT].yaml' for your next run? [y/N]:`. Answer `y`.

You now have a fully populated configuration file inside the generated deployment directory that you can safely tweak and deploy later using:
```bash
./synth Landscape/landscape.yaml -y -c Landscape/[DEPLOY_ID]/config-[PROJECT].yaml
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

To access the Landscape Server web UI, query Juju for the HAProxy public IP address once connected to the controller:
```bash
juju status
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
| `01-verify-deps` | Installs deb MAAS (if selected) and verifies core CLI dependencies (`lxc`, `jq`, `maas`, `juju`) |
| `02-maas-init` | Configures PostgreSQL, initializes MAAS, creates the admin user, and uploads SSH keys |
| `03-maas-networking` | Configures subnets, DHCP ranges, VLANs, spaces, and DNS settings in MAAS |
| `04-maas-images` | Triggers and monitors the synchronization of required OS boot images |
| `05-lxd-setup` | Establishes certificate trust between MAAS and the LXD provider |
| `06-vm-creation` | Provisions the empty Juju controller, Landscape, and client virtual machines in LXD |
| `07-maas-enlist` | Boots the machines and monitors their automatic enlistment into MAAS |
| `08-maas-configure` | Assigns availability zones, hostnames, and LXD power controls |
| `09-maas-commission` | Triggers the commissioning phase and waits for hardware discovery |
| `10-maas-tagging` | Applies hardware tags (`juju-controller`, `landscape`, `client`) and configures flat storage layouts |
| `11-juju-add-cloud` | Registers MAAS as a Juju cloud and imports the MAAS API credentials |
| `12-juju-bootstrap` | Bootstraps the Juju controller and enables controller HA if `juju_ha > 1` |
| `13-juju-deploy` | Creates the `landscape-dense-maas` Juju model and provisions the bare-metal Landscape and client machines |
| `14-juju-deploy-haproxy` | Deploys and exposes HAProxy in LXD containers across the Landscape nodes with self-signed SSL |
| `15-juju-deploy-postgresql` | Deploys PostgreSQL directly on the bare-metal Landscape nodes with required extensions enabled |
| `16-juju-deploy-rabbitmq` | Deploys RabbitMQ Server in LXD containers across the Landscape nodes |
| `17-juju-deploy-landscape-server` | Deploys Landscape Server in LXD containers and integrates it with RabbitMQ, HAProxy, and PostgreSQL |
| `18-juju-deploy-ubuntu-machine` | Deploys the `ubuntu` charm onto the dedicated client machines |
| `19-juju-deploy-landscape-client` | Deploys `landscape-client` configured with the HAProxy leader IP and relates it to the client machines |
| `20-attach-landscape-client` | Attaches the Ubuntu Pro token (if provided) and runs the `register` action on each `landscape-client` unit |

### Why is this useful?

If a deployment fails at step `17` due to a transient network error or charm timeout, you **do not** need to destroy the lab and start over. Connect to the primary machine with `./synth shell <id>` (which automatically falls back to `lxc shell` if SSH is not up yet) and re-run the specific script:

```bash
ubuntu@maas-1:~$ 17-juju-deploy-landscape-server
```

## Variables
When launching this Transcript, `synth` will parse the payload and optionally prompt for the following configuration values.

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| update_n_upgrade | True | Auto Update & Upgrade base packages |
| vm_image | ubuntu:24.04 | Base operating system image for the primary MAAS controller |
| sys_user | ubuntu | Default system user for SSH access |
| password | ubuntu | Password for the default system user |
| pro_token | None | Optional Ubuntu Pro token for extended packages and automated client attachment |
| hostname | None | Custom hostname for the MAAS controller |
| tld | landscape | Top Level Domain for the MAAS environment |
| timezone | America/New_York | System timezone |
| timeout | 45m | Timeout duration for Juju application wait loops |
| lxd_channel | 5.21/stable | Snap channel for the LXD installation |
| maas_channel | 3.7/stable | Snap channel for the MAAS installation |
| juju_channel | 3.6/stable | Snap channel for the Juju installation |
| juju_base | ubuntu@22.04 | Operating system base used for the Juju bootstrap and model |
| haproxy_channel | latest/stable | Charm channel for HAProxy |
| haproxy_base | ubuntu@24.04 | Operating system base used for HAProxy |
| postgresql_channel | 14/stable | Charm channel for PostgreSQL |
| postgresql_base | ubuntu@22.04 | Operating system base used for PostgreSQL |
| rabbitmq_channel | 3.9/stable | Charm channel for RabbitMQ Server |
| rabbitmq_base | ubuntu@22.04 | Operating system base used for RabbitMQ Server |
| landscape_server_channel | latest/stable | Charm channel for Landscape Server |
| landscape_server_base | ubuntu@22.04 | Operating system base used for Landscape Server |
| landscape_client_channel | latest/stable | Charm channel for Landscape Client |
| lxd_pool | default | Target LXD storage pool for the deployment |
| maas_user | admin | Web UI and API admin username for MAAS |
| maas_password | admin | Web UI and API admin password for MAAS |
| maas_email | admin@email.com | Admin email address for MAAS |
| maas_images | noble jammy | Space separated list of Ubuntu releases to sync |
| maas_space | landspace | Logical network space name mapped in MAAS |
| maas_dns | 8.8.8.8 | Upstream DNS forwarder for the MAAS network |
| maas_bridge | mbr0 | Name of the primary MAAS network bridge |
| maas_cidr | 10.10.0.0/22 | Subnet CIDR for the MAAS network |
| maas_ip_count | 30 | Number of IPs to reserve for the MAAS dynamic DHCP pool |
| maas_cpu | 4 | CPU cores allocated to the MAAS controller |
| maas_ram | 8GiB | RAM allocated to the MAAS controller |
| maas_disk | 30GiB | Root disk size for the MAAS controller |
| juju_ha | 1 | Total number of Juju controller machines to provision |
| juju_cpu | 2 | CPU cores allocated to each Juju controller |
| juju_ram | 6GiB | RAM allocated to each Juju controller |
| juju_disk | 20GiB | Root disk size for each Juju controller |
| node_ha | 3 | Total number of core Landscape machines to provision |
| node_cpu | 3 | CPU cores allocated to each core Landscape machine |
| node_ram | 8GiB | RAM allocated to each core Landscape machine |
| node_disk | 40GiB | Root disk size for each core Landscape machine |
| client_ha | 1 | Total number of separate client machines to provision |
| client_cpu | 2 | CPU cores allocated to each client machine |
| client_ram | 4GiB | RAM allocated to each client machine |
| client_disk | 10GiB | Root disk size for each client machine |
| client_base | ubuntu@22.04 | Operating system base used for the client machines |

