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

        cherry_pick

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

cherry_pick() {
    # pci: pcie_dw_rockchip: Configure number of lanes and link width speed
    # https://github.com/u-boot/u-boot/commit/9af0c7732bf1df29138bb63712dc3fcbc6d821af
    git -C u-boot cherry-pick 9af0c7732bf1df29138bb63712dc3fcbc6d821af

    # phy: rockchip: snps-pcie3: Refactor to use clk_bulk API
    # https://github.com/u-boot/u-boot/commit/3b39592e8e245fc5c7b0a003ac65672ce9cfaf0f
    git -C u-boot cherry-pick 3b39592e8e245fc5c7b0a003ac65672ce9cfaf0f

    # phy: rockchip: snps-pcie3: Refactor to use a phy_init ops
    # https://github.com/u-boot/u-boot/commit/6cacdf842db5e62e9c26d015eddadd2f2410a6de
    git -C u-boot cherry-pick 6cacdf842db5e62e9c26d015eddadd2f2410a6de

    # phy: rockchip: snps-pcie3: Add bifurcation support for RK3568
    # https://github.com/u-boot/u-boot/commit/1ebebfcc25bc8963cbdc6e35504160e5b745cabd
    git -C u-boot cherry-pick 1ebebfcc25bc8963cbdc6e35504160e5b745cabd

    # phy: rockchip: snps-pcie3: Add support for RK3588
    # https://github.com/u-boot/u-boot/commit/50e54e80679b4ab45c84687c77309aebc6f7b981
    git -C u-boot cherry-pick 50e54e80679b4ab45c84687c77309aebc6f7b981

    # phy: rockchip: naneng-combphy: Use signal from comb PHY on RK3588
    # https://github.com/u-boot/u-boot/commit/b37260bca1aa562c6c99527d997c768a12da017b
    git -C u-boot cherry-pick b37260bca1aa562c6c99527d997c768a12da017b

    # power: regulator: Only run autoset once for each regulator
    # https://github.com/u-boot/u-boot/commit/d99fb64a98af3bebf6b0c134291c4fb89e177aa2
    git -C u-boot cherry-pick d99fb64a98af3bebf6b0c134291c4fb89e177aa2

    # regulator: rk8xx: Return correct voltage for buck converters
    # https://github.com/u-boot/u-boot/commit/04c38c6c4936f353de36be60655f402922292a37
    git -C u-boot cherry-pick 04c38c6c4936f353de36be60655f402922292a37

    # regulator: rk8xx: Return correct voltage for switchout converters
    # https://github.com/u-boot/u-boot/commit/bb657ffdd688dc08073734a402914ec0a8492d53
    git -C u-boot cherry-pick bb657ffdd688dc08073734a402914ec0a8492d53

    # arm: dts: rockchip: sync DT for RK3588 series with Linux
    # https://github.com/u-boot/u-boot/commit/74273f1d9c88f0ed4a05048bd42d599726fa69b5
    git -C u-boot cherry-pick 74273f1d9c88f0ed4a05048bd42d599726fa69b5
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

