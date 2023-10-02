#!/bin/sh

set -e

# script exit codes:
#   1: missing utility

main() {
    local utag='v2023.10'
    local atf_file='../rkbin/rk3588_bl31_v1.34.elf'
    local tpl_file='../rkbin/rk3588_ddr_lp4_2112MHz_lp5_2736MHz_v1.08.bin'

    # branch name is yyyy.mm[-rc]
    local branch="$(echo "$utag" | grep -Po '\d{4}\.\d{2}(.*-rc\d)*')"
    echo "${bld}branch: $branch${rst}"

    if is_param 'clean' "$@"; then
        rm -f *.img *.itb
        if [ -d u-boot ]; then
            rm -f 'u-boot/mkimage-in-simple-bin'*
            rm -f 'u-boot/simple-bin.fit'*
            make -C u-boot distclean
            git -C u-boot clean -f
            git -C u-boot checkout master
            git -C u-boot branch -D "$branch" 2>/dev/null || true
            git -C u-boot pull --ff-only
        fi
        echo '\nclean complete\n'
        exit 0
    fi

    check_installed 'bc' 'bison' 'flex' 'libssl-dev' 'make' 'python3-dev' 'python3-pyelftools' 'python3-setuptools' 'swig'

    if [ ! -d u-boot ]; then
        git clone https://github.com/u-boot/u-boot.git
        git -C u-boot fetch --tags
    fi

    if ! git -C u-boot branch | grep -q "$branch"; then
        git -C u-boot checkout -b "$branch" "$utag"

        local patch
        for patch in patches/*.patch; do
            git -C u-boot am "../$patch"
        done
    elif [ "$branch" != "$(git -C u-boot branch --show-current)" ]; then
        git -C u-boot checkout "$branch"
    fi

    # outputs: idbloader.img, u-boot.itb
    rm -f 'idbloader.img' 'u-boot.itb'
    if ! is_param 'inc' "$@"; then
        make -C u-boot distclean
        make -C u-boot rock5b-rk3588_defconfig
    fi
    make -C u-boot -j$(nproc) BL31="$atf_file" ROCKCHIP_TPL="$tpl_file"
    ln -sfv 'u-boot/idbloader.img'
    ln -sfv 'u-boot/u-boot.itb'

    is_param 'cp' "$@" && cp_to_debian

    echo "\n${cya}idbloader and u-boot binaries are now ready${rst}"
    echo "\n${cya}copy images to media:${rst}"
    echo "  ${cya}sudo dd bs=4K seek=8 if=idbloader.img of=/dev/sdX conv=notrunc${rst}"
    echo "  ${cya}sudo dd bs=4K seek=2048 if=u-boot.itb of=/dev/sdX conv=notrunc,fsync${rst}"
    echo
    echo "${blu}optionally, flash to spi (apt install mtd-utils):${rst}"
    echo "  ${blu}sudo flashcp -Av idbloader.img /dev/mtd0${rst}"
    echo "  ${blu}sudo flashcp -Av u-boot.itb /dev/mtd2${rst}"
    echo
}

cp_to_debian() {
    local deb_dist=$(cat "../debian/make_debian_img.sh" | sed -n 's/\s*local deb_dist=.\([[:alpha:]]\+\)./\1/p')
    [ -z "$deb_dist" ] && return
    local cdir="../debian/cache.$deb_dist"
    echo '\ncopying to debian cache...'
    sudo mkdir -p "$cdir"
    sudo cp -v './idbloader.img' "$cdir"
    sudo cp -v './u-boot.itb' "$cdir"
}

check_installed() {
    local item todo
    for item in "$@"; do
        dpkg -l "$item" 2>/dev/null | grep -q "ii  $item" || todo="$todo $item"
    done

    if [ ! -z "$todo" ]; then
        echo "this script requires the following packages:${bld}${yel}$todo${rst}"
        echo "   run: ${bld}${grn}sudo apt update && sudo apt -y install$todo${rst}\n"
        exit 1
    fi
}

is_param() {
    local item match
    for item in "$@"; do
        if [ -z "$match" ]; then
            match="$item"
        elif [ "$match" = "$item" ]; then
            return 0
        fi
    done
    return 1
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

