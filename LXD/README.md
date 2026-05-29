# Transcript: LXD

## Description
A streamlined, purely LXD-focused environment. This Transcript synthesizes a primary host node that securely configures the LXD daemon and orchestrates a fleet of Ubuntu virtual machines. It serves as a lightweight, fast reproducer for base operating system testing, LXD clustering, or general-purpose virtual machine scaling without the overhead of MAAS or Juju.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the default topology.
* CPU: 19 cores
* RAM: 48 GiB
* Disk: 180 GiB
* Network: Outbound internet access for LXD image downloads and package installations

## Variables
When launching this Transcript, `synth` will parse the payload and optionally prompt for the following configuration values.

| Variable | Default Value | Description |
| :--- | :--- | :--- |
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

## Usage
Deploy this Transcript using the `se-polymerase` orchestrator.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth LXD/lxd.yaml -a
```

Deploy with a nested LXD architecture, prompt for all variables interactively, and assign a specific case number as the deployment ID:
```bash
./synth LXD/lxd.yaml -n 00426900
```

## Access and Cleanup
Once the payload finishes executing, `synth` will automatically drop you into a secure multiplexed SSH shell connected to the primary node. From here, you can immediately interact with the running fleet using standard `lxc` commands.

The LXD Web UI access URL will be printed to your terminal at the end of the deployment phase, along with the exact SSH tunneling commands required to securely reach it from your local browser.

To completely wipe this environment and release its resources, execute the auto-generated teardown script located in your working directory:
```bash
./destroy-[PROJECT_NAME].sh
```

## Architecture Overview
* Network Topology: Utilizes a single NAT-enabled LXD bridge. The primary node provides standard DHCP and outbound internet routing for the child virtual machines.
* Node Distribution: Features one primary host node managing the core LXD daemon and a dedicated fleet of child virtual machines (defaulting to 5) running the specified Ubuntu image.
* Provisioning Pipeline: The primary node configures the LXD daemon and establishes client certificate trust. It then provisions a strictly isolated LXD project and directly launches the specified fleet of virtual machines using the native LXD API.
