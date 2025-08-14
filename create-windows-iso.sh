#!/bin/bash
set -eE

if [ $EUID -ne 0 ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

declare -A WIN_URL=(
    [win2k16]='https://go.microsoft.com/fwlink/?LinkID=2195174&clcid=0x409&culture=en-us&country=US'
    [win2k19]='https://go.microsoft.com/fwlink/?LinkID=2195167&clcid=0x409&culture=en-us&country=US'
    [win2k22]='https://go.microsoft.com/fwlink/?LinkID=2195280&clcid=0x409&culture=en-us&country=US'
    [win2k25]='https://go.microsoft.com/fwlink/?linkid=2293312&clcid=0x409&culture=en-us&country=US'
)

if [[ $# -ne 1 || -z ${WIN_URL[$1]} ]]; then
    IFS='|'
    cat 1>&2 <<EOD
Usage: $(basename $0) CODE

CODE	One of [${!WIN_URL[*]}]
EOD
    exit 1
fi

BASEDIR=$(dirname $0)
WIN_VER=$1

: ${WIN_ISO:=$BASEDIR/$WIN_VER.iso}
if [[ ! -f $WIN_ISO ]]; then
    echo "Downloading $WIN_VER..."
    curl -o $WIN_ISO.download -C- -#fSL ${WIN_URL[$WIN_VER]} \
    && mv $WIN_ISO.download $WIN_ISO
fi

TMP_WIN_ISO=$(/bin/mktemp)
TMP_MOUNT_PATH=$(/bin/mktemp -d)
mkdir $TMP_MOUNT_PATH/{lower,upper,workdir,overlay}
cleanup() {
    umount $TMP_MOUNT_PATH/overlay
    umount $TMP_MOUNT_PATH/lower
    rm -rf $TMP_WIN_ISO $TMP_MOUNT_PATH
}
trap cleanup INT ERR EXIT

echo "Mounting $WIN_VER ISO..."
mount -o loop -r $WIN_ISO $TMP_MOUNT_PATH/lower
eval `blkid -o export $(awk '$2~mount{ print $1 }' mount=$TMP_MOUNT_PATH /proc/mounts)`

echo "Allowing direct CD/DVD booting..."
mount -t overlay -o lowerdir=$TMP_MOUNT_PATH/lower,upperdir=$TMP_MOUNT_PATH/upper,workdir=$TMP_MOUNT_PATH/workdir none $TMP_MOUNT_PATH/overlay
cp $TMP_MOUNT_PATH/overlay/efi/microsoft/boot/efisys_noprompt.bin $TMP_MOUNT_PATH/overlay/efi/microsoft/boot/efisys.bin
cp $TMP_MOUNT_PATH/overlay/efi/microsoft/boot/cdboot_noprompt.efi $TMP_MOUNT_PATH/overlay/efi/microsoft/boot/cdboot.bin

echo "Creating $WIN_VER ISO..."
xorriso -as mkisofs -iso-level 3 -volid "$LABEL" -eltorito-boot boot/etfsboot.com -eltorito-catalog boot/boot.cat -no-emul-boot -boot-load-size 8 -boot-info-table -eltorito-alt-boot -e efi/microsoft/boot/efisys.bin -no-emul-boot -isohybrid-gpt-basdat -o $TMP_WIN_ISO $TMP_MOUNT_PATH/overlay

: ${WIN_IMAGE:=$BASEDIR/$WIN_VER.noprompt.iso}
mv $TMP_WIN_ISO $WIN_IMAGE
