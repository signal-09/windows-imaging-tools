#!/bin/bash
set -eE

if [ $EUID -ne 0 ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

CMD=$(basename $0)
BASEDIR=$(dirname $0)

declare -a WIN_YEARS=(2016 2019 2022 2025)

usage() {
    local IFS='|'
    cat 1>&2 <<EOD
Usage: $CMD [OPTION] YEAR

YEAR		Windows version identified by year (one of [${WIN_YEARS[*]}])

-E|--efi	Enable EFI
-H|--hyper-v	Enable Hyper-V
-I|--ini FILE	Alternative config.ini
-K|--key=KEY	Activate Product Key (KEY=XXXXX-XXXXX-XXXXX-XXXXX-XXXXX)
-V|--virtio	Install virtIO dirver
-h|--help	Display this help 
EOD
}

OPTS=$(getopt -o 'EHI:K:Vh' --long 'efi,hyper-v,ini:,key:,virtio,help' -n $CMD -- "$@")
eval set -- "$OPTS"
unset OPTS

CONTENT_SRC=$BASEDIR/Autounattend
CONFIG_INI=$CONTENT_SRC/config.ini
OS="Windows"
TYPE="SERVERSTANDARD"
HW="phy"
while true; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -E|--efi)
            EFI=true
            ;;
        -H|--hyper-v)
            OS="Hyper-V"
            TYPE="SERVERHYPERCORE"
            ;;
        -I|--ini)
            CONFIG_INI="$2"
            shift
            if [[ ! -f "$CONFIG_INI" ]]; then
                echo "Custom INI file not found: $CONFIG_INI" >&2
                exit 1
            fi
            ;;
        -K|--key)
            PRODUCT_KEY="<ProductKey>$2</ProductKey>"
            shift
            ;;
        -V|--virtio)
            HW="kvm"
            ;;
        --)
            shift
            break
            ;;
        *)
            echo 'Internal error!' >&2
            exit 1
            ;;
    esac
    shift
done

if [[ $# -ne 1 || $1 =~ ' ' || ! " ${WIN_YEARS[*]} " =~ " $1 " ]]; then
    usage 1>&2 && exit 1
fi

export IMAGE_CODE="2k${1:2:2}"
export IMAGE_NAME="$OS Server $1 $TYPE"
export UNATTEND_XML="Autounattend-$HW.xml.in"

FLOPPY_IMAGE=$BASEDIR/win$IMAGE_CODE.vfd

TMP_FLOPPY_IMAGE=`/bin/mktemp`
TMP_MOUNT_PATH=`/bin/mktemp -d`

rm -rf $TMP_MOUNT_PATH
rm -f $TMP_FLOPPY_IMAGE
dd if=/dev/zero of=$TMP_FLOPPY_IMAGE bs=1k count=1440
mkfs.vfat $TMP_FLOPPY_IMAGE

mkdir $TMP_MOUNT_PATH
mount -t vfat -o loop $TMP_FLOPPY_IMAGE $TMP_MOUNT_PATH
envsubst <$CONTENT_SRC/$UNATTEND_XML >$TMP_MOUNT_PATH/Autounattend.xml
cp $CONTENT_SRC/*.ps1 $CONTENT_SRC/*.psm1 $TMP_MOUNT_PATH
cp $CONTENT_SRC/*.conf $TMP_MOUNT_PATH
cp $CONFIG_INI $TMP_MOUNT_PATH/config.ini

umount $TMP_MOUNT_PATH
rmdir $TMP_MOUNT_PATH

cp $TMP_FLOPPY_IMAGE $FLOPPY_IMAGE
