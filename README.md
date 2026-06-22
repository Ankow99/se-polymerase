# se-polymerase 🧬

Polymerase is a zero-state, Terraform-free reproducer repository designed exclusively for Support Engineering. It houses the "Transcripts" (labs), parameterised Jinja2 `cloud-init.yaml` templates for complex OpenStack, Kubernetes, and MAAS + Juju support deployments.

At the core of the project is `synth`, a standalone LXD orchestrator that acts as the active enzyme. Instead of relying on Terraform, `synth` reads the reproducer's payload, prompts for required variables on the fly, provisions isolated LXD projects and networks, tracks the deployment in real time by tailing the logs, and generates a bespoke teardown script.

### Key Features
* Parses Jinja `cloud-config.yaml` payloads to dynamically calculate hardware requirements and generate interactive CLI prompts.
* Supports nested LXD architectures or bare-metal LXD daemons.
* Provisions `ipv4.nat` bridges, calculates CIDR gateways, and validates DHCP settings to prevent collisions.
* Auto-injects local or Launchpad SSH keys and establishes secure SSH tunnel for dashboard port-forwarding.
* Generates an `access-<project_name>.txt` manifest containing all URLs, local-forwarding tunnels, and passwords.
* Tails `cloud-init` logs and seamlessly transitions to a live juju status watch-loop.
* Supports a detached `--headless` mode for asynchronous background deployments and execution logging.
* Generates a project-specific teardown script to destroy the LXD project, un-trust certificates, and remove dynamic networks.

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
| `-a, --accept-defaults` | Bypass interactive CLI prompts and auto-accept all template defaults. |
| `-n, --nested` | Deploy using a nested LXD architecture. |
| `-d, --deb` | Force DEB packages for MAAS instead of the default snap. |
| `-i, --id <lp_id>` | Import SSH public keys directly from a Launchpad account. |
| `--headless` | Run `synth` in the background, auto-accept all defaults, and redirect output to a `synth-<project_name>.log` file. |

### Examples

Deploy interactively with a custom ID:
```bash
./synth Sunbeam/sunbeam.yaml 00426900
```

Deploy an automated cluster using deb MAAS and Launchpad keys:
```bash
./synth -a -d -i pgdg99 Openstack/focal-ussuri.yaml
```

Deploy headless in the background (output is redirected to `synth-<project_name>.log`):
```bash
./synth Sunbeam/sunbeam.yaml --headless
```

---

## Access & Dashboards

If `synth` detects that you are deploying over a remote SSH session, it will automatically calculate and provide the exact `ssh -L` port-forwarding commands required to access the internal dashboards (LXD, MAAS, OpenStack Horizon) securely from your local browser. 

Additionally, `synth` performs dynamic credential extraction:
* LXD UI: Automatically generates and displays a volatile trust token.
* OpenStack Horizon: Natively queries Juju (or the `sunbeam` snap) to extract the dashboard VIP, Domain, Username, and Admin Password.

All of these credentials, URLs, and tunnel commands are safely appended to an `access-<project_name>.txt` file generated in the same directory as your payload, ensuring you don't lose them if your terminal buffer clears.

---

## Cleanup

`synth` generates a `destroy-<project_name>.sh` file in the same directory as the payload. 

Execute this script to wipe the LXD project, stop and delete instances, un-trust volatile certificates, remove the access manifest, and clean up the associated dynamic networks.

```bash
./destroy-maas-00436900.sh
```

---

## Building Payloads

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
