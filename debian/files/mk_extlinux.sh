#!/bin/sh

set -e

if [ -e /boot/extlinux_defaults.txt ]; then
    . /boot/extlinux_defaults.txt
elif [ -e /extlinux_defaults.txt ]; then
    . /extlinux_defaults.txt
fi

EXTL_MENU_ITEMS="${EXTL_MENU_ITEMS:-2}"
EXTL_BOOT_DIR="${EXTL_BOOT_DIR:-/boot}"
EXTL_LINUX="${EXTL_LINUX:-vmlinuz}"
EXTL_INITRD="${EXTL_INITRD:-initrd.img}"
EXTL_FDT="${EXTL_FDT:-rk3588-rock-5b.dtb}"
EXLT_CMDLN="${EXLT_CMDLN:-ro rootwait ipv6.disable=1}"
EXTL_FILE="${EXTL_FILE:-${EXTL_BOOT_DIR}/extlinux/extlinux.conf}"


# import release info
if [ -e /etc/os-release ]; then
    . /etc/os-release
elif [ -e /usr/lib/os-release ]; then
    . /usr/lib/os-release
fi

get_root_dev() {
    local rootdev="root=$(findmnt -fsno SOURCE '/')"
    if [ -z "${rootdev}" ]; then
        rootdev="$(cat /proc/cmdline | sed -re 's/.*(root=[^[:space:]]*).*/\1/')"
    fi
    echo "${rootdev}"
}

gen_menu_header() {
    echo '#'
    echo '# this is an automatically generated file'
    echo '# to update, modify /boot/extlinux_defaults.txt'
    echo '# then run /boot/mk_extlinux.sh'
    echo '#'
    echo
    echo 'default l0'
    echo 'menu title u-boot menu'
    echo 'prompt 0'
    echo 'timeout 50'
}

gen_menu_item() {
    local num="$1"
    local kver="$2"
    local prms="$3"

    echo "label l${num}"
    echo "\tmenu label ${PRETTY_NAME} ${kver}"
    echo "\tlinux ${EXTL_BOOT_DIR}/${EXTL_LINUX}-${kver}"
    echo "\tinitrd ${EXTL_BOOT_DIR}/${EXTL_INITRD}-${kver}"
    echo "\tfdt ${EXTL_BOOT_DIR}/${EXTL_FDT}-${kver}"
    echo "\tappend ${prms}"
}

main() {
    local extcfg="$(gen_menu_header)\n\n"

    local num=0
    local kvers="$(linux-version list | linux-version sort --reverse | head -n ${EXTL_MENU_ITEMS})"
    local prms="$(get_root_dev) ${EXLT_CMDLN}"
    for kver in ${kvers}; do
        local entry="$(gen_menu_item "${num}" "${kver}" "${prms}")"
        num="$((num+1))"
        extcfg="${extcfg}\n${entry}\n"
    done

    mkdir -pv "$(dirname "${EXTL_FILE}")"
    echo "${extcfg}" > "${EXTL_FILE}"
    echo "file ${EXTL_FILE} updated successfully"
}

if [ 0 -ne $(id -u) ]; then
    echo 'this script must be run as root'
    exit 9
fi

main $@

