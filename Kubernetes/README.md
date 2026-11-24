# Transcript: Kubeadm

## Description
A fully automated, scalable Kubernetes cluster orchestrated via `kubeadm` on top of MAAS. This Transcript synthesizes a primary MAAS controller, provisions a fleet of empty LXD virtual machines, enlists and commissions them as bare-metal nodes across MAAS Availability Zones, and sequentially bootstraps a high-availability Kubernetes control plane and worker node pool using native `kubeadm` commands and `containerd`.

## Architecture Overview
This reproducer implements a multi-node, high-availability upstream Kubernetes cluster using Canonical MAAS as the bare-metal provider:

### Cluster Architecture:
- MAAS Controller (`maas-1`): Hosts the MAAS region/rack controller, local LXD client configuration, and `kubectl` pre-configured with the cluster's `admin.conf` so you can manage the cluster directly from the jump host.
- Control Plane Nodes (`control-plane-*`): Dedicated Kubernetes control plane machines running `kubeadm`, `kubelet`, `kubectl`, and `containerd` with the `systemd` cgroup driver (defaulting to 3 nodes for control-plane HA).
- Worker Nodes (`worker-node-*`): Dedicated compute nodes running `kubeadm`, `kubelet`, and `containerd` to schedule cluster workloads (defaulting to 3 nodes).

### Network Architecture:
- Provisioning & Cluster Network (`mbr0` / `maas_cidr`): Uses a single NAT-enabled LXD bridge mapped to the `kubespace` MAAS network space. MAAS provides DHCP and DNS for PXE booting and node resolution (including the primary control-plane FQDN endpoint on port `6443`).
- Pod Networking: Handled internally by Calico CNI (`192.168.0.0/16` pod network CIDR), automatically applied right after the primary control plane initializes.

### High Availability & Availability Zones:
- Availability Zones: Control plane and worker nodes are automatically distributed across MAAS Availability Zones (`AZ1` through `AZn`) matching their replica index.
- Control Plane Scaling: Setting `control_ha` to `3` or higher deploys a multi-master HA control plane using `kubeadm init --upload-certs` and joins secondary control planes with `--control-plane --certificate-key`.

### Provisioning Pipeline
All nodes are created natively via the LXD API, enlisted and commissioned in MAAS using LXD power drivers, and tagged with their roles (`kubernetes`, `control-plane`, `worker-node`). The pipeline deploys `control-plane-1` first, runs `kubeadm init` and installs Calico, extracts the join command, certificate key, and `kubeconfig` over SSH, and injects those tokens into the cloud-init payloads used to roll out the remaining control plane and worker nodes sequentially.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the *default* topology.
- CPU: 16 cores
- RAM: 38 GiB
- Disk: 210 GiB
- Network: Outbound internet access for LXD image downloads, MAAS image synchronization, and Kubernetes apt repositories

## Usage
Deploy this Transcript using the `se-polymerase` orchestrator. The orchestrator isolates all generated files into a dedicated `[DEPLOY_ID]` directory and automatically handles headless background execution.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth Kubernetes/kubeadm.yaml -y
```

Deploy using deb MAAS, prompt for all variables interactively, and assign a specific case number as the deployment ID:
```bash
./synth Kubernetes/kubeadm.yaml -d 00426900
```

Deploy bypassing prompts by passing a pre-generated configuration file from a previous run:
```bash
./synth Kubernetes/kubeadm.yaml -yc Kubernetes/00426900/config-kubeadm-00426900.yaml
```

### Configuration Files and "Dry Runs"
Every time you execute `synth` interactively, it automatically records your answers and generates a reusable YAML configuration file (e.g., `config-[PROJECT].yaml`). You can pass this file to the `-c` flag in future runs to perfectly replicate a specific environment without having to manually answer the prompts again.

#### How to perform a "Dry Run" (Generate a config without deploying):
If you want to build a configuration file to review, share, or edit *before* actually spinning up any resources, you can use `synth` as a configuration generator:

1. Run `synth` interactively (do **not** use the `-y` flag):
   ```bash
   ./synth Kubernetes/kubeadm.yaml
   ```
2. Answer all the prompts to configure your environment.
3. At the final resource confirmation prompt (`Proceed with deployment using these resources and networks? [y/N]:`), answer `n` to abort.
4. The script will catch the abort and ask: `Keep generated config file 'config-[PROJECT].yaml' for your next run? [y/N]:`. Answer `y`.

You now have a fully populated configuration file inside the generated deployment directory that you can safely tweak and deploy later using:
```bash
./synth Kubernetes/kubeadm.yaml -y -c Kubernetes/[DEPLOY_ID]/config-[PROJECT].yaml
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

The `kubeconfig` file is automatically fetched from the primary control plane node and configured for both `root` and the default system user on the MAAS controller. You can interact with your cluster immediately:
```bash
kubectl get nodes
kubectl get pods --all-namespaces
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
| `01-verify-deps` | Installs deb MAAS (if selected) and verifies core CLI dependencies (`lxc`, `jq`, `maas`, `kubectl`) |
| `02-maas-init` | Configures PostgreSQL, initializes MAAS, creates the admin user, and uploads SSH keys |
| `03-maas-networking` | Configures subnets, DHCP ranges, VLANs, spaces, and DNS settings in MAAS |
| `04-maas-images` | Triggers and monitors the synchronization of required OS boot images |
| `05-lxd-setup` | Establishes certificate trust between MAAS and the LXD provider |
| `06-vm-creation` | Provisions the empty control plane and worker virtual machines in LXD |
| `07-maas-enlist` | Boots the machines and monitors their automatic enlistment into MAAS |
| `08-maas-configure` | Assigns availability zones, hostnames, and LXD power controls |
| `09-maas-commission` | Triggers the commissioning phase and waits for hardware discovery |
| `10-maas-tagging` | Applies hardware tags (`kubernetes`, `control-plane`, `worker-node`) and configures flat storage layouts |
| `11-k8s-deploy-primary` | Deploys `control-plane-1` with `/opt/k8s-primary.yaml`, runs `kubeadm init`, and installs Calico CNI |
| `12-k8s-extract-tokens` | Extracts the `kubeadm` join command, certificate key, and `kubeconfig` from `control-plane-1` over SSH |
| `13-k8s-deploy-nodes` | Deploys and joins the remaining secondary control plane and worker nodes sequentially |

### Why is this useful?

If a deployment fails at step `13` due to a transient network or node join error, you **do not** need to destroy the lab and start over. Connect to the primary machine with `./synth shell <id>` (which automatically falls back to `lxc shell` if SSH is not up yet) and re-run the specific script:

```bash
ubuntu@maas-1:~$ 13-k8s-deploy-nodes
```

## Variables
When launching this Transcript, `synth` will parse the payload and optionally prompt for the following configuration values.

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| update_n_upgrade | True | Auto Update & Upgrade base packages |
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
| maas_images | noble jammy | Space separated list of Ubuntu releases to sync |
| maas_space | kubespace | Logical network space name mapped in MAAS |
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

