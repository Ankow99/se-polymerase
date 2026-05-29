# Transcript: Snapcraft

## Description
A dedicated environment tailored specifically for building and testing snaps. This Transcript synthesizes a lightweight, isolated LXD virtual machine pre-configured with Snapcraft and a nested LXD daemon. It securely injects your base64 encoded store credentials directly into the build environment, allowing for immediate, automated snap packaging and publishing.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the default topology.
* CPU: 4 cores
* RAM: 10 GiB
* Disk: 50 GiB
* Network: Outbound internet access for snap downloads and Snap Store communication

## Variables
When launching this Transcript, `synth` will parse the payload and optionally prompt for the following configuration values.

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| vm_image | ubuntu:24.04 | Base operating system image for the primary virtual machine |
| sys_user | ubuntu | Default system user for SSH access |
| password | ubuntu | Password for the default system user |
| pro_token | None | Optional Ubuntu Pro token for extended packages |
| hostname | None | Custom hostname for the Snapcraft machine |
| tld | None | Top Level Domain for the local environment |
| timezone | America/New_York | System timezone |
| lxd_channel | 5.21/stable | Snap channel for the nested LXD installation |
| snapcraft_channel | latest/stable | Snap channel for the Snapcraft installation |
| snapcraft_creds_b64 | None | Base64 encoded Snapcraft login credentials |
| lxd_project | default | Target LXD project for the deployment |
| lxd_pool | default | Target LXD storage pool for the deployment |
| lxd_bridge | lbr0 | Name of the primary LXD network bridge |
| lxd_cidr | 10.10.0.0/22 | Subnet CIDR for the LXD network |
| primary_cpu | 4 | CPU cores allocated to the primary host VM |
| primary_ram | 10GiB | RAM allocated to the primary host VM |
| primary_disk | 50GiB | Root disk size for the primary host VM |

## Usage
Deploy this Transcript using the `se-polymerase` orchestrator.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth.sh Snapcraft/snapcraft.yaml -a
```

Deploy with a nested LXD architecture, prompt for all variables interactively, and assign a specific case number as the deployment ID:
```bash
./synth.sh Snapcraft/snapcraft.yaml -n 00426900
```

## Access and Cleanup
Once the payload finishes executing, `synth` will automatically drop you into a secure multiplexed SSH shell connected to the node.

Your base64 credentials are automatically written to a hidden `.snapcraft-credentials` file and exported as an environment variable in the user's `~/.bashrc`. You can immediately begin using Snapcraft commands without requiring a manual login.

```bash
snapcraft whoami
```

To completely wipe this environment and release its resources, execute the auto-generated teardown script located in your working directory:
```bash
./destroy-[PROJECT_NAME].sh
```

## Architecture Overview
* Network Topology: Utilizes a single NAT-enabled LXD bridge for outbound internet access and Snap Store communication.
* Node Distribution: Features a single virtual machine acting as a dedicated build host.
* Provisioning Pipeline: The host machine provisions the virtual machine and installs the necessary snaps. The cloud-init script initializes a local LXD daemon inside the VM to serve as the isolated build provider for Snapcraft, bypassing the need for Multipass. Credentials are automatically injected and secured with strict file permissions.
