# Transcript: Kubeadm

## Description
A fully automated, scalable Kubernetes cluster orchestrated via `kubeadm` on top of MAAS. This Transcript synthesizes a primary MAAS controller, provisions a fleet of empty LXD virtual machines, enlists them as bare-metal nodes, and sequentially bootstraps a high-availability Kubernetes control plane and worker node pool using native `kubeadm` commands. 

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the default topology.
* CPU: 16 cores
* RAM: 38 GiB
* Disk: 210 GiB
* Network: Outbound internet access for LXD image downloads, MAAS image synchronization, and Kubernetes apt repositories.

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
| k8s_version | v1.36 | Version of Kubernetes to install via upstream apt repositories |
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
| control_ha | 3 | Total number of Kubernetes control plane nodes to provision |
| control_cpu | 2 | CPU cores allocated to each control plane node |
| control_ram | 4GiB | RAM allocated to each control plane node |
| control_disk | 30GiB | Root disk size for each control plane node |
| worker_ha | 3 | Total number of Kubernetes worker nodes to provision |
| worker_cpu | 2 | CPU cores allocated to each worker node |
| worker_ram | 6GiB | RAM allocated to each worker node |
| worker_disk | 30GiB | Root disk size for each worker node |

## Usage
Deploy this Transcript using the `se-polymerase` orchestrator.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth Kubernetes/kubeadm.yaml -a
```

Deploy with a nested LXD architecture, prompt for all variables interactively, and assign a specific case number as the deployment ID:
```bash
./synth Kubernetes/kubeadm.yaml -n 00426900
```

## Access and Cleanup
Once the payload finishes executing, `synth` will automatically drop you into a secure multiplexed SSH shell connected to the primary MAAS controller. 

The `kubeconfig` file is automatically fetched from the primary control plane node and injected directly into the MAAS controller. This allows you to immediately begin interacting with your new cluster using standard `kubectl` commands right from your terminal without having to SSH into individual nodes.

The MAAS web UI access URL will also be printed to your terminal at the end of the deployment phase, along with the exact SSH tunneling commands required to securely reach it from your local browser.

To completely wipe this environment and release its resources, execute the auto-generated teardown script located in your working directory:
```bash
./destroy-[PROJECT_NAME].sh
```

## Architecture Overview
* Network Topology: Utilizes a single NAT-enabled LXD bridge. The primary controller provides DHCP and DNS for the subnet to facilitate PXE booting. Kubernetes pod networking is handled internally via Calico CNI.
* Node Distribution: One primary MAAS controller serving as the provisioning gateway and jump host. The Kubernetes cluster itself is split between dedicated Control Plane nodes (defaulting to 3 for HA) and dedicated Worker nodes (defaulting to 3).
* Provisioning Pipeline: All nodes are created natively via the LXD API and commissioned in MAAS. The payload dynamically determines the first control plane node, deploys it, runs `kubeadm init`, configures Calico, and securely extracts the join tokens and certificate keys via SSH. It then injects those tokens into the subsequent cloud-init payloads, rolling out the remaining secondary control plane nodes and worker nodes sequentially.
