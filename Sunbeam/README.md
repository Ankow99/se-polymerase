# Transcript: Sunbeam

## Description
A fully automated, scalable OpenStack environment deployed via Canonical Sunbeam on top of MAAS. This Transcript synthesizes a primary MAAS controller, provisions a fleet of LXD virtual machines, enlists them as bare-metal nodes, and executes the Sunbeam cluster bootstrap and deployment processes. It serves as a comprehensive reproducer for Canonical OpenStack architectures deployed using Sunbeam.

## Requirements
To successfully synthesize this environment, your host machine must meet the following minimum specifications using the *default* topology.
* CPU: 22 cores
* RAM: 60 GiB
* Disk: 310 GiB
* Network: Outbound internet access for LXD image downloads, MAAS image synchronization, and Sunbeam snap installations

## Variables
When launching this Transcript, `synth` will parse the payload and optionally prompt for the following configuration values.

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| update_n_upgrade | True | Auto Update & Upgrade base packages |
| auto_retry | True | Auto-retry once on Sunbeam deployment timeouts |
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
| lxd_project | default | Target LXD project for the deployment |
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
| os_run_demo | True | Run the Sunbeam demo user setup |
| os_neutron_bridge | nbr0 | Name of the dedicated Neutron network bridge |
| os_neutron_cidr | 10.20.0.0/22 | Subnet CIDR for the OpenStack provider network |
| os_pub_api_ip_count | 50 | Number of IPs to reserve for the OpenStack Public API |
| os_int_api_ip_count | 50 | Number of IPs to reserve for the OpenStack Internal API |
| os_pub_api_hostname | public | OpenStack Public API Hostname |
| os_int_api_hostname | internal | OpenStack Internal API Hostname |
| os_rgw_api_hostname | rgw | OpenStack RGW API Hostname |
| os_add_vault | False | Enable Vault |
| os_add_tls | False | Enable TLS Endpoints |
| os_add_barbican | False | Enable Barbican |
| os_add_octavia | False | Enable Octavia |
| os_add_amphora | False | Enable Octavia Amphora |
| os_add_masakari | False | Enable Masakari |
| os_add_heat | False | Enable Heat |
| os_add_designate | False | Enable Designate |
| os_add_magnum | False | Enable Magnum |
| os_add_ldap | False | Enable LDAP |
| os_add_images | False | Enable Images Sync |
| os_add_watcher | False | Enable Watcher |
| os_add_maintenance | False | Enable Maintenance Mode |
| os_add_telemetry | False | Enable Ceilometer/Aodh |
| os_add_manila | False | Enable Manila |
| os_add_tempest | False | Enable Tempest |
| os_add_cos | False | Enable Observability Stack |
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

## Additional Features
This Transcript supports enabling optional Sunbeam features during step `15-sunbeam-addons`. Enabling certain addons will automatically cascade and activate their prerequisite dependencies (for example, `os_add_amphora` automatically enables `os_add_tls`, `os_add_octavia`, `os_add_barbican`, and `os_add_vault`).

| Addon Variable | Sunbeam Feature | Description & Sizing Notes |
| :--- | :--- | :--- |
| `os_add_vault` | `vault` | Deploys HashiCorp Vault for secret storage and certificate management. Automatically initializes, unseals, and authorizes the charm |
| `os_add_tls` | `tls` | Enables TLS encryption on public, internal, and RGW endpoints. Uses Vault as an intermediate CA if `os_add_vault` is enabled; otherwise falls back to self-signed certificates |
| `os_add_barbican` | `secrets` | Deploys OpenStack Barbican for key and secret management. Automatically enables `os_add_vault` |
| `os_add_octavia` | `loadbalancer` | Deploys OpenStack Octavia for Load Balancer as a Service (LBaaS). Automatically enables `os_add_barbican` and `os_add_vault` |
| `os_add_amphora` | `loadbalancer` (Amphora) | Enables the Octavia Amphora provider along with MicroOVN SDN feature gates and automated Amphora certificate signing. Automatically enables `os_add_octavia`, `os_add_tls`, `os_add_barbican`, and `os_add_vault` |
| `os_add_masakari` | `instance-recovery` | Deploys OpenStack Masakari for automated compute instance high availability and recovery. |
| `os_add_heat` | `orchestration` | Deploys OpenStack Heat for template-based cloud orchestration |
| `os_add_designate` | `dns` | Deploys OpenStack Designate for DNS as a Service, configured with `ns1.<tld>.` |
| `os_add_magnum` | `caas` | Deploys OpenStack Magnum for Container Infrastructure Management (Kubernetes clusters). Automatically enables `os_add_octavia`, `os_add_barbican`, and `os_add_vault` |
| `os_add_ldap` | `ldap` | Enables external LDAP authentication integration for Keystone |
| `os_add_images` | `images-sync` | Enables automated Glance cloud image synchronization |
| `os_add_watcher` | `resource-optimization` | Deploys OpenStack Watcher for cluster resource optimization and workload rebalancing |
| `os_add_telemetry` | `telemetry` | Deploys the OpenStack Telemetry and metering stack (Ceilometer, Gnocchi, and Aodh) |
| `os_add_manila` | `shared-filesystem` | Deploys OpenStack Manila for Shared File Systems as a Service (enables the `feature.shared-filesystem` snap gate) |
| `os_add_maintenance` | `maintenance` | Enables host maintenance mode capabilities (enables the `feature.maintenance` snap gate) |
| `os_add_tempest` | `validation` | Deploys OpenStack Tempest for automated cloud validation and RefStack testing |
| `os_add_cos` | `observability embedded` | Deploys the embedded Canonical Observability Stack (Prometheus, Loki, Grafana, Alertmanager, and Traefik). **Sizing requirement:** Allocate at least **`150GiB`+ on `cloud_disk`** per cloud node |

## Usage
Deploy this Transcript using the `se-polymerase` orchestrator. The orchestrator isolates all generated files into a dedicated `[DEPLOY_ID]` directory and automatically handles headless background execution.

Accept all default variables and let `synth` auto-generate a deployment ID:
```bash
./synth Sunbeam/sunbeam.yaml -y
```

Deploy using deb MAAS, prompt for all variables interactively, and assign a specific case number as the deployment ID:
```bash
./synth Sunbeam/sunbeam.yaml -d 00426900
```

Deploy bypassing prompts by passing a pre-generated configuration file from a previous run:
```bash
./synth Sunbeam/sunbeam.yaml -c Sunbeam/00426900/config-sunbeam-00426900.yaml
```

Deploy using a custom Sunbeam manifest file to override the default cloud generation (it is the user's responsibility to ensure this manifest works - not recommended):
```bash
./synth Sunbeam/sunbeam.yaml -m custom-manifest.yaml
```

### Configuration Files and "Dry Runs"
Every time you execute `synth` interactively, it automatically records your answers and generates a reusable YAML configuration file (e.g., `config-[PROJECT].yaml`). You can pass this file to the `-c` flag in future runs to perfectly replicate a specific environment without having to manually answer the prompts again.

#### How to perform a "Dry Run" (Generate a config without deploying):
If you want to build a configuration file to review, share, or edit *before* actually spinning up any resources, you can use `synth` as a configuration generator:

1. Run `synth` interactively (do **not** use the `-y` flag):
   ```bash
   ./synth Sunbeam/sunbeam.yaml
   ```
2. Answer all the prompts to configure your environment.
3. At the final resource confirmation prompt (`Proceed with deployment using these resources and networks? [y/N]:`), answer `n` to abort.
4. The script will catch the abort and ask: `Keep generated config file 'config-[PROJECT].yaml' for your next run? [y/N]:`. Answer `y`.

You now have a fully populated configuration file inside the generated deployment directory that you can safely tweak and deploy later using:
```bash
./synth Sunbeam/sunbeam.yaml -y -c Sunbeam/[DEPLOY_ID]/config-[PROJECT].yaml
```

## Testflinger Machine Templates
Pre-configured YAML templates for Canonical Testflinger bare-metal machines are located in `Sunbeam/templates/`. Each template shares the exact name of its target Testflinger host (e.g., `hoodin.yaml` for `hoodin`) and is tailored to that machine's hardware envelope.

Because Testflinger machines vary significantly in CPU, RAM, and local storage, **larger machines can run the full addon suite (including COS) in full HA, whereas smaller or disk-constrained machines only support a subset of addons** without exhausting host RAM or disk space.

### Host Capacity & Sizing Notes

| Template / Machine | Host Capacity (`CPU` / `RAM` / `Disk`) | Template Footprint | Addon Capacity & Notes |
| :--- | :--- | :--- | :--- |
| `aitken.yaml` (`aitken`) | `96c` / `126 GiB` / `~822 GiB` | `48c` / `112 GiB` / `640 GiB` | **Partial addons (no COS):** Constrained by `126 GiB` RAM and `~822 GiB` disk. Runs core addons (Vault, Barbican, Octavia, Masakari, Tempest) with `100GiB` cloud root disks. |
| `oogtar.yaml` (`oogtar`) | `256c` / `126 GiB` / `~894 GiB` | `90c` / `112 GiB` / `700 GiB` | **Partial addons (no COS):** High core count, but constrained by `126 GiB` RAM and `~894 GiB` disk. Runs Vault, TLS, Barbican, Octavia, Masakari, and Tempest; lacks disk headroom for COS without shrinking OSD allocations. |
| `tabuu.yaml` (`tabuu`) | `32c` / `251 GiB` / `~823 GiB` | `30c` / `216 GiB` / `700 GiB` | **Most addons (14/17, no COS):** High RAM supports most OpenStack services, but `32` cores and `~823 GiB` disk (`100GiB` `cloud_disk`) exclude COS, Masakari, and Designate. |
| `megatron.yaml` (`megatron`) | `128c` / `125 GiB` / `~3330 GiB` | `78c` / `112 GiB` / `1630 GiB` | **Multi-addon + COS (storage-heavy):** Massive `~3.3 TB` disk allows `200GiB` cloud root disks + `6` OSDs/node to run COS alongside core addons, while omitting RAM-heavy addons (Amphora, Magnum, Telemetry, Watcher) to fit `125 GiB` RAM. |
| `hoodin.yaml` (`hoodin`) | `384c` / `250 GiB` / `~1378 GiB` | `122c` / `224 GiB` / `1120 GiB` | **Full addon suite (17/17):** High core count and `200GiB` cloud root disks support full HA controllers and every addon simultaneously, including COS. |
| `rockman.yaml` (`rockman`) | `128c` / `503 GiB` / `~1380 GiB` | `116c` / `396 GiB` / `1240 GiB` | **Full addon suite (17/17, 5-node cloud):** `503 GiB` RAM supports a scaled 5-node cloud / 5-Sunbeam HA topology (`170GiB` `cloud_disk`, `1` OSD/node) with all addons enabled. |
| `buzzar.yaml` (`buzzar`) | `104c` / `378 GiB` / `~2773 GiB` | `95c` / `236 GiB` / `2320 GiB` | **Full addon suite (17/17, max storage):** Abundant RAM and `~2.77 TB` disk support full HA controllers, `500GiB` cloud root disks, `100GiB` OSDs, and all addons simultaneously. |

### Template Topology & Setup Matrix

| Machine | MAAS (`CPU/RAM/Disk`) | Juju (`HA x CPU/RAM/Disk`) | Sunbeam (`HA x CPU/RAM/Disk`) | Cloud Nodes (`HA x CPU/RAM/Disk`) | Ceph OSDs (per Cloud Node) | Enabled Addons |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `aitken` | `4c / 8GiB / 40GiB` | `1x (4c / 4GiB / 30GiB)` | `1x (4c / 4GiB / 30GiB)` | `3x (12c / 32GiB / 100GiB)` | `2x 40GiB` | Vault, Barbican, Octavia, Masakari, Tempest |
| `oogtar` | `8c / 8GiB / 40GiB` | `1x (8c / 4GiB / 30GiB)` | `1x (8c / 4GiB / 30GiB)` | `3x (22c / 32GiB / 100GiB)` | `2x 50GiB` | Vault, TLS, Barbican, Octavia, Masakari, Tempest |
| `tabuu` | `2c / 8GiB / 40GiB` | `1x (2c / 8GiB / 30GiB)` | `1x (2c / 8GiB / 30GiB)` | `3x (8c / 64GiB / 100GiB)` | `2x 50GiB` | All except Masakari, Designate, COS |
| `megatron` | `6c / 8GiB / 50GiB` | `1x (6c / 4GiB / 40GiB)` | `1x (6c / 4GiB / 40GiB)` | `3x (20c / 32GiB / 200GiB)` | `6x 50GiB` | Vault, TLS, Barbican, Octavia, Masakari, Tempest, **COS** |
| `hoodin` | `8c / 8GiB / 40GiB` | `3x (8c / 6GiB / 30GiB)` | `3x (8c / 6GiB / 30GiB)` | `3x (22c / 60GiB / 200GiB)` | `2x 50GiB` | **All 17 addons (incl. COS)** |
| `rockman` | `4c / 12GiB / 30GiB` | `3x (4c / 8GiB / 20GiB)` | `5x (4c / 8GiB / 20GiB)` | `5x (16c / 64GiB / 170GiB)` | `1x 40GiB` | **All 17 addons (incl. COS)** |
| `buzzar` | `5c / 8GiB / 40GiB` | `3x (5c / 6GiB / 30GiB)` | `3x (5c / 6GiB / 30GiB)` | `3x (20c / 64GiB / 500GiB)` | `2x 100GiB` | **All 17 addons (incl. COS)** |

To deploy directly on a matching Testflinger machine using its template:
```bash
./synth Sunbeam/sunbeam.yaml -c Sunbeam/templates/hoodin.yaml
```
*(Note: `Sunbeam/templates/example.yaml` is also available as a default-values baseline if you want to build a custom configuration from scratch.)*

## Access and Cleanup
Because the deployment is executed in the background, you can detach your terminal at any time. Monitor the live progress by tailing the log file stored in the deployment directory:
```bash
tail -f Sunbeam/00426900/log-sunbeam-00426900.log
```

Once the payload finishes executing, `synth` will automatically drop you into a secure multiplexed SSH shell connected to the primary MAAS controller. You can also view all SSH tunneling commands and dashboard URLs in the generated `access-[PROJECT].txt` file.

OpenStack credentials are automatically generated in your user directory. The `admin-openrc` file is automatically sourced at login. You can interact with the OpenStack CLI and manage the newly deployed cloud:
```bash
openstack server list
```
Note: If `os_run_demo` is enabled, a `demo-openrc` file will also be available for testing isolated tenant workflows.

To completely wipe this environment and release its resources, execute the auto-generated teardown script located in the deployment directory:
```bash
./Sunbeam/00426900/destroy-sunbeam-00426900.sh
```

## Modular Execution and Recovery
To make debugging and recovery effortless, the entire cloud-init deployment pipeline is broken down into discrete, numbered executable scripts located in `/usr/local/bin/` on the primary MAAS controller. 

If a specific phase of the deployment fails or times out, you do not need to destroy the environment and start over. Simply SSH into the primary controller and execute the failed step manually to retry it. Every script automatically escalates privileges and sources the `/etc/repro-env` state file, ensuring it has all the correct environment variables and dynamically calculated IPs needed to resume the deployment exactly where it left off.

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
| `11-sunbeam-prep` | Prepares the nodes, adds the MAAS provider, and validates the space |
| `12-sunbeam-bootstrap` | Generates the deployment manifest and bootstraps the Juju controller |
| `13-sunbeam-deploy` | Executes the main Sunbeam cluster deployment for the OpenStack services |
| `14-sunbeam-configure` | Runs post-deployment cloud configuration and generates user credentials |
| `15-sunbeam-addons` | Activates and configures all requested optional addons (Vault, Octavia, etc.) |

### Why is this useful?

If a deployment fails at step `12` due to a transient network error or misconfiguration, you **do not** need to destroy the lab and start over. You can simply SSH into the primary machine and re-run the specific script:

```bash
ubuntu@maas-1:~$ 12-sunbeam-bootstrap
```

## Architecture Overview
* Network Topology: Utilizes a dual-bridge network. The primary bridge handles MAAS provisioning and PXE traffic, while a secondary bridge provides an isolated Neutron provider network for OpenStack traffic.
* Node Distribution: Features one primary MAAS controller, one dedicated Juju controller, one Sunbeam cluster controller, and one heavy compute node handling the bulk of the virtualization and storage workload.
* Provisioning Pipeline: Nodes are created natively via the LXD API and commissioned in MAAS. Ceph OSDs are mapped to the compute node as raw block devices. The `sunbeam` CLI is invoked on the primary MAAS controller to validate the MAAS provider, map the network spaces, generate a multi-node manifest, and ultimately execute the cluster bootstrap, cloud configuration, and addon deployment sequences.
