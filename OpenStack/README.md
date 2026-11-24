# Transcript: Charmed OpenStack

## Description
A fully automated, highly available Charmed OpenStack environment orchestrated by Juju on top of MAAS. This Transcript synthesizes a primary MAAS controller, bootstraps a Juju orchestration layer, and performs a dense deployment of OpenStack components. It provisions core services like Nova, Neutron (OVN), Keystone, Glance, Placement, and Cinder alongside a fully integrated Ceph storage cluster and HashiCorp Vault for certificate management.

## Architecture Overview
This reproducer implements a hyperconverged Charmed OpenStack reference architecture using Canonical MAAS as the bare-metal provider and Juju for service orchestration:

### Cloud Architecture (Hyperconverged):
Control-plane services run inside isolated LXD containers across the cluster, while compute, storage, and SDN data-plane services run directly on the bare-metal nodes:
- MAAS Controller (`maas-1`): Hosts the MAAS region/rack controller, local LXD client configuration, and the `juju` and `openstack` CLIs used to drive and manage the deployment.
- Juju Controller Nodes (`juju-controller-*`): Dedicated machines assigned the `juju-controller` tag to manage the `openstack` Juju model and charm lifecycle (scales to HA when `juju_ha > 1`).
- OpenStack Nodes (`node-*`): Hyperconverged bare-metal nodes hosting Ceph OSDs (backed by raw LXD block volumes), Nova Compute, and OVN Chassis directly on the host, while co-hosting containerized control-plane services (MySQL InnoDB Cluster, Vault, OVN Central, Keystone, RabbitMQ, Neutron API, Nova Cloud Controller, Placement, Horizon Dashboard, Glance, Ceph Monitors, Cinder, and Ceph RADOS Gateway).

### Network Architecture & Traffic Segregation:
Uses a two-network bridged topology mapped through MAAS network spaces (`openstackspace`):
- Generic Network (`mbr0` / `maas_cidr`): Carries PXE provisioning, machine management, Juju orchestration, and internal OpenStack API traffic.
- External Network (`nbr0` / `os_neutron_cidr`): Mapped to `physnet1` (`br-ex` on `enp6s0`) on all OpenStack nodes to provide north-south external connectivity (`ext_net`) and floating IP routing via OVN.

### High Availability & Quorum Scaling:
- Availability Zones: Nodes are automatically distributed across MAAS Availability Zones (`AZ1` through `AZn`) matching their replica index.
- Minimum Quorum: A minimum of 3 OpenStack nodes (`node_ha >= 3`) is required to satisfy quorum and replication requirements for MySQL InnoDB Cluster, OVN Central, and Ceph Monitors.
- Compute Isolation: With the default of 4 nodes, `node-1` is dedicated to control-plane containers and Ceph OSDs while `node-2` through `node-4` host Nova Compute. Scaling `node_ha` beyond 4 automatically expands Nova Compute, OVN Chassis, and Ceph OSD capacity across all additional nodes (up to 12 OSDs per node).

### Provisioning Pipeline
Virtual machines are created via the LXD API with attached block volumes and secondary Neutron interfaces, enlisted and commissioned in MAAS using LXD power drivers, and tagged with their roles (`juju-controller`, `control`, `compute`, `storage`, `network`) before Juju bootstraps the controller and deploys each OpenStack, Ceph, OVN, and Vault charm sequentially.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the *default* topology.
- CPU: 20 cores
- RAM: 58 GiB
- Disk: 370 GiB
- Network: Outbound internet access for LXD image downloads, MAAS image synchronization, and Juju charm deployments

## Release Generation Script
Due to the strict version compatibility matrix between OpenStack, Ceph, OVN, and underlying database services, this repository includes a `generate-releases.sh` script.

Instead of manually editing the base template to test older OpenStack releases, you can run the generator script against the base transcript. The script iterates through the official [charm delivery](https://docs.openstack.org/charm-guide/latest/project/charm-delivery.html) matrix and outputs discrete, version-locked `cloud-init` templates for each supported release.

To generate the release templates:
```bash
./generate-releases.sh openstack.yaml
```
This will output distinct files such as `focal-ussuri.yaml`, `jammy-yoga.yaml`, and `jammy-2023.2.yaml` into your directory, with all underlying snap and charm channels properly pinned.

## Usage
Deploy a generated OpenStack release using the `se-polymerase` orchestrator. The orchestrator isolates all generated files into a dedicated `[DEPLOY_ID]` directory and automatically handles headless background execution.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth OpenStack/focal-ussuri.yaml -y
```

Deploy using deb MAAS, prompt for all variables interactively, and assign a specific case number as the deployment ID:
```bash
./synth OpenStack/jammy-yoga.yaml -d 00426900
```

Deploy bypassing prompts by passing a pre-generated configuration file from a previous run:
```bash
./synth OpenStack/jammy-2024.1.yaml -yc OpenStack/00426900/config-openstack-00426900.yaml
```

### Configuration Files and "Dry Runs"
Every time you execute `synth` interactively, it automatically records your answers and generates a reusable YAML configuration file (e.g., `config-[PROJECT].yaml`). You can pass this file to the `-c` flag in future runs to perfectly replicate a specific environment without having to manually answer the prompts again.

#### How to perform a "Dry Run" (Generate a config without deploying):
If you want to build a configuration file to review, share, or edit *before* actually spinning up any resources, you can use `synth` as a configuration generator:

1. Run `synth` interactively (do **not** use the `-y` flag):
   ```bash
   ./synth OpenStack/jammy-2023.2.yaml
   ```
2. Answer all the prompts to configure your environment.
3. At the final resource confirmation prompt (`Proceed with deployment using these resources and networks? [y/N]:`), answer `n` to abort.
4. The script will catch the abort and ask: `Keep generated config file 'config-[PROJECT].yaml' for your next run? [y/N]:`. Answer `y`.

You now have a fully populated configuration file inside the generated deployment directory that you can safely tweak and deploy later using:
```bash
./synth OpenStack/jammy-2023.2.yaml -y -c OpenStack/[DEPLOY_ID]/config-[PROJECT].yaml
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

An `openrc` file is automatically generated in your user directory and sourced at login. You can interact with the OpenStack CLI:
```bash
openstack server list
```
Vault is automatically initialized, unsealed, and authorized during deployment, with its root token and unseal keys saved to `~/vault-init.json`.

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
| `01-verify-deps` | Installs deb MAAS (if selected) and verifies core CLI dependencies (`lxc`, `jq`, `maas`, `juju`, `openstack`) |
| `02-maas-init` | Configures PostgreSQL, initializes MAAS, creates the admin user, and uploads SSH keys |
| `03-maas-networking` | Configures subnets, DHCP ranges, VLANs, spaces, and DNS settings in MAAS |
| `04-maas-images` | Triggers and monitors the synchronization of required OS boot images |
| `05-lxd-setup` | Establishes certificate trust between MAAS and the LXD provider |
| `06-vm-creation` | Provisions the virtual machines and attaches OSD block volumes and Neutron interfaces |
| `07-maas-enlist` | Boots the machines and monitors their automatic enlistment into MAAS |
| `08-maas-configure` | Assigns availability zones, hostnames, and LXD power controls |
| `09-maas-commission` | Triggers the commissioning phase and waits for hardware discovery |
| `10-maas-tagging` | Applies hardware tags, configures flat storage layouts, and tags OSD disks and Neutron interfaces |
| `11-juju-add-cloud` | Registers MAAS as a Juju cloud and imports the MAAS API credentials |
| `12-juju-bootstrap` | Bootstraps the Juju controller and enables controller HA if `juju_ha > 1` |
| `13-juju-deploy` | Creates the `openstack` Juju model and provisions the bare-metal OpenStack machines |
| `14-juju-deploy-ceph-osd` | Deploys `ceph-osd` across all OpenStack nodes using the attached raw block devices |
| `15-juju-deploy-nova-compute` | Deploys `nova-compute` across the compute nodes |
| `16-juju-deploy-mysql` | Deploys a 3-unit `mysql-innodb-cluster` in LXD containers |
| `17-juju-deploy-vault` | Deploys Vault, connects it to MySQL, initializes/unseals it, and generates the root CA |
| `18-juju-deploy-neutron` | Deploys `ovn-central`, `neutron-api`, `neutron-api-plugin-ovn`, and `ovn-chassis` with TLS and DB integrations |
| `19-juju-deploy-keystone` | Deploys Keystone and integrates it with MySQL, Vault, and Neutron API |
| `20-juju-deploy-rabbitmq` | Deploys RabbitMQ and integrates it with Nova Compute and Neutron API |
| `21-juju-deploy-ncc` | Deploys `nova-cloud-controller` and integrates it with MySQL, Keystone, RabbitMQ, Neutron, Nova Compute, and Vault |
| `22-juju-deploy-placement` | Deploys Placement and integrates it with MySQL, Keystone, Nova Cloud Controller, and Vault |
| `23-juju-deploy-dashboard` | Deploys `openstack-dashboard` (Horizon) and integrates it with MySQL, Keystone, and Vault |
| `24-juju-deploy-glance` | Deploys Glance and integrates it with MySQL, Keystone, Nova, and Vault |
| `25-juju-deploy-ceph-mon` | Deploys a 3-unit `ceph-mon` cluster and integrates Ceph storage with OSDs, Nova Compute (RBD), and Glance |
| `26-juju-deploy-cinder` | Deploys Cinder and `cinder-ceph` and integrates them with MySQL, Keystone, RabbitMQ, Glance, Ceph, and Nova |
| `27-juju-deploy-ceph-radosgw` | Deploys `ceph-radosgw` and integrates it with `ceph-mon` |
| `28-openstack-configure` | Waits for the model to settle, generates `~/openrc`, imports the base Glance image, creates flavor `m1`, and configures `ext_net` |

### Why is this useful?

If a deployment fails at step `18` due to a transient network error or charm timeout, you **do not** need to destroy the lab and start over. Connect to the primary machine with `./synth shell <id>` (which automatically falls back to `lxc shell` if SSH is not up yet) and re-run the specific script:

```bash
ubuntu@maas-1:~$ 18-juju-deploy-neutron
```

## Variables
When launching this Transcript, `synth` will parse the payload and optionally prompt for the following configuration values.

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| update_n_upgrade | True | Auto Update & Upgrade base packages |
| vm_image | ubuntu:22.04 | Base operating system image for the primary MAAS controller |
| sys_user | ubuntu | Default system user for SSH access |
| password | ubuntu | Password for the default system user |
| pro_token | None | Optional Ubuntu Pro token for extended packages |
| hostname | None | Custom hostname for the MAAS controller |
| tld | openstack | Top Level Domain for the MAAS environment |
| timezone | America/New_York | System timezone |
| timeout | 60m | Timeout duration for Juju application and model wait loops |
| lxd_channel | 5.21/stable | Snap channel for the LXD installation |
| maas_channel | 3.7/stable | Snap channel for the MAAS installation |
| juju_channel | 3.6/stable | Snap channel for the Juju installation |
| openstack_channel | 2023.2/stable | Charm channel for OpenStack components |
| ceph_channel | reef/stable | Charm channel for Ceph components |
| mysql_channel | 8.0/stable | Charm channel for MySQL InnoDB |
| rabbitmq_channel | 3.9/stable | Charm channel for RabbitMQ |
| ovn_channel | 23.09/stable | Charm channel for OVN |
| vault_channel | 1.8/stable | Charm channel for Vault |
| lxd_pool | default | Target LXD storage pool for the deployment |
| maas_user | admin | Web UI and API admin username for MAAS |
| maas_password | admin | Web UI and API admin password for MAAS |
| maas_email | admin@email.com | Admin email address for MAAS |
| maas_images | jammy | Space separated list of Ubuntu releases to sync |
| maas_space | openstackspace | Logical network space name mapped in MAAS |
| maas_dns | 8.8.8.8 | Upstream DNS forwarder for the MAAS network |
| maas_bridge | mbr0 | Name of the primary MAAS network bridge |
| maas_cidr | 10.10.0.0/22 | Subnet CIDR for the MAAS network |
| maas_ip_count | 30 | Number of IPs to reserve for the MAAS dynamic DHCP pool |
| os_neutron_bridge | nbr0 | Name of the dedicated Neutron network bridge |
| os_neutron_cidr | 10.20.0.0/22 | Subnet CIDR for the OpenStack provider network |
| os_ip_count | 50 | Number of IPs to reserve for OpenStack floating IPs |
| os_base_flavor | jammy | Base OS image to automatically import into Glance |
| os_ram_flavor | 2048 | RAM allocation for the default Nova flavor |
| os_disk_flavor | 10 | Disk allocation for the default Nova flavor |
| os_e_disk_flavor | 10 | Ephemeral disk allocation for the default Nova flavor |
| maas_cpu | 2 | CPU cores allocated to the MAAS controller |
| maas_ram | 4GiB | RAM allocated to the MAAS controller |
| maas_disk | 30GiB | Root disk size for the MAAS controller |
| juju_ha | 1 | Total number of Juju controller machines to provision |
| juju_cpu | 2 | CPU cores allocated to each Juju controller |
| juju_ram | 6GiB | RAM allocated to each Juju controller |
| juju_disk | 20GiB | Root disk size for each Juju controller |
| juju_base | ubuntu@22.04 | Operating system base used for the Juju bootstrap |
| node_ha | 4 | Total number of OpenStack machines to provision (minimum 3) |
| node_cpu | 4 | CPU cores allocated to each OpenStack machine |
| node_ram | 12GiB | RAM allocated to each OpenStack machine |
| node_disk | 50GiB | Root disk size for each OpenStack machine |
| node_osd_disk | 10GiB | Size of each attached Ceph OSD volume |
| node_osd_count | 3 | Number of Ceph OSD volumes to attach per OpenStack machine |

---

# Transcript: DevStack

## Description
A fully automated, monolithic OpenStack environment deployed via upstream DevStack. This Transcript synthesizes a single, heavy-duty virtual machine that pulls directly from OpenDev repositories to build an all-in-one OpenStack cloud. It serves as a fast, highly configurable reproducer for upstream development, API testing, and validating bleeding-edge OpenStack features without the overhead of a multi-node Juju + MAAS deployment.

## Architecture Overview
This reproducer deploys an all-in-one upstream OpenStack cloud inside a single vertically scaled LXD virtual machine:

### Cloud Architecture (All-in-One):
- Primary VM (`devstack`): Runs all OpenStack control-plane, database, messaging, and compute services locally under a dedicated `stack` user (`/opt/stack/devstack`).
- Compute Virtualization: Explicitly configures Libvirt with KVM hardware acceleration (`LIBVIRT_TYPE=kvm`) and `host-passthrough` CPU mode for nested guest performance.
- Optional Service Plugins: Dynamically enables upstream plugins for Swift, Skyline, Masakari, Heat, Designate, Octavia (with OVN provider), Barbican, and Tempest based on your configuration.

### Network Architecture:
- Primary Uplink (`lbr0` / `lxd_cidr`): Uses a single NAT-enabled, DHCP-managed LXD bridge for external access. DevStack binds `HOST_IP` to this interface and configures its own internal Neutron/OVN networking on top of it.

### Provisioning Pipeline
The LXD virtual machine is provisioned with `/dev/kvm` permissions and a dedicated `stack` user, clones the requested branch from OpenDev, renders `/opt/stack/devstack/local.conf` with your selected plugins, executes `stack.sh`, and copies `openrc` into the default user's home directory.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the *default* topology.
- CPU: 20 cores
- RAM: 40 GiB
- Disk: 150 GiB
- Network: Outbound internet access for extensive git cloning, pip installations, and apt package downloads

## Usage
Deploy this Transcript using the `se-polymerase` orchestrator. The orchestrator isolates all generated files into a dedicated `[DEPLOY_ID]` directory and automatically handles headless background execution.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth OpenStack/devstack.yaml -y
```

Prompt for all variables interactively and assign a specific case number as the deployment ID:
```bash
./synth OpenStack/devstack.yaml 00426900
```

Deploy bypassing prompts by passing a pre-generated configuration file from a previous run:
```bash
./synth OpenStack/devstack.yaml -yc OpenStack/00426900/config-devstack-00426900.yaml
```

### Configuration Files and "Dry Runs"
Every time you execute `synth` interactively, it automatically records your answers and generates a reusable YAML configuration file (e.g., `config-[PROJECT].yaml`). You can pass this file to the `-c` flag in future runs to perfectly replicate a specific environment without having to manually answer the prompts again.

#### How to perform a "Dry Run" (Generate a config without deploying):
If you want to build a configuration file to review, share, or edit *before* actually spinning up any resources, you can use `synth` as a configuration generator:

1. Run `synth` interactively (do **not** use the `-y` flag):
   ```bash
   ./synth OpenStack/devstack.yaml
   ```
2. Answer all the prompts to configure your environment.
3. At the final resource confirmation prompt (`Proceed with deployment using these resources and networks? [y/N]:`), answer `n` to abort.
4. The script will catch the abort and ask: `Keep generated config file 'config-[PROJECT].yaml' for your next run? [y/N]:`. Answer `y`.

You now have a fully populated configuration file inside the generated deployment directory that you can safely tweak and deploy later using:
```bash
./synth OpenStack/devstack.yaml -y -c OpenStack/[DEPLOY_ID]/config-[PROJECT].yaml
```

## Access and Cleanup
Because the deployment is executed in the background, you can detach your terminal at any time. Check active labs with `./synth list` and monitor live progress using the lab's numeric ID or deploy ID:
```bash
./synth monitor 00426900
```

Once the payload finishes executing, `synth` will automatically drop you into an SSH shell connected to the DevStack machine. You can reconnect at any time using:
```bash
./synth shell 00426900
```

View all SSH tunneling commands, dashboard URLs, and credentials stored in `access-[PROJECT].txt`:
```bash
./synth info 00426900
```

An `openrc` file is automatically generated in your user directory and sourced at login. You can interact with the OpenStack CLI:
```bash
openstack server list
```
All DevStack scripts and configurations are located in `/opt/stack/devstack`.

To completely wipe this environment and release its resources (pass `-a` / `--all` to also remove the saved configuration file):
```bash
./synth destroy 00426900
```

## Modular Execution and Recovery
To make debugging and recovery effortless, the entire cloud-init deployment pipeline is broken down into discrete, numbered executable scripts located in `/usr/local/bin/` on the DevStack machine.

If a specific phase of the deployment fails or times out, you do not need to destroy the environment and start over. Connect to the DevStack machine and execute the failed step manually to retry it. Every script automatically escalates privileges and sources the `/etc/repro-env` state file.

| Script | Description |
| :--- | :--- |
| `00-generate-env` | Initializes the persistent state file `/etc/repro-env` with runtime IP and interface details |
| `01-verify-deps` | Verifies core CLI dependencies (`jq`) |
| `02-devstack-configure` | Clones the target DevStack branch into `/opt/stack/devstack` and generates `local.conf` with all enabled plugins |
| `03-devstack-install` | Executes `stack.sh` as the `stack` user and copies `openrc` into the default user's home directory |

### Why is this useful?

If `stack.sh` fails during step `03` due to a transient upstream package or git error, you **do not** need to destroy the lab and start over. Connect to the machine with `./synth shell <id>` (which automatically falls back to `lxc shell` if SSH is not up yet) and re-run the installation step:

```bash
ubuntu@devstack:~$ 03-devstack-install
```

## Variables
When launching this Transcript, `synth` will parse the payload and optionally prompt for the following configuration values.

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| update_n_upgrade | True | Auto Update & Upgrade base packages |
| vm_image | ubuntu:24.04 | Base operating system image for the DevStack machine |
| sys_user | ubuntu | Default system user for SSH access |
| password | ubuntu | Password for the default system user |
| pro_token | None | Optional Ubuntu Pro token for extended packages |
| hostname | None | Custom hostname for the DevStack machine |
| tld | None | Top Level Domain for the local environment |
| timezone | America/New_York | System timezone |
| lxd_pool | default | Target LXD storage pool for the deployment |
| lxd_bridge | lbr0 | Name of the primary LXD network bridge |
| lxd_cidr | 10.10.0.0/22 | Subnet CIDR for the LXD network |
| devstack_release | stable/2025.2 | Git branch to clone from the upstream DevStack repository |
| devstack_password | admin | Universal password applied to all OpenStack services and databases |
| enable_swift | True | Enables the Swift object storage plugin |
| enable_skyline | True | Enables the Skyline dashboard plugin |
| enable_masakari | True | Enables the Masakari instance high availability plugin |
| enable_heat | True | Enables the Heat orchestration plugin |
| enable_designate | True | Enables the Designate DNS plugin |
| enable_octavia | True | Enables the Octavia load balancing plugin |
| enable_barbican | True | Enables the Barbican key manager plugin |
| primary_cpu | 20 | CPU cores allocated to the DevStack machine |
| primary_ram | 40GiB | RAM allocated to the DevStack machine |
| primary_disk | 150GiB | Root disk size for the DevStack machine |

