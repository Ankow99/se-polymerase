# Transcript: Charmed OpenStack

## Description
A fully automated, highly available Charmed OpenStack environment orchestrated by Juju on top of MAAS. This Transcript synthesizes a primary MAAS controller, bootstraps a Juju orchestration layer, and performs a dense deployment of OpenStack components. It provisions core services like Nova, Neutron (OVN), Keystone, Glance, Placement, and Cinder alongside a fully integrated Ceph storage cluster and HashiCorp Vault for certificate management.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the default topology.
* CPU: 20 cores
* RAM: 58 GiB
* Disk: 370 GiB
* Network: Outbound internet access for LXD image downloads, MAAS image synchronization, and Juju charm deployments

## Variables
When launching this Transcript, `synth` will parse the payload and optionally prompt for the following configuration values. 

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| vm_image | ubuntu:22.04 | Base operating system image for the primary MAAS controller |
| sys_user | ubuntu | Default system user for SSH access |
| password | ubuntu | Password for the default system user |
| pro_token | None | Optional Ubuntu Pro token for extended packages |
| hostname | None | Custom hostname for the MAAS controller |
| tld | openstack | Top Level Domain for the MAAS environment |
| timezone | America/New_York | System timezone |
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
| node_cpu | 4 | CPU cores allocated to each OpenStack machine |
| node_ram | 12GiB | RAM allocated to each OpenStack machine |
| node_disk | 50GiB | Root disk size for each OpenStack machine |
| node_osd_disk | 10GiB | Size of each attached Ceph OSD volume |
| node_osd_count | 3 | Number of Ceph OSD volumes to attach per OpenStack machine |

*Note: The total number of OpenStack hyperconverged machines is strictly fixed at 4. This ensures the cluster meets the strict quorum and architectural requirements of a high-availability deployment without overwhelming host resources.*

## Release Generation Script
Due to the strict version compatibility matrix between OpenStack, Ceph, OVN, and underlying database services, this repository includes a `generate-releases.sh` script.

Instead of manually editing the base template to test older OpenStack releases, you can run the generator script against the base transcript. The script iterates through Canonical's official version matrix and outputs discrete, version-locked `cloud-init` templates for each supported release.

To generate the release templates:
```bash
./generate-releases.sh transcripts/openstack.yaml
```
This will output distinct files such as `focal-ussuri.yaml`, `jammy-yoga.yaml`, and `jammy-2023.2.yaml` into your directory, with all underlying snap and charm channels properly pinned.

## Usage
Deploy a generated OpenStack release using the `se-polymerase` orchestrator.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth OpenStack/focal-ussuri.yaml -a
```

Deploy with a nested LXD architecture, prompt for all variables interactively, and assign a specific case number as the deployment ID:
```bash
./synth OpenStack/jammy-2023.2.yaml -n 00426900
```

## Access and Cleanup
Once the payload finishes executing, `synth` will automatically drop you into a secure multiplexed SSH shell connected to the primary MAAS controller. 

An `openrc` file is automatically generated in your user directory and sourced at login. You can interact with the OpenStack CLI:
```bash
openstack server list
```

The MAAS web UI access URL will be printed to your terminal at the end of the deployment phase, along with the exact SSH tunneling commands required to securely reach it from your local browser. Vault is automatically unsealed and authorized, and the initialization keys are saved to `~/vault-init.json`.

To completely wipe this environment and release its resources, execute the auto-generated teardown script located in your working directory:
```bash
./destroy-[PROJECT_NAME].sh
```

## Architecture Overview
* Network Topology: Utilizes a dual-bridge network. The primary bridge handles MAAS provisioning and PXE traffic, while a secondary bridge provides an isolated Neutron provider network for OpenStack floating IPs.
* Node Distribution: Features one primary MAAS controller, one Juju controller, and four hyperconverged OpenStack nodes.
* Provisioning Pipeline: All nodes are created natively via the LXD API. The four OpenStack nodes are dynamically configured with loop-backed ZFS volumes that MAAS registers and tags as raw SSD block devices. Juju deploys MySQL, Vault, and Ceph Monitors in LXD containers across the nodes, while mapping Ceph OSDs and Nova Compute directly to the bare metal instances for hardware access.

---

# Transcript: DevStack

## Description
A fully automated, monolithic OpenStack environment deployed via upstream DevStack. This Transcript synthesizes a single, heavy-duty virtual machine that pulls directly from OpenDev repositories to build an all-in-one OpenStack cloud. It serves as a fast, highly configurable reproducer for upstream development, API testing, and validating bleeding-edge OpenStack features without the overhead of a multi-node Juju + MAAS deployment.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the default topology.
* CPU: 20 cores
* RAM: 40 GiB
* Disk: 150 GiB
* Network: Outbound internet access for extensive git cloning, pip installations, and apt package downloads

## Variables
When launching this Transcript, `synth` will parse the payload and optionally prompt for the following configuration values.

| Variable | Default Value | Description |
| :--- | :--- | :--- |
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

## Usage
Deploy this Transcript using the `se-polymerase` orchestrator.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth OpenStack/devstack.yaml -a
```

Deploy with a nested LXD architecture, prompt for all variables interactively, and assign a specific case number as the deployment ID:
```bash
./synth OpenStack/devstack.yaml -n 00426900
```

## Access and Cleanup
Once the payload finishes executing, `synth` will automatically drop you into a secure multiplexed SSH shell connected to the DevStack machine. 

An `openrc` file is automatically generated in your user directory and sourced at login. You can interact with the OpenStack CLI:
```bash
openstack server list
```

All DevStack scripts and configurations are located in `/opt/stack/devstack`.

To completely wipe this environment and release its resources, execute the auto-generated teardown script located in your working directory:
```bash
./destroy-[PROJECT_NAME].sh
```

## Architecture Overview
* Network Topology: Utilizes a single NAT-enabled LXD bridge for primary external access. DevStack configures its own internal OVN/Neutron networking architecture on top of this bridge.
* Node Distribution: Features a single, vertically scaled virtual machine executing all OpenStack control plane and compute plane services locally.
* Provisioning Pipeline: The LXD virtual machine is provisioned and injected with a dedicated `stack` user. The machine downloads the requested branch of the upstream DevStack repository, dynamically generates a `local.conf` file based on your plugin selections, and executes `stack.sh`. KVM hardware acceleration (host-passthrough) is explicitly enabled to ensure high performance for nested guest instances.
