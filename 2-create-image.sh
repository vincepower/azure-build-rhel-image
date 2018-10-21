#!/bin/bash

##
## This script is used to upload the prepared image to azure
##
## It assumes a storage account exists, and you are running
## on a Mac that has VirtualBox with a Hard Disk type of VDI
## (and have qemu and gawk installed)
##

echo "== Cleaning up any previous partial runs"
rm -f azure.raw azure.vhd

echo "== Exporting to RAW"
VBoxManage clonehd azure.vdi azure.raw --format RAW

echo "== Ensuring the disk size is exactly on a MB (not a partial)"
MB=$((1024*1024))
size=$(qemu-img info -f raw --output json "azure.raw" | \
    gawk 'match($0, /"virtual-size": ([0-9]+),/, val) {print val[1]}')
rounded_size=$((($size/$MB + 1)*$MB))
qemu-img resize -f raw azure.raw $rounded_size

echo "== Convert the disk to VHD"
qemu-img convert -f raw -o subformat=fixed,force_size -O vpc azure.raw azure.vhd

echo "== Uploading the image"
az storage blob upload \
    --account-name vpredhat \
    --account-key "O/XqS0tCv1N/4HEkhNNodiS8xWx9srzzsMCs3h4hi3wQ9re+4rAv2Qm06PtlkrHv8qrJ2efVDCgwQCF1WejSVQ==" \
    --container-name images \
    --type page \
    --file azure.vhd \
    --name rhel75.vhd

echo "== Final clean-up"
rm -f azure.raw azure.vhd

