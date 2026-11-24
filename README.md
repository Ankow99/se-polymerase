# Polymerase 🧬

Polymerase is a zero-state, Terraform-free reproducer repository designed for reproducing client environments. It houses the "Transcripts" (labs), parameterised Jinja2 `cloud-init.yaml` templates for complex OpenStack, Kubernetes, and MAAS + Juju cloud deployments.

At the core of the project is `synth`, a standalone LXD orchestrator that acts as the active enzyme. Instead of relying on Terraform, `synth` reads the reproducer's payload, prompts for required variables on the fly, provisions isolated LXD projects and networks, tracks the deployment in real time, and manages the entire lab lifecycle natively using LXD project metadata.

### Key Features

Workflow & Execution
- **Modular Execution:**<br>
  Deployments are executed via modular, sequential scripts (`00-generate-env`, `01-verify-deps`, etc.) staged in `/usr/local/bin/`. If any step fails, you can connect with `synth shell <id>` and manually re-run the specific script to resume the deployment without starting from scratch.
- **Background Detachment:**<br>
  Deployments run in the background. Press `Ctrl+C` at any time during the deployment phase to instantly drop back to your local terminal, and re-attach to live progress anytime with `synth monitor <id>`.
- **Live Tracking:**<br>
  Automatically records all deployment stdout/stderr to a `log-<project_name>.log` file and seamlessly transitions to a live Juju status watch-loop.
- **LXD-Native Lab Management:**<br>
  Tracks all deployed labs directly inside LXD project metadata (`user.synth.*`), providing `list`, `monitor`, `shell`, `info`, and `destroy` subcommands with persistent numeric IDs and Bash tab-completion.

State & Artifacts
- **Isolated Directories:**<br>
  All generated artifacts (logs, certificates, configurations, and access credentials) are cleanly consolidated into a unique deployment ID folder created right next to your payload.
- **Declarative Replication:**<br>
  Saves the deployment state into a reusable `config-<project>.yaml` file inside the unique deployment folder, allowing 1:1 declarative environment replication without prompting.
- **Manifest Generation:**<br>
  Generates an `access-<project_name>.txt` manifest containing all URLs, local-forwarding tunnels, passwords, and a final cluster IP inventory table, viewable from anywhere via `synth info <id>`.
- **Built-In Teardown:**<br>
  `synth destroy <id>` safely terminates any active background worker, wipes the LXD project, instances, volumes, dynamic bridges, DNS records, volatile certificates, and logs, while preserving your `config-<project>.yaml` unless `-a`/`--all` is passed.

Infrastructure & Provisioning
- **Automated Host Bootstrapping:**<br>
  Automatically detects missing host dependencies (`lxd`, `jq`, `openssl`) and initializes an LXD storage pool using a configurable backend (`dir` by default, or `zfs`/`lvm` based on spare disk availability).
- **Dynamic Parsing:**<br>
  Parses Jinja `cloud-config.yaml` payloads to dynamically calculate hardware requirements and generate interactive CLI prompts.
- **Host Optimization:**<br>
  Supports nested LXD architectures or bare-metal LXD daemons, leveraging the host's LXD image cache by default to massively speed up VM provisioning.
- **Network Provisioning:**<br>
  Provisions `ipv4.nat` bridges, calculates CIDR gateways, and validates DHCP settings to prevent collisions.
- **Credential Management:**<br>
  Auto-injects local or Launchpad SSH keys and establishes secure SSH tunnels for dashboard port-forwarding.
- **Custom Manifests:**<br>
  Supports injecting custom Sunbeam `manifest.yaml` files directly via CLI flags to override deployment defaults.
- **Smart SSH Detection:**<br>
  Automatically extracts keys from your local `ssh-agent` if standard identity files aren't found, or interactively generates a new Ed25519 pair on the fly if you have none.
- **Predictable Port Mapping:**<br>
  Dynamically calculates collision-free, high-range local ports for remote dashboard SSH tunnels based on your unique deployment ID.

---

## Available Labs

The repository is structured around various environments and reproducer templates. While the exact steps adapt to the payload, most MAAS-based labs share a standardized provisioning baseline.

Current available labs include:

| Lab&nbsp;Template | Description | Core Technologies |
| :--- | :--- | :--- |
| <code>sunbeam</code> | Automated, scalable installation of Canonical Sunbeam (OpenStack) | MAAS, Juju, OpenStack |
| <code>openstack</code> | Highly available Charmed OpenStack deployment | MAAS, Juju, OpenStack |
| <code>devstack</code> | Single-node DevStack OpenStack environment with optional service plugins (Skyline, Octavia, Heat, etc.) | OpenStack, DevStack |
| <code>kubeadm</code> | Scalable Kubernetes cluster deployed via `kubeadm` | MAAS, Kubernetes |
| <code>landscape</code> | High Availability Canonical Landscape deployment | MAAS, Juju |
| <code>juju</code> | Base environment for generalized Juju controller and node provisioning | MAAS, Juju |
| <code>maas</code> | Standalone, scalable MAAS provisioning environment | MAAS |
| <code>lxd</code> | Automated scalable cloud-init install of an LXD environment | LXD |
| <code>snapcraft</code> | Dedicated, isolated VM specifically tailored for Snap building | LXD, Snapcraft |
| <code>simple&#8209;example</code> | Simple example of a simple payload | LXD |

---

## Prerequisites

While Polymerase is designed to work best on a clean, dedicated Ubuntu host (such as a fresh Testflinger node), a pristine machine is **not** strictly required. `synth` will automatically bootstrap a clean host by installing missing dependencies and securely initializing an LXD storage pool out of the box, while remaining fully capable of adapting to existing host configurations.

Even though `synth` auto-installs missing dependencies, the following are required on the host:

- `lxd` (snap)
- `jq`
- `openssl`
- `lvm2` or `zfsutils-linux` (optional, if using `lvm` or `zfs` storage backends)
- An SSH key pair (detected from `~/.ssh/` or `ssh-agent`, or auto-generated on the fly)

> **Storage Backend Selection:** By default, `synth` initializes LXD using the directory (`dir`) backend for maximum stability across environments. You can customize the preferred storage drivers at the top of the `synth` script via `LXD_SPARE_DRIVER` (used when an unpartitioned block device >= 500 GiB is detected) and `LXD_NON_SPARE_DRIVER` (fallback when no spare disk is available), supporting `"dir"`, `"zfs"`, or `"lvm"`.

---

## Usage

Clone the repository to your local machine and `cd` into it:

```bash
git clone https://github.com/Ankow99/se-polymerase
cd se-polymerase
```

Deploy a new environment or manage existing ones:

```bash
./synth [OPTIONS] <CLOUD_INIT_FILE> [DEPLOY_ID]
./synth <COMMAND> [ARGS]
```

> **Note:** If this is your first time running `synth` on a new host, it will prompt you to install dependencies and initialize LXD's storage pool using your configured backend (defaults to `dir`). Each lab must use a dedicated LXD project (the `default` project is prohibited).

### Deployment Arguments
| Argument | Description |
| :--- | :--- |
| `CLOUD_INIT_FILE` | (Required) Path to the `cloud-config.yaml` template. |
| `DEPLOY_ID` | (Optional) Custom alphanumeric deployment ID (max 8 characters). Defaults to a random 8-character hex string. |

### Deployment Options
| Flag | Description |
| :--- | :--- |
| `-h, --help` | Show the help menu. |
| `-y, --yes` | Bypass interactive CLI prompts and auto-accept all template defaults. |
| `-n, --nested` | Deploy using a nested LXD architecture. |
| `-d, --deb` | Force DEB packages for MAAS instead of the default snap. |
| `-i, --id <user_id>` | Import SSH public keys from trusted online identities (`lp:`, `gh:`, `gl:`). |
| `-I, --isolate-images` | Isolate LXD images per project (disables host image sharing). |
| `-c, --config <file>` | Load a pre-defined YAML configuration file to bypass prompts and replicate an environment. |
| `-m, --manifest <file>` | Provide a custom deployment manifest (e.g., Sunbeam `manifest.yaml`) to override the default. |

### Deployment Examples

Deploy interactively with a custom ID:
```bash
./synth Sunbeam/sunbeam.yaml 00426900
```

Deploy an automated cluster using deb MAAS and Launchpad keys:
```bash
./synth Openstack/focal-ussuri.yaml -y -d -i lp:pgdg99
```

Redeploy a previous exact environment using a saved configuration file:
```bash
./synth Juju/juju.yaml -y -c Juju/b737170d/config-juju-b737170d.yaml
```

Run a fully automated background deployment (start it, and press `Ctrl+C` to detach once the logs begin):
```bash
./synth Sunbeam/sunbeam.yaml -y
```

Deploy an environment injecting a custom deployment manifest (only available for the Sunbeam lab):
```bash
./synth Sunbeam/sunbeam.yaml -m custom-manifest.yaml
```

---

## Management Commands

Every lab deployed by `synth` is assigned a persistent numeric ID (`1`, `2`, `3`, ...) and can be targeted by its numeric ID, its 8-character deploy ID, or its full LXD project name. Run `./synth <COMMAND> --help` for command-specific options.

| Command | Aliases | Description |
| :--- | :--- | :--- |
| <code>list</code> | <code>ls</code> | List all managed labs in an auto-resizing table with IDs, primary VM IPs, and color-coded status (`deploying`, `deployed`, `failed`). |
| <code>monitor&nbsp;&lt;id&#124;name&gt;</code> | <code>logs</code>,&nbsp;<code>log</code> | Tail the last 10 lines of a lab's deployment log and stream live while deploying. Supports `-n`/`--lines <N>` and `-a`/`--all`. |
| <code>shell&nbsp;&lt;id&#124;name&gt;</code> | <code>connect</code>,&nbsp;<code>ssh</code> | Connect to a lab's primary VM via SSH. Automatically falls back to `lxc shell` if the VM has no IP yet or SSH is unreachable. |
| <code>info&nbsp;&lt;id&#124;name&gt;</code> | - | Display access details, SSH commands, port-forwarding tunnels, dashboard credentials, and log/config file paths. |
| <code>destroy&nbsp;&lt;id&#124;name&gt;</code> | <code>rm</code>,&nbsp;<code>delete</code> | Tear down a lab and clean up all LXD projects, instances, volumes, bridges, DNS records, certificates, and logs. Supports `-y`/`--yes` and `-a`/`--all`. |
| <code>completion&nbsp;[bash&#124;install]</code> | - | Print or install Bash tab-completion for `synth` commands, flags, YAML templates, and live lab IDs. |

### Management Examples

List all deployed labs and their current status (using `list` or its `ls` alias):
```bash
./synth list
./synth ls
```

Monitor live deployment logs by numeric ID, or tail the last 50 lines and continue streaming using the `logs` alias and unique deploy ID:
```bash
./synth monitor 1
./synth logs 00426900 -n 50
```

Connect to a lab's primary VM via SSH using its numeric ID, or use the `ssh` alias with its unique deploy ID:
```bash
./synth shell 1
./synth ssh 00426900
```

View access details, tunnels, and credentials by numeric ID or full project name:
```bash
./synth info 1
./synth info sunbeam-00426900
```

Destroy a lab interactively by numeric ID, or use the `rm` alias to skip confirmation and remove its saved config file:
```bash
./synth destroy 1
./synth rm 00426900 -ya
```

### Tab Completion

Install Bash autocomplete for `synth` with:
```bash
./synth completion install
```

To use `synth` from any directory, symlink it into your `$PATH` and reload your shell:
```bash
sudo ln -sf "$(realpath ./synth)" /usr/local/bin/synth
exec bash
```

---

## Access & Dashboards

If `synth` detects that you are deploying over a remote SSH session, it will automatically calculate and provide the exact `ssh -L` port-forwarding commands required to access the internal dashboards (LXD, MAAS, OpenStack Horizon) securely from your local browser.

Additionally, `synth` performs dynamic credential extraction:
- LXD UI: Automatically generates and displays a volatile trust token.
- OpenStack Horizon: Natively queries Juju (or the `sunbeam` snap) to extract the dashboard VIP, Domain, Username, and Admin Password.
- Cluster Inventory: Captures all node hostnames, states, and IPv4 addresses.

All of these credentials, URLs, and tunnel commands are saved to `access-<project_name>.txt` in the project directory and can be displayed at any time with:

```bash
./synth info 1
```

---

## Cleanup

Use `synth destroy` with the lab's numeric ID, deploy ID, or project name to terminate any active background worker and wipe the LXD project, instances, custom volumes, volatile certificates, access manifest, logs, and dynamic networks:

```bash
./synth destroy 1
```

Skip confirmation and also remove the saved `config-<project_name>.yaml` file (which allows `synth` to delete the empty project directory):

```bash
./synth destroy 1 -ya
```

> **Note:** By default, `synth destroy` preserves your `config-<project_name>.yaml` file so you can replicate the environment later with `-c`. Pass `-a` / `--all` to remove it as well.

---

## Modular Deployments & Troubleshooting

A major feature of `se-polymerase` is its **modular execution**. Rather than deploying a massive, monolithic cloud-init runcmd, deployments are broken down into logical, sequentially numbered scripts executed inside the primary VM (found in `/usr/local/bin/`).

For most MAAS-based labs, steps `00` to `10` are highly standardized:

| Script | Description |
| :--- | :--- |
| `00-generate-env` | Initializes the persistent state file `/etc/repro-env` and calculates dynamic IP allocations |
| `01-verify-deps` | Installs and verifies core dependencies like LXD, MAAS, and Sunbeam |
| `02-maas-init` | Configures the database, initializes MAAS, and creates the admin user |
| `03-maas-networking` | Configures subnets, DHCP ranges, VLANs, and DNS settings in MAAS |
| `04-maas-images` | Triggers and monitors the synchronization of required OS boot images |
| `05-lxd-setup` | Establishes certificate trust between MAAS and the LXD provider |
| `06-vm-creation` | Provisions the virtual machines and attaches custom storage/network devices |
| `07-maas-enlist` | Boots the machines and monitors their automatic enlistment into MAAS |
| `08-maas-configure` | Assigns availability zones, hostnames, and LXD power controls |
| `09-maas-commission` | Triggers the commissioning phase and waits for hardware discovery |
| `10-maas-tagging` | Applies hardware tags, configures storage layouts, and tags interfaces |

### Why is this useful?

If a deployment fails at step `12` due to a transient network error or misconfiguration, you **do not** need to destroy the lab and start over. You can connect directly to the primary machine with `./synth shell <id>` (which automatically falls back to `lxc shell` if SSH isn't up yet) and re-run the specific script:

```bash
ubuntu@maas-1:~$ 12-sunbeam-bootstrap
```

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
Use the `[BRIDGE:dhcp=<true/false>,cidr=<var_name>]` tag to instruct `synth` to provision an isolated LXD network.
```jinja
{% set custom_maas_bridge = "mbr0" %}               # PROMPT:MAAS Bridge Name [BRIDGE:dhcp=false,cidr=maas_cidr]
{% set custom_maas_cidr = "10.10.0.0/22" %}
```

### Juju Trigger
Define the string that signals the end of normal `cloud-init-output.log` tailing and the start of the Juju deployment so it switches to a Juju status watch:
```jinja
{% set custom_juju_trigger = "-------- Bootstrapping Juju Controller... --------" %}
```
