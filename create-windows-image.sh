#!/bin/bash
set -eE

if [ $EUID -ne 0 ]; then
    echo "This script must be run as root" 1>&2
    exit 1
fi

declare -a WIN_YEARS=(2016 2019 2022 2025)

declare -A WIN_URL=(
    [hyp2k16]='https://go.microsoft.com/fwlink/?LinkID=2195337&clcid=0x409&culture=en-us&country=US'
    [win2k16]='https://go.microsoft.com/fwlink/?LinkID=2195174&clcid=0x409&culture=en-us&country=US'
    [hyp2k19]='https://go.microsoft.com/fwlink/?LinkID=2195287&clcid=0x409&culture=en-us&country=US'
    [win2k19]='https://go.microsoft.com/fwlink/?LinkID=2195167&clcid=0x409&culture=en-us&country=US'
    [win2k22]='https://go.microsoft.com/fwlink/?LinkID=2195280&clcid=0x409&culture=en-us&country=US'
    [win2k25]='https://go.microsoft.com/fwlink/?linkid=2293312&clcid=0x409&culture=en-us&country=US'
)

: ${VIRTIO_URL:=https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso}

run() {
    local CMD=$1
    shift

    if [[ $DRY_RUN ]]; then
        echo Executing: $CMD "$@" 1>&2
        [[ $CMD =~ dd|mkfs|mount|rm|umount ]] || return 0
    fi
    command $CMD "$@"
}

CMDS=(cp dd mkfs mount mv rm qemu-img qemu-system-x86_64 umount virt-install xorriso)
for CMD in ${CMDS[*]}; do eval 'function '$CMD' { run '$CMD' "$@"; }'; done

CMD=$(basename $0)
BASEDIR=$(dirname $0)

get_options() {
    declare -A OPTS=(
        [HYPER]='--hyper-v'
        [STANDARD]='--standard'
        [DATACENTER]='--datacenter'
        [CORE]='--core'
    )

    declare -a LIST
    for OPT in ${!OPTS[*]}; do
        if [[ "$1" =~ $OPT ]]; then
            LIST+=(${OPTS[$OPT]})
        fi
    done
    echo -n ${LIST[*]}
}

usage() {
    local IFS='|'
    cat <<EOD
Usage: $CMD [OPTIONS] YEAR

YEAR            Windows version identified by year (one of [${WIN_YEARS[*]}])

-i|--iso        Windows ISO image (default [hyp|win]2k[YY].iso)
-f|--floppy     Unattend floppy image (default [hyp|win]2k[YY].vfd)
-p|--prompt     Modify ISO for manual installation (ask to press key)
-n|--no-prompt  Modify ISO for direct installation (no press key)
-s|--size SIZE  Disk image size expressed in GiB (>= default 15/30 with updates)
-u|--update     Download and install all available updates (disk size >= 30)
-z|--compress   Compress qcow2 output image with zlib algorithm
-k|--kvm [ISO]  Install virtIO dirvers (default virtio-win.iso)
-c|--core       Install Windows without graphical environment (exclude --default)
-d|--desktop    Install Windows with graphical environment (default, exclude --core)
-V|--hyper-v    Install Hyper-V edition (implies --core)
-S|--standard   Install Standard edition
-D|--datacenter	Install DataCenter edition
-I|--ini FILE   Alternative INI file (default config.ini)
-K|--key KEY    Activate Product Key (KEY=XXXXX-XXXXX-XXXXX-XXXXX-XXXXX)
-N|--name NAME  Windows disk image name without extension (default [hyp|win]2k[YY])
   --dry-run    Print actions instead of executing them
-h|--help       Display this help
EOD
}

if ! OPTS=$(getopt -o 'i:f:pns:uzk::cdVSDI:K:N:h' -l 'iso:,floppy:,prompt,no-prompt,size:,update,compress,kvm::,core,desktop,hyper-v,standard,datacenter,ini:,key:,name:,dry-run,help' -n $CMD -- "$@"); then
    usage 1>&2
    exit 1
fi
eval set -- "$OPTS"
unset OPTS

OS='Windows'
HW='phy'
CONFIG_INI='config.ini'
VIRTIO_ISO='virtio-win.iso'
INSTALL_UPDATES=False
PURGE_UPDATES=False
while true; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        --dry-run)
            DRY_RUN=True
            ;;
        -i|--iso)
            WIN_ISO=$2
            shift
            ;;
        -f|--floppy)
            WIN_VFD=$2
            shift
            ;;
        -p|--prompt)
            PROMPT='prompt'
            ;;
        -n|--no-prompt)
            PROMPT='noprompt'
            ;;
        -s|--size)
            SIZE=$2
            shift
            ;;
        -u|--update)
            INSTALL_UPDATE=True
            PURGE_UPDATE=True
            : ${SIZE:=30}
            ;;
        -z|--compress)
            COMPRESS='-c'
            ;;
        -k|--kvm)
            HW='kvm'
            [[ -z $2 ]] || VIRTIO_ISO=$2
            shift
            ;;
        -c|--core)
            if [[ ${CORE=CORE} != CORE ]]; then
                echo "--core and --desktop are mutually exclusive." 1>&2
                exit 1
            fi
            ;;
        -d|--desktop)
            if [[ ${CORE=''} != '' ]]; then
                echo "--core and --desktop are mutually exclusive." 1>&2
                exit 1
            fi
            ;;
        -V|--hyper-v)
            if [[ ${EDITION=HYPER} != HYPER ]]; then
                echo "--hyper-v, --standard, and --datacenter are mutually exclusive." 1>&2
                exit 1
            fi
            OS='Hyper-V'
            CORE='CORE'
            ;;
        -S|--standard)
            if [[ ${EDITION=STANDARD} != STANDARD ]]; then
                echo "--hyper-v, --standard, and --datacenter are mutually exclusive." 1>&2
                exit 1
            fi
            ;;
        -D|--datacenter)
            if [[ ${EDITION=DATACENTER} != DATACENTER ]]; then
                echo "--hyper-v, --standard, and --datacenter are mutually exclusive." 1>&2
                exit 1
            fi
            ;;
        -I|--ini)
            CONFIG_INI=$2
            shift
            ;;
        -K|--key)
            PRODUCT_KEY="<ProductKey>$2</ProductKey>"
            shift
            ;;
        -N|--name)
            DISK_NAME=$2
            shift
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Internal error while parsing parameters." 1>&2
            exit 1
            ;;
    esac
    shift
done

# Check year validity
if [[ $# -ne 1 || $1 =~ ' ' || ! " ${WIN_YEARS[*]} " =~ " $1 " ]]; then
    echo "Invalid year: $1" 1>&2
    usage 1>&2
    exit 1
fi

# Check for INI file
if [[ ! -f "$CONFIG_INI" ]]; then
    echo "Custom INI file not found: $CONFIG_INI" >&2
    exit 1
fi

# Check disk size
: ${SIZE:=15}
if [[ $INSTALL_UPDATE == True && $SIZE -lt 30 || $SIZE -lt 15 ]]; then
    echo "Insufficient disk size: $SIZE (>= 15GiB or 30GiB with updates)"
    exit 1
fi

YEAR=$1
FLAGS="SERVER${EDITION}${CORE}"
IMAGE_CODE="2k${YEAR:2:2}"
IMAGE_NAME="$OS Server $YEAR $FLAGS"
WIN_VER=${OS:0:3}
WIN_VER="${WIN_VER@L}$IMAGE_CODE"
QCOW_DISK="${DISK_NAME:-$WIN_VER}.qcow2"

# Check version availability
if [[ -z ${WIN_URL[$WIN_VER]} ]]; then
    echo "$IMAGE_NAME not available." 1>&2
    exit 1
fi

TMP_DISK_IMAGE=$(/bin/mktemp)
TMP_MOUNT_PATH=$(/bin/mktemp -d)
mkdir $TMP_MOUNT_PATH/{iso,upper,workdir,overlay}
cleanup() {
    umount "$TMP_MOUNT_PATH/overlay" || :
    umount "$TMP_MOUNT_PATH/iso" || :
    rm -rf "$TMP_DISK_IMAGE" "$TMP_MOUNT_PATH" || :
} &>/dev/null
trap cleanup INT ERR

# Download Windows ISO image if not present
if [[ ! -f "${WIN_ISO:=$WIN_VER.iso}" ]]; then
    echo "Downloading $OS $YEAR ($WIN_ISO)..."
    curl -o "$WIN_ISO.download" -C- -#fSL "${WIN_URL[$WIN_VER]}"
    mv "$WIN_ISO.download" "$WIN_ISO"
fi

# Mount ISO image
mount -o loop -r "$WIN_ISO" "$TMP_MOUNT_PATH/iso"

# Lookup available Windows images
mapfile -t IMAGES < <(wiminfo "$TMP_MOUNT_PATH/iso/sources/install.wim" | awk -F': *' '/^Name:/{ print $2 }')
if [[ $FLAGS == SERVER && ${#IMAGES[*]} == 1 ]]; then
    IMAGE=${IMAGES[0]##* }
else
    IMAGE=$(printf '%s\n' "${IMAGES[@]}" | grep "$FLAGS\$" || :)
fi
if [[ -z "$IMAGE" ]]; then
    echo "No specific image selected, choose one from:"
    for IMAGE in "${IMAGES[@]}"; do
        OPTIONS=$(get_options "$IMAGE")
        echo "- $IMAGE: ($OPTIONS)"
    done
    exit 1
fi
if [[ $IMAGE != $IMAGE_NAME ]]; then
    echo "Expected image \`$IMAGE_NAME’ not found, get \`$IMAGE’ instead." 1>&2
    exit 1
fi
echo "Image found: $IMAGE"

switch_iso_boot() {
    # Exit if no prompt change
    [[ $# -eq 1 ]] || return

    local TGT=$1
    declare -A SRC=(
       [prompt]='noprompt'
       [noprompt]='prompt'
    )

    # Return if there are no files to restore
    for FILE in efisys.bin cdboot.efi; do
        SOURCE="$TMP_MOUNT_PATH/iso/efi/microsoft/boot/${FILE/./_$TGT.}"
        [[ -f "$SOURCE" ]] || return 0
    done

    echo "Create custom ISO image..."

    # Use overlay instead of copying to reduce disk space usage
    mount -t overlay \
          -o lowerdir="$TMP_MOUNT_PATH/iso",upperdir="$TMP_MOUNT_PATH/upper",workdir="$TMP_MOUNT_PATH/workdir" \
          none "$TMP_MOUNT_PATH/overlay"

    # Switch boot files
    for TARGET in efisys.bin cdboot.efi; do
        SOURCE=${TARGET/./_$TGT.}
        BACKUP=${TARGET/./_${SRC[$TGT]}.}
        mv "$TMP_MOUNT_PATH/overlay/efi/microsoft/boot/$TARGET" \
           "$TMP_MOUNT_PATH/overlay/efi/microsoft/boot/$BACKUP"
        mv "$TMP_MOUNT_PATH/overlay/efi/microsoft/boot/$SOURCE" \
           "$TMP_MOUNT_PATH/overlay/efi/microsoft/boot/$TARGET"
    done

    # Extract blkid properties (e.g. LABEL)
    eval `blkid -o export $(awk '$2~mount{ print $1 }' mount="$TMP_MOUNT_PATH" /proc/mounts)`

    # Burn the new ISO
    xorriso -as mkisofs \
            -iso-level 3 \
            -volid "$LABEL" \
            -eltorito-boot boot/etfsboot.com \
            -eltorito-catalog boot/boot.cat \
            -no-emul-boot \
            -boot-load-size 8 \
            -boot-info-table \
            -eltorito-alt-boot \
            -e efi/microsoft/boot/efisys.bin \
            -no-emul-boot \
            -isohybrid-gpt-basdat \
            -o "$TMP_DISK_IMAGE" \
            "$TMP_MOUNT_PATH/overlay"

    # Replace original ISO
    umount "$TMP_MOUNT_PATH/overlay"
    mv "$TMP_DISK_IMAGE" "$WIN_ISO"

    echo "ISO image: $WIN_ISO"
}

# Modify ISO image as needed
switch_iso_boot $PROMPT

# Clean up ISO tasks
umount "$TMP_MOUNT_PATH/iso"
rm -rf "$TMP_DISK_IMAGE" "$TMP_MOUNT_PATH"

# Create Autounattend floppy image
echo "Create Autounattend floppy image..."
TMP_DISK_IMAGE=$(/bin/mktemp)
TMP_MOUNT_PATH=$(/bin/mktemp -d)

dd if=/dev/zero of=$TMP_DISK_IMAGE bs=1k count=1440
mkfs -t vfat $TMP_DISK_IMAGE
mount -t vfat -o loop $TMP_DISK_IMAGE $TMP_MOUNT_PATH

UNATTEND_XML="Autounattend-$HW.xml.in"
CONTENT_SRC="$BASEDIR/Autounattend"

export IMAGE_CODE IMAGE_NAME PRODUCT_KEY INSTALL_UPDATES PURGE_UPDATES
envsubst <"$CONTENT_SRC/$UNATTEND_XML" >"$TMP_MOUNT_PATH/Autounattend.xml"
envsubst <"$CONFIG_INI" >"$TMP_MOUNT_PATH/config.ini"
cp "$CONTENT_SRC"/*.ps* "$TMP_MOUNT_PATH/"
cp "$CONTENT_SRC"/*.conf "$TMP_MOUNT_PATH/"

umount "$TMP_MOUNT_PATH"
rmdir "$TMP_MOUNT_PATH"

mv "$TMP_DISK_IMAGE" "${WIN_VFD:=$WIN_VER.vfd}"
echo "Autounattend floppy image: $WIN_VFD"

# Download virtIO ISO image if not present
if [[ ! -f "$VIRTIO_ISO" ]]; then
    echo "Downloading virtIO ISO ($VIRTIO_ISO)..."
    curl -o "$VIRTIO_ISO.download" -C- -#fSL "$VIRTIO_URL"
    mv "$VIRTIO_ISO.download" "$VIRTIO_ISO"
fi

TMP_DISK_IMAGE=$(/bin/mktemp)
truncate --size=${SIZE}G "$TMP_DISK_IMAGE"

qemu_system() {
    qemu-system-x86_64 \
	-accel kvm \
	-cpu host \
	-smp 2 \
	-m 4G \
	-bios /usr/share/ovmf/OVMF.fd \
	-device qemu-xhci \
	-device usb-tablet \
	-drive file="$TMP_DISK_IMAGE",if=virtio,index=0,media=disk,format=raw \
	-drive file="$VIRTIO_ISO",index=3,media=cdrom \
	-drive file="$WIN_VFD",if=floppy,index=0,format=raw \
	-nic user \
	-display none \
	-vnc :0,to=100 \
        "$@"
}

# First install from ISO
echo "Install Windows from ISO..."
qemu_system -no-reboot -drive file="$WIN_ISO",index=2,media=cdrom -boot order=d

echo "Complete Windows installation from disk..."
# Then complete installation from disk
qemu_system

#virt-install --connect qemu:///system \
#	--name $WIN_VER \
#	--ram 4096 --vcpus 2 \
#	--network bridge=lan0,model=virtio \
#	--disk format=raw,size=30,device=disk,bus=virtio \
#	--cdrom $WIN_ISO \
#	--disk path=$VIRTIO_ISO,device=cdrom \
#	--disk path=$WIN_VFD,device=floppy \
#	--osinfo detect=on,require=off \
#	--graphics=vnc --boot uefi

echo "Convert${COMPRESS+ and compress} Windows disk image ($QCOW_DISK)..."
qemu-img convert $COMPRESS -p -O qcow2 "$TMP_DISK_IMAGE" "$QCOW_DISK"
