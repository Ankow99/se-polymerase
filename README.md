# se-polymerase 🧬

Polymerase is a zero-state, Terraform-free reproducer repository designed exclusively for Support Engineering. It houses the "Transcripts" (labs), parameterised Jinja2 `cloud-init.yaml` templates for complex OpenStack, Kubernetes, and MAAS + Juju support deployments.

At the core of the project is `synth`, a standalone LXD orchestrator that acts as the active enzyme. Instead of relying on Terraform, `synth` reads the reproducer's payload, prompts for required variables on the fly, provisions isolated LXD projects and networks, tracks the deployment in real time by tailing the logs, and generates a bespoke teardown script.

### Key Features

Workflow & Execution
* `Modular Execution` - Deployments are executed via modular, sequential scripts (`00-generate-env`, `01-verify-deps`, etc.) staged in `/usr/local/bin/`. If any step fails, you can SSH in and manually re-run the specific script to resume the deployment without starting from scratch.
* `Background Detachment` - Deployments are executed in the background. Press `Ctrl+C` at any time during the deployment phase to instantly drop back to your local terminal. You can easily reconnect to the live progress by tailing the saved log file.
* `Live Tracking` - Automatically records all deployment stdout/stderr to a `log-<project_name>.log` file and seamlessly transitions to a live juju status watch-loop.

State & Artifacts
* `Isolated Directories` - All generated artifacts (logs, certificates, teardown scripts, configurations, and access credentials) are cleanly consolidated into a unique deployment ID folder created right next to your payload.
* `Declarative Replication` - Saves the deployment state into a reusable `config-<project>.yaml` file inside the unique deployment folder, allowing 1:1 declarative environment replication without prompting.
* `Manifest Generation` - Generates an `access-<project_name>.txt` manifest containing all URLs, local-forwarding tunnels, passwords, and a final cluster IP inventory table.
* `Intelligent Teardown` - Generates a bespoke teardown script that wipes the LXD project, networks, and certificates, and finally attempts to cleanly delete the unique deployment folder if left empty.

Infrastructure & Provisioning
* `Dynamic Parsing` - Parses Jinja `cloud-config.yaml` payloads to dynamically calculate hardware requirements and generate interactive CLI prompts.
* `Host Optimization` - Supports nested LXD architectures or bare-metal LXD daemons, leveraging the host's LXD image cache by default to massively speed up VM provisioning.
* `Network Provisioning` - Provisions `ipv4.nat` bridges, calculates CIDR gateways, and validates DHCP settings to prevent collisions.
* `Credential Management` - Auto-injects local or Launchpad SSH keys and establishes secure SSH tunnels for dashboard port-forwarding.

---

## Available Labs

The repository is structured around various environments and reproducer templates. While the exact steps adapt to the payload, most MAAS-based labs share a standardized provisioning baseline. 

Current available labs include:

| Lab Template | Description | Core Technologies |
| :--- | :--- | :--- |
| `sunbeam` | Automated, scalable installation of Canonical Sunbeam (OpenStack) | MAAS, Juju, OpenStack |
| `openstack` | Highly available Charmed OpenStack deployment | MAAS, Juju, OpenStack |
| `kubeadm` | Scalable Kubernetes cluster deployed via `kubeadm` | MAAS, Kubernetes, containerd |
| `landscape` | High Availability Canonical Landscape deployment | MAAS, Juju, PostgreSQL, RabbitMQ |
| `juju` | Base environment for generalized Juju controller and node provisioning | MAAS, Juju |
| `maas` | Standalone, scalable MAAS provisioning environment | MAAS, PostgreSQL |
| `lxd` | Automated scalable cloud-init install of an LXD environment | LXD |
| `snapcraft` | Dedicated, isolated VM specifically tailored for Snap building | LXD, Snapcraft |

---

## Prerequisites

Ensure the following dependencies are installed on the host machine:
* `lxd`
* `jq`
* `openssl`
* `python3`

You must also have an SSH key pair generated before launching `synth`, as it requires one to establish the final SSH connection into the created lab. If you don't already have one, you can generate it using:

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

---

## Usage

Clone the repository to your local machine and `cd` into it:

```bash
git clone https://github.com/Ankow99/se-polymerase
cd se-polymerase
```

Invoke the script against a cloud-init template:

```bash
./synth [OPTIONS] <CLOUD_INIT_FILE> [DEPLOY_ID]
```

> **Note:** If this is your first time running `synth`, it may take a little longer to execute as it initializes LXD in the background.

### Arguments
| Argument | Description |
| :--- | :--- |
| `CLOUD_INIT_FILE` | (Required) Path to the `cloud-config.yaml` template. |
| `DEPLOY_ID` | (Optional) Custom alphanumeric deployment ID (max 8 characters). Defaults to a random 8-character hex string. |

### Options
| Flag | Description |
| :--- | :--- |
| `-h, --help` | Show the help menu. |
| `-y, --yes` | Bypass interactive CLI prompts and auto-accept all template defaults. |
| `-n, --nested` | Deploy using a nested LXD architecture. |
| `-d, --deb` | Force DEB packages for MAAS instead of the default snap. |
| `-i, --id <lp_id>` | Import SSH public keys directly from a Launchpad account. |
| `-I, --isolate-images` | Isolate LXD images per project (disables host image sharing). |
| `-c, --config <file>`| Load a pre-defined YAML configuration file to bypass prompts and replicate an environment. |

### Examples

Deploy interactively with a custom ID:
```bash
./synth Sunbeam/sunbeam.yaml 00426900
```

Deploy an automated cluster using deb MAAS and Launchpad keys:
```bash
./synth Openstack/focal-ussuri.yaml -y -d -i pgdg99
```

Redeploy a previous exact environment using a saved configuration file:
```bash
./synth Juju/juju.yaml -y -c Juju/b737170d/config-juju-b737170d.yaml
```

Run a fully automated background deployment (Start it, and press `Ctrl+C` to detach once the logs begin):
```bash
./synth Sunbeam/sunbeam.yaml -y
```

---

## Modular Deployments & Troubleshooting

A major feature of `se-polymerase` is its **modular execution**. Rather than deploying a massive, monolithic cloud-init runcmd, deployments are broken down into logical, sequentially numbered scripts executed inside the primary VM (found in `/usr/local/bin/`).

For most MAAS-based labs, steps `00` to `10` are highly standardized:

| Script | Description |
| :--- | :--- |
| `00-generate-env` | Calculates networking math and dynamic IP allocations. |
| `01-verify-deps` | Verifies and installs critical system packages. |
| `02-maas-init` | Sets up PostgreSQL and initializes the MAAS admin user. |
| `03-maas-networking` | Configures subnets, VLANs, gateway IPs, and DNS. |
| `04-maas-images` | Imports and syncs required Ubuntu boot resources. |
| `05-lxd-setup` | Configures LXD certificates, remotes, and project isolation. |
| `06-vm-creation` | Provisions empty VMs with calculated hardware allocations. |
| `07-maas-enlist` | Starts the newly created VMs to trigger PXE boot and enlistment. |
| `08-maas-configure` | Assigns Availability Zones, hostnames, and explicit power settings. |
| `09-maas-commission` | Commissions the discovered nodes. |
| `10-maas-tagging` | Injects tags for disks, roles, and logical network interfaces. |

### Why is this useful?

If a deployment fails at step `12` due to a transient network error or misconfiguration, you **do not** need to destroy the lab and start over. You can simply SSH into the primary machine and re-run the specific script:

```bash
ubuntu@maas-1:~$ 12-sunbeam-bootstrap
```

---

## Access & Dashboards

If `synth` detects that you are deploying over a remote SSH session, it will automatically calculate and provide the exact `ssh -L` port-forwarding commands required to access the internal dashboards (LXD, MAAS, OpenStack Horizon) securely from your local browser. 

Additionally, `synth` performs dynamic credential extraction:
* LXD UI: Automatically generates and displays a volatile trust token.
* OpenStack Horizon: Natively queries Juju (or the `sunbeam` snap) to extract the dashboard VIP, Domain, Username, and Admin Password.
* Cluster Inventory: Captures all node hostnames, states, and IPv4 addresses.

All of these credentials, URLs, and tunnel commands are safely appended to an `access-<project_name>.txt` file generated in the project directory, ensuring you don't lose them if your terminal buffer clears.

---

## Cleanup

`synth` generates a `destroy-<project_name>.sh` file in the same directory as the payload. 

Execute this script to wipe the LXD project, stop and delete instances, un-trust volatile certificates, remove the access manifest and logs, and clean up the associated dynamic networks.

```bash
./Juju/b737170d/destroy-juju-b737170d.sh
```

> **Note:** The cleanup script will safely self-delete and attempt to remove its parent project directory. It will deliberately leave the directory intact if you choose to keep your `config-<project_name>.yaml` file for future redeployments.

---

## Building Payloads to use with Synth

`synth` parses standard Jinja comments to generate the CLI wizard. Format your `cloud-init.yaml` variables using the following standards:

### Standard Variables
Add a `# PROMPT: <Text>` comment after a Jinja variable to trigger the interactive UI.
```jinja
{% set custom_sys_user = "ubuntu" %}                # PROMPT:System User
{% set custom_juju_channel = "3.6/stable" %}        # PROMPT:Juju Channel
```

### Hardware Allocation
Use the suffixes `_cpu`, `_ram`, `_disk`, and `_ha` to enable `synth` to automatically calculate host resource capacity.
```jinja
{% set custom_juju_ha = 1 %}                        # PROMPT:Number of Juju Controllers
{% set custom_juju_cpu = "3" %}                     # PROMPT:Juju Controller CPU cores
{% set custom_juju_ram = "6GiB" %}                  # PROMPT:Juju Controller RAM
{% set custom_juju_disk = "30GiB" %}                # PROMPT:Juju Controller Root Disk
```

### Dynamic Networking
Use the `[BRIDGE:dhcp=<true/false>,cidr=<var_name>]` tag to instruct synth to provision an isolated LXD network.
```jinja
{% set custom_maas_bridge = "mbr0" %}               # PROMPT:MAAS Bridge Name [BRIDGE:dhcp=false,cidr=maas_cidr]
{% set custom_maas_cidr = "10.10.0.0/22" %}
```

### Juju Trigger
Define the string that signals the end of normal `cloud-init-output.log` tailing and the start of the Juju deployment so it switches to a Juju status watch:
```jinja
{% set custom_juju_trigger = "-------- Bootstrapping Juju Controller... --------" %}
```
