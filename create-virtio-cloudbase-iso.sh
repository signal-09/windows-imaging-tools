#!/bin/bash
set -eE

BASEDIR=$(dirname $0)

: ${VIRTIO_URL:=https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/latest-virtio/virtio-win.iso}
: ${VIRTIO_ISO:=$BASEDIR/virtio-win.iso}
if [[ ! -f $VIRTIO_ISO ]]; then
    echo "Downloading virtIO drivers for Windows..."
    curl -o $VIRTIO_ISO -#fSL $VIRTIO_URL
fi

TMP_VIRTIO_ISO=$(/bin/mktemp)
TMP_MOUNT_PATH=$(/bin/mktemp -d)
trap "rm -rf $TMP_VIRTIO_ISO $TMP_MOUNT_PATH" INT ERR EXIT

echo "Extracting virtIO ISO..."
ISO_LABEL=$(osirrox -indev $VIRTIO_ISO -extract / $TMP_MOUNT_PATH 2>&1 | sed -n -e "s/^Volume id.*'\(.*\)'/\\1/p")

: ${CLOUDBASE_URL:=https://cloudbase.it/downloads/CloudbaseInitSetup_Stable_x64.msi}
: ${CLOUDBASE_MSI:=$BASEDIR/CloudbaseInit.msi}
if [[ ! -f $CLOUDBASE_MSI ]]; then
    echo "Downloading Cloudbase-Init installer..."
    curl -o $CLOUDBASE_MSI -#fSL $CLOUDBASE_URL
fi
echo "Merging Cloudbase-Init with virtIO ISO..."
cp $CLOUDBASE_MSI $TMP_MOUNT_PATH/

echo "Creating virtIO/Cloudbase-Init ISO..."
mkisofs -quiet -o $TMP_VIRTIO_ISO -r -iso-level 4 -input-charset iso8859-1 -V $ISO_LABEL $TMP_MOUNT_PATH

: ${VIRTIO_IMAGE:=$BASEDIR/virtio-cloudbase.iso}
cp $TMP_VIRTIO_ISO $VIRTIO_IMAGE
