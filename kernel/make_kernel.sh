#!/bin/sh

set -e

# script exit codes:
#   1: missing utility
#   5: invalid file hash
#   7: no screen session
#   8: superuser disallowed

main() {\
    local linux='https://git.kernel.org/torvalds/t/linux-6.4-rc7.tar.gz'
    local lxsha='c9626fe3c2564eeda618cb53c3d52c41f7492e1f628b20921d320fc1e57e6c2d'

    local lf="$(basename "$linux")"
    local lv="$(echo "$lf" | sed -nE 's/linux-(.*)\.tar\..z/\1/p')"

    if [ '_clean' = "_$1" ]; then
        rm -rf "kernel-$lv/linux-$lv"
        echo '\nclean complete\n'
        exit 0
    fi

    check_installed 'build-essential' 'python3' 'flex' 'bison' 'pahole' 'bc' 'rsync' 'libncurses-dev' 'libelf-dev' 'libssl-dev' 'lz4' 'zstd'

    mkdir -p "kernel-$lv"
    [ -f "kernel-$lv/$lf" ] || wget "$linux" -P "kernel-$lv"

    if [ "_$lxsha" != "_$(sha256sum "kernel-$lv/$lf" | cut -c1-64)" ]; then
        echo "invalid hash for linux source file: $lf"
        exit 5
    fi

    if [ ! -d "kernel-$lv/linux-$lv" ]; then
        tar -C "kernel-$lv" -xavf "kernel-$lv/$lf"

        for patch in patches/*.patch; do
            patch -p1 -d "kernel-$lv/linux-$lv" -i "../../$patch"
        done
    fi

    # build
    if [ '_inc' != "_$1" ]; then
        echo "\n${h1}configuring source tree...${rst}"
        make -C "kernel-$lv/linux-$lv" mrproper
        cp './config' "kernel-$lv/linux-$lv/.config"
    fi

    echo "\n${h1}beginning compile...${rst}"
    rm -f linux-image-*.deb
    local kv="$(make --no-print-directory -C "kernel-$lv/linux-$lv" kernelversion)"
    local bv="$(expr "$(cat "kernel-$lv/linux-$lv/.version" 2>/dev/null || echo 0)" + 1 2>/dev/null)"
    export SOURCE_DATE_EPOCH="$(stat -c %Y "kernel-$lv/linux-$lv/README")"
    export KBUILD_BUILD_TIMESTAMP="$(date -d @$SOURCE_DATE_EPOCH)"
    export KBUILD_BUILD_HOST='build-host'
    export KBUILD_BUILD_USER='debian-build'
    export KBUILD_BUILD_VERSION="$bv"

    nice make -C "kernel-$lv/linux-$lv" -j"$(nproc)" bindeb-pkg LOCALVERSION="-$bv-arm64"
    echo "\n${cya}kernel package ready${mag}"
    ln -sfv "kernel-$lv/linux-image-$kv-$bv-arm64_$kv-${bv}_arm64.deb"
    echo "${rst}"
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

cd "$(dirname "$(realpath "$0")")"
main $@

