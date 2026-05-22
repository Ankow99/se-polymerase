#!/bin/bash

# Ensure an input file is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_cloud_init_template.yaml>"
    exit 1
fi

INPUT_FILE=$1

# Ensure the input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: File '$INPUT_FILE' not found."
    exit 1
fi

# Array containing the version mapping matrix including the OS base
# Format: "UBUNTU_OS OS_VER OS_RELEASE CEPH OVN MYSQL RABBITMQ VAULT"
RELEASES=(
    "focal 20.04 ussuri octopus 22.03 8.0 3.8 1.7"
    "focal 20.04 victoria octopus 22.03 8.0 3.8 1.7"
    "focal 20.04 wallaby pacific 22.03 8.0 3.8 1.7"
    "focal 20.04 xena pacific 22.03 8.0 3.8 1.7"
    "focal 20.04 yoga quincy 22.03 8.0 3.8 1.7"
    "jammy 22.04 yoga quincy 22.03 8.0 3.9 1.8"
    "jammy 22.04 zed quincy 22.09 8.0 3.9 1.8"
    "jammy 22.04 2023.1 quincy 23.03 8.0 3.9 1.8"
    "jammy 22.04 2023.2 reef 23.09 8.0 3.9 1.8"
)

echo "Starting OpenStack release cloud-init generation from '$INPUT_FILE'..."

for entry in "${RELEASES[@]}"; do
    # Read the space-separated string into discrete variables
    read -r ubuntu_os os_ver os_release ceph ovn mysql rabbit vault <<< "$entry"
    
    OUTPUT_FILE="${ubuntu_os}-${os_release}.yaml"
    echo "  -> Generating '$OUTPUT_FILE'"

    # Use sed to replace the variables inline
    # This also dynamically handles the Focal (20.04) vs Jammy (22.04) base image swaps
    sed -e "s|{% set custom_repro_name = .*|{% set custom_repro_name = \"${ubuntu_os}-${os_release}\" %}|" \
        -e "s|{% set custom_openstack_channel = .*|{% set custom_openstack_channel = \"${os_release}/stable\" %}  # PROMPT:OpenStack Channel|" \
        -e "s|{% set custom_ceph_channel = .*|{% set custom_ceph_channel = \"${ceph}/stable\" %}      # PROMPT:Ceph Channel|" \
        -e "s|{% set custom_ovn_channel = .*|{% set custom_ovn_channel = \"${ovn}/stable\" %}         # PROMPT:OVN Channel|" \
        -e "s|{% set custom_mysql_channel = .*|{% set custom_mysql_channel = \"${mysql}/stable\" %}         # PROMPT:MySQL InnoDB Channel|" \
        -e "s|{% set custom_rabbitmq_channel = .*|{% set custom_rabbitmq_channel = \"${rabbit}/stable\" %}      # PROMPT:RabbitMQ Channel|" \
        -e "s|{% set custom_vault_channel = .*|{% set custom_vault_channel = \"${vault}/stable\" %}         # PROMPT:Vault Channel|" \
        -e "s|{% set custom_maas_images = .*|{% set custom_maas_images = \"${ubuntu_os}\" %}              # PROMPT:MAAS Deploy Images (space separated)|" \
        -e "s|{% set custom_os_base_flavor = .*|{% set custom_os_base_flavor = ${ubuntu_os} %}             # PROMPT:OpenStack Flavor Base|" \
        -e "s|{% set custom_juju_base = .*|{% set custom_juju_base = \"ubuntu@${os_ver}\" %}         # PROMPT:Juju Base|" \
        "$INPUT_FILE" > "$OUTPUT_FILE"
done

echo "All templates successfully generated in their respective OS directories!"
