# Transcript: Landscape

## Description
A fully automated, highly available Landscape environment orchestrated by Juju on top of MAAS. This Transcript synthesizes a primary MAAS controller, bootstraps a Juju orchestration layer, and performs a dense deployment of Charmed Landscape. It provisions PostgreSQL directly on bare-metal nodes while placing HAProxy, RabbitMQ, and Landscape Server components into nested containers, alongside separate client machines that automatically register themselves to the control plane.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the default topology.
* CPU: 22 cores
* RAM: 60 GiB
* Disk: 310 GiB
* Network: Outbound internet access for LXD image downloads, MAAS image synchronization, and Juju charm deployments

## Variables
When launching this Transcript, `synth` will parse the payload and optionally prompt for the following configuration values.

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| vm_image | ubuntu:24.04 | Base operating system image for the primary MAAS controller |
| sys_user | ubuntu | Default system user for SSH access |
| password | ubuntu | Password for the default system user |
| pro_token | None | Optional Ubuntu Pro token for extended packages and automated client attachment |
| hostname | None | Custom hostname for the MAAS controller |
| tld | landscape | Top Level Domain for the MAAS environment |
| timezone | America/New_York | System timezone |
| lxd_channel | 5.21/stable | Snap channel for the LXD installation |
| maas_channel | 3.7/stable | Snap channel for the MAAS installation |
| juju_channel | 3.6/stable | Snap channel for the Juju installation |
| haproxy_channel | latest/stable | Charm channel for HAProxy |
| postgresql_channel | 14/stable | Charm channel for PostgreSQL |
| rabbitmq_channel | 3.9/stable | Charm channel for RabbitMQ Server |
| landscape_server_channel | latest/stable | Charm channel for Landscape Server |
| landscape_client_channel | latest/stable | Charm channel for Landscape Client |
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
| juju_ha | 1 | Total number of Juju controller machines to provision |
| juju_cpu | 2 | CPU cores allocated to each Juju controller |
| juju_ram | 6GiB | RAM allocated to each Juju controller |
| juju_disk | 20GiB | Root disk size for each Juju controller |
| juju_base | ubuntu@22.04 | Operating system base used for the Juju bootstrap |
| node_ha | 3 | Total number of core Landscape machines to provision |
| node_cpu | 3 | CPU cores allocated to each core Landscape machine |
| node_ram | 8GiB | RAM allocated to each core Landscape machine |
| node_disk | 40GiB | Root disk size for each core Landscape machine |
| client_ha | 1 | Total number of separate client machines to provision |
| client_cpu | 2 | CPU cores allocated to each client machine |
| client_ram | 4GiB | RAM allocated to each client machine |
| client_disk | 10GiB | Root disk size for each client machine |
| client_base | ubuntu@22.04 | Operating system base used for the client machines |

## Usage
Deploy this Transcript using the `se-polymerase` orchestrator.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth Landscape/landscape.yaml -a
```

Deploy with a nested LXD architecture, prompt for all variables interactively, and assign a specific case number as the deployment ID:
```bash
./synth Landscape/landscape.yaml -n 00426900
```

## Access and Cleanup
Once the payload finishes executing, `synth` will automatically drop you into a secure multiplexed SSH shell connected to the primary MAAS controller. 

The MAAS web UI access URL will be printed to your terminal at the end of the deployment phase. To access the Landscape Server web UI, you can query Juju for the HAProxy public IP address once connected to the controller:
```bash
juju status
```

To completely wipe this environment and release its resources, execute the auto-generated teardown script located in your working directory:
```bash
./destroy-[PROJECT_NAME].sh
```

## Architecture Overview

* Network Topology: Utilizes a single NAT-enabled LXD bridge. The primary controller provides DHCP and DNS for the subnet to facilitate bare-metal PXE booting.
* Node Distribution: Features one primary MAAS controller, one Juju controller, three core Landscape nodes, and one dedicated client node.
* Provisioning Pipeline: All nodes are created natively via the LXD API, powered on, and PXE booted. MAAS commissions the hardware, and Juju bootstraps the orchestration layer. Juju then deploys PostgreSQL directly to the metal of the three core nodes, while co-locating HAProxy, RabbitMQ, and the Landscape Server inside LXD containers on those same nodes for dense resource utilization. Finally, standard Ubuntu machines are deployed and the Landscape Client charm is applied and registered to the newly built server cluster.
