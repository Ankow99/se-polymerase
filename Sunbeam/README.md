# Transcript: Sunbeam

## Description
A fully automated, scalable OpenStack environment deployed via Canonical Sunbeam on top of MAAS. This Transcript synthesizes a primary MAAS controller, provisions a fleet of LXD virtual machines, enlists them as bare-metal nodes, and executes the Sunbeam cluster bootstrap and deployment processes. It serves as a comprehensive reproducer for microk8s-based OpenStack architectures using the Sunbeam snap.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the default topology.
* CPU: 22 cores
* RAM: 60 GiB
* Disk: 310 GiB
* Network: Outbound internet access for LXD image downloads, MAAS image synchronization, and Sunbeam snap installations

## Variables
When launching this Transcript, `synth` will parse the payload and optionally prompt for the following configuration values.

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| vm_image | ubuntu:24.04 | Base operating system image for the primary MAAS controller |
| sys_user | ubuntu | Default system user for SSH access |
| password | ubuntu | Password for the default system user |
| pro_token | None | Optional Ubuntu Pro token for extended packages |
| hostname | None | Custom hostname for the MAAS controller |
| tld | sunbeam | Top Level Domain for the MAAS environment |
| timezone | America/New_York | System timezone |
| lxd_channel | 5.21/stable | Snap channel for the LXD installation |
| maas_channel | 3.7/stable | Snap channel for the MAAS installation |
| sunbeam_channel | 2024.1/stable | Snap channel for the Sunbeam installation |
| lxd_pool | default | Target LXD storage pool for the deployment |
| maas_user | admin | Web UI and API admin username for MAAS |
| maas_password | admin | Web UI and API admin password for MAAS |
| maas_email | admin@email.com | Admin email address for MAAS |
| maas_images | noble | Space separated list of Ubuntu releases to sync |
| maas_space | sunspace | Logical network space name mapped in MAAS and Sunbeam |
| maas_dns | 8.8.8.8 | Upstream DNS forwarder for the MAAS network |
| maas_bridge | mbr0 | Name of the primary MAAS network bridge |
| maas_cidr | 10.10.0.0/22 | Subnet CIDR for the MAAS network |
| maas_ip_count | 30 | Number of IPs to reserve for the MAAS dynamic DHCP pool |
| os_deployment | sunbeam | Internal logical name for the Sunbeam deployment |
| os_neutron_bridge | nbr0 | Name of the dedicated Neutron network bridge |
| os_neutron_cidr | 10.20.0.0/22 | Subnet CIDR for the OpenStack provider network |
| os_pub_api_ip_count | 50 | Number of IPs to reserve for the OpenStack Public API |
| os_int_api_ip_count | 50 | Number of IPs to reserve for the OpenStack Internal API |
| maas_cpu | 4 | CPU cores allocated to the MAAS controller |
| maas_ram | 8GiB | RAM allocated to the MAAS controller |
| maas_disk | 30GiB | Root disk size for the MAAS controller |
| juju_ha | 1 | Total number of Juju controller machines to provision |
| juju_cpu | 3 | CPU cores allocated to each Juju controller |
| juju_ram | 6GiB | RAM allocated to each Juju controller |
| juju_disk | 30GiB | Root disk size for each Juju controller |
| sunbeam_ha | 1 | Total number of Sunbeam controller machines to provision |
| sunbeam_cpu | 3 | CPU cores allocated to each Sunbeam controller |
| sunbeam_ram | 6GiB | RAM allocated to each Sunbeam controller |
| sunbeam_disk | 30GiB | Root disk size for each Sunbeam controller |
| cloud_ha | 1 | Total number of hyperconverged cloud compute nodes to provision |
| cloud_cpu | 12 | CPU cores allocated to each cloud compute node |
| cloud_ram | 40GiB | RAM allocated to each cloud compute node |
| cloud_disk | 100GiB | Root disk size for each cloud compute node |
| cloud_osd_disk | 30GiB | Size of each attached Ceph OSD volume |
| cloud_osd_count | 4 | Number of Ceph OSD volumes to attach per cloud compute node |

## Usage
Deploy this Transcript using the `se-polymerase` orchestrator.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth.sh Sunbeam/sunbeam.yaml -a
```

Deploy with a nested LXD architecture, prompt for all variables interactively, and assign a specific case number as the deployment ID:
```bash
./synth.sh Sunbeam/sunbeam.yaml -n 00426900
```

## Access and Cleanup
Once the payload finishes executing, `synth` will automatically drop you into a secure multiplexed SSH shell connected to the primary MAAS controller.

A `sunrc` file is automatically generated in your user directory and sourced at login. You can interact with the OpenStack CLI and manage the newly deployed cloud:
```bash
openstack server list
```

The MAAS web UI access URL will be printed to your terminal at the end of the deployment phase, along with the exact SSH tunneling commands required to securely reach it from your local browser.

To completely wipe this environment and release its resources, execute the auto-generated teardown script located in your working directory:
```bash
./destroy-[PROJECT_NAME].sh
```

## Architecture Overview
* Network Topology: Utilizes a dual-bridge network. The primary bridge handles MAAS provisioning and PXE traffic, while a secondary bridge provides an isolated Neutron provider network for OpenStack traffic.
* Node Distribution: Features one primary MAAS controller, one dedicated Juju controller, one Sunbeam cluster controller, and one heavy compute node handling the bulk of the virtualization and storage workload.
* Provisioning Pipeline: Nodes are created natively via the LXD API and commissioned in MAAS. Ceph OSDs are mapped to the compute node as raw block devices. The `sunbeam` CLI is invoked on the primary MAAS controller to validate the MAAS provider, map the network spaces, generate a multi-node manifest, and ultimately execute the cluster bootstrap and cloud configuration sequences.
