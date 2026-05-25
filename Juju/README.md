# Transcript: Juju

## Description
A fully automated, highly available Juju orchestration environment integrated directly with MAAS. This Transcript synthesizes a primary MAAS controller, provisions a fleet of empty LXD virtual machines, enlists them as bare-metal nodes, and then automatically bootstraps a Juju controller cluster to take ownership of the hardware. It serves as the baseline reproducer for complex Juju-on-MAAS deployments.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the default topology.
* CPU: 22 cores
* RAM: 58 GiB
* Disk: 210 GiB
* Network: Outbound internet access for LXD image downloads, MAAS image synchronization, and Juju agent downloads.

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
| juju_channel | 3.6/stable | Snap channel for the Juju installation |
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
| juju_ha | 3 | Total number of Juju controller machines to provision |
| juju_cpu | 2 | CPU cores allocated to each Juju controller |
| juju_ram | 6GiB | RAM allocated to each Juju controller |
| juju_disk | 20GiB | Root disk size for each Juju controller |
| juju_base | ubuntu@22.04 | Operating system base used for the Juju bootstrap |
| node_ha | 4 | Total number of standard compute machines to provision |
| node_cpu | 3 | CPU cores allocated to each standard compute machine |
| node_ram | 8GiB | RAM allocated to each standard compute machine |
| node_disk | 30GiB | Root disk size for each standard compute machine |

## Usage
Deploy this Transcript using the `se-polymerase` orchestrator.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth.sh Juju/juju.yaml -a
```

Deploy with a nested LXD architecture, prompt for all variables interactively, and assign a specific case number as the deployment ID:
```bash
./synth.sh Juju/juju.yaml -n 00426900
```

## Access and Cleanup
Once the payload finishes executing, `synth` will automatically drop you into a secure multiplexed SSH shell connected to the primary controller. 

The MAAS web UI access URL will be printed to your terminal at the end of the deployment phase, along with the exact SSH tunneling commands required to securely reach it from your local browser. You can immediately begin interacting with the Juju client from the terminal using standard commands.

To completely wipe this environment and release its resources, execute the auto-generated teardown script located in your working directory:
```bash
./destroy-[PROJECT_NAME].sh
```

## Architecture Overview
* Network Topology: Utilizes a single NAT-enabled LXD bridge. The primary controller provides DHCP and DNS for the subnet to facilitate PXE booting.
* Node Distribution: One primary MAAS controller containing the MAAS services and Juju client. Three dedicated machines are tagged specifically for Juju HA controller duties, while the remaining nodes are tagged as generic compute machines.
* Provisioning Pipeline: All nodes are created natively via the LXD API, powered on, and PXE booted. Once MAAS commissions the hardware, the Juju client is configured with the MAAS API credentials. Juju then bootstraps the orchestration layer onto the nodes tagged "juju-controller" and subsequently requests MAAS to allocate the remaining machines to a default model.
