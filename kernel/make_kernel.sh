#!/bin/sh

set -e

# script exit codes:
#   1: missing utility
#   5: invalid file hash
#   7: no screen session
#   8: superuser disallowed

main() {\
    local linux='https://git.kernel.org/torvalds/t/linux-6.4-rc6.tar.gz'
    local lxsha='29fc6ac5009c19e0e015e64c7efe1e6b705ce9e7cbc0ff6ef751a82838e57438'

    local lf=$(basename $linux)
    local lv=$(echo $lf | sed -nE 's/linux-(.*)\.tar\..z/\1/p')

    if [ '_clean' = "_$1" ]; then
        rm -rf "linux-$lv"
        echo '\nclean complete\n'
        exit 0
    fi

    check_installed build-essential python3 flex bison pahole bc rsync libncurses-dev libelf-dev libssl-dev lz4 zstd

    [ -f $lf ] || wget $linux

    if [ _$lxsha != _$(sha256sum $lf | cut -c1-64) ]; then
        echo "invalid hash for linux source file: $lf"
        exit 5
    fi

    if [ ! -d "linux-$lv" ]; then
        tar xavf $lf

        for patch in patches/*.patch; do
            patch -p1 -d "linux-$lv" -i "../$patch"
        done
    fi

    # build
    cd "linux-$lv"

    if [ '_inc' != "_$1" ]; then
        echo "\n${h1}cleaning tree (mrproper)...${rst}"
        make mrproper
    fi

    echo "\n${h1}beginning compile...${rst}"
    cp ../config .config

    export SOURCE_DATE_EPOCH=$(stat -c %Y README)
    export KBUILD_BUILD_TIMESTAMP="$(date -d @$SOURCE_DATE_EPOCH)"
    export KBUILD_BUILD_HOST=build-host
    export KBUILD_BUILD_USER=debian-build
    export KBUILD_BUILD_VERSION=1

    nice make -j$(nproc) bindeb-pkg LOCALVERSION=-1-arm64
    echo "\n${cya}kernel ready${rst}\n"
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

if [ 0 -eq $(id -u) ]; then
    echo 'do not compile as root'
    exit 8
fi

if [ -z $STY ]; then
    echo 'run from a screen session'
    exit 7
fi

cd "$(dirname "$(readlink -f "$0")")"
main $@

