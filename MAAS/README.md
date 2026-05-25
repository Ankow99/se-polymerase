# Transcript: MAAS

## Description
A fully automated, highly scalable MAAS environment. This Transcript synthesizes a primary MAAS controller that dynamically provisions, PXE boots, and commissions empty LXD virtual machines acting as bare-metal nodes. It serves as a foundational reproducer for hardware provisioning, networking, and storage tagging workflows.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the default topology.
* CPU: 19 cores
* RAM: 48 GiB
* Disk: 180 GiB
* Network: Outbound internet access for LXD image downloads and MAAS image synchronization

## Variables
When launching this Transcript, `synth` will parse the payload and optionally prompt for the following configuration values.

| Variable | Default Value | Description |
| :--- | :--- | :--- |
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
| maas_images | noble jammy | Space-separated list of Ubuntu releases to sync |
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

## Usage
Deploy this Transcript using the `se-polymerase` orchestrator.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth.sh MAAS/maas.yaml -a
```

Deploy with a nested LXD architecture, prompt for all variables interactively, and assign a specific case number as the deployment ID:
```bash
./synth.sh MAAS/maas.yaml -n 00426900
```

## Access and Cleanup
Once the payload finishes executing, `synth` will automatically drop you into a secure multiplexed SSH shell connected to the primary MAAS controller. 

The MAAS web UI access URL will be printed to your terminal at the end of the deployment phase, along with the exact SSH tunneling commands required to securely reach it from your local browser.

To completely wipe this environment and release its resources, execute the auto-generated teardown script located in your working directory:
```bash
./destroy-[PROJECT_NAME].sh
```

## Architecture Overview
* Network Topology: Utilizes a single NAT-enabled LXD bridge functioning as the untrusted network. The MAAS controller provides DHCP and DNS for this subnet to facilitate PXE booting.
* Node Distribution: One primary MAAS controller containing the PostgreSQL database, region daemon, and rack daemon. A dynamic fleet of blank compute nodes (defaulting to 5) are attached to the same network bridge.
* Provisioning Pipeline: Compute nodes are created natively via the LXD API, powered on, and PXE booted into MAAS. The cloud-init script automatically oversees their enlistment, assigns them to isolated Availability Zones, tags their block devices as SSDs, and successfully commissions them into a Ready state.
