#!/bin/bash

declare -a WIN_YEARS=(2016 2019 2022 2025)

usage() {
    local IFS='|'
    cat 1>&2 <<EOD
Usage: $CMD YEAR

YEAR		Windows version identified by year (one of [${WIN_YEARS[*]}])
EOD
}

if [[ $# -ne 1 || $1 =~ ' ' || ! " ${WIN_YEARS[*]} " =~ " $1 " ]]; then
    usage 1>&2 && exit 1
fi

WIN_CODE="win2k${1:2:2}"


virt-install --connect qemu:///system \
	--name $WIN_CODE \
	--ram 4096 --vcpus 2 \
	--network bridge=lan0,model=virtio \
	--disk format=raw,size=15,device=disk,bus=virtio \
	--cdrom $WIN_CODE.noprompt.iso \
	--disk path=virtio-win.iso,device=cdrom \
	--disk path=$WIN_CODE.vfd,device=floppy \
	--osinfo detect=on,require=off \
	--graphics=vnc --boot uefi
