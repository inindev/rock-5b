#!/bin/sh

set -e

# script exit codes:
#   1: missing utility
#   5: invalid file hash

main() {\
    local linux='https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-6.4.2.tar.xz'
    local lxsha='a326ab224176c5b17c73c9ccad85f32e49b6e4e764861d57595727b7ef10062c'

    local lf=$(basename "$linux")
    local lv=$(echo $lf | sed -nE 's/linux-(.*)\.tar\..z/\1/p')

    if [ '_clean' = "_$1" ]; then
        rm -f *.dt*
        rm -rf "linux-$lv"
        echo '\nclean complete\n'
        exit 0
    fi

    check_installed 'device-tree-compiler' 'gcc' 'wget' 'xz-utils'

    [ -f $lf ] || wget $linux

    if [ _$lxsha != _$(sha256sum $lf | cut -c1-64) ]; then
        echo "invalid hash for linux source file: $lf"
        exit 5
    fi

    local rkpath=linux-$lv/arch/arm64/boot/dts/rockchip
    local rkfl='rk3588-rock-5b.dts rk3588.dtsi rk3588s.dtsi rk3588-pinctrl.dtsi rockchip-pinconf.dtsi'
    if [ ! -d "linux-$lv" ]; then
        tar xavf $lf linux-$lv/include/dt-bindings linux-$lv/include/uapi $rkpath

        for rkf in $rkfl; do
            get_for_next $rkpath/$rkf
        done
    fi

    if [ _links = _$1 ]; then
        for rkf in $rkfl; do
            ln -sfv $rkpath/$rkf
        done
        echo '\nlinks created\n'
        exit 0
    fi

    # build
    local dt=rk3588-rock-5b
    gcc -I linux-$lv/include -E -nostdinc -undef -D__DTS__ -x assembler-with-cpp -o ${dt}-top.dts $rkpath/${dt}.dts

    local fldtc='-Wno-interrupt_provider -Wno-unique_unit_address -Wno-unit_address_vs_reg -Wno-avoid_unnecessary_addr_size -Wno-alias_paths -Wno-graph_child_address -Wno-simple_bus_reg'
    dtc -I dts -O dtb -b 0 ${fldtc} -o ${dt}.dtb ${dt}-top.dts

    echo "\n${cya}device tree ready: ${dt}.dtb${rst}\n"
}

get_for_next() {
    local filepath=$1
    local file=$(basename "$filepath")
    local url=https://gitlab.collabora.com/hardware-enablement/rockchip-3588/linux/-/raw/rk3588/arch/arm64/boot/dts/rockchip/$file?inline=false
    wget -O "$filepath" "$url"
}

check_installed() {
    local todo
    for item in "$@"; do
        dpkg -l "$item" 2>/dev/null | grep -q "ii  $item" || todo="$todo $item"
    done

    if [ ! -z "$todo" ]; then
        echo "this script requires the following packages:${bld}${yel}$todo${rst}"
        echo "   run: ${bld}${grn}sudo apt update && sudo apt -y install$todo${rst}\n"
        exit 1
    fi
}

rst='\033[m'
bld='\033[1m'
red='\033[31m'
grn='\033[32m'
yel='\033[33m'
blu='\033[34m'
mag='\033[35m'
cya='\033[36m'
h1="${blu}==>${rst} ${bld}"

cd "$(dirname "$(realpath "$0")")"
main "$@"

