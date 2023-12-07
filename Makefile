
LDIST ?= $(shell cat "debian/make_debian_img.sh" | sed -n 's/\s*local deb_dist=.\([[:alpha:]]\+\)./\1/p')


all: screen uboot dtb debian
	@echo "all binaries ready"

debian: screen uboot dtb debian/mmc_2g.img kernel
	sudo sh debian/install_kernel.sh
	@echo "debian image ready"

dtb: dtb/rk3588-rock-5b.dtb
	@echo "device tree binaries ready"

kernel: screen kernel/linux-image-*_arm64.deb
	@echo "kernel package is ready"

uboot: uboot/idbloader.img uboot/u-boot.itb
	@echo "u-boot binaries ready"

package-%: all
	@echo "building package for version $*"

	@rm -rfv distfiles
	@mkdir -v distfiles

	@cp -v uboot/idbloader.img uboot/u-boot.itb distfiles
	@cp -v dtb/rk3588-rock-5b.dtb distfiles
	@cp -v debian/mmc_2g.img distfiles/rock-5b_$(LDIST)-$*.img
	@xz -zve8 distfiles/rock-5b_$(LDIST)-$*.img

	@cd distfiles ; sha256sum * > sha256sums.txt

clean:
	@rm -rfv distfiles
	sudo sh debian/make_debian_img.sh clean
	sh dtb/make_dtb.sh clean
	sh uboot/make_uboot.sh clean
	@echo "all targets clean"

screen:
ifeq ($(STY)$(TMUX),)
	$(error please start a screen or tmux session)
endif

debian/mmc_2g.img:
	sudo sh debian/make_debian_img.sh nocomp

dtb/rk3588-rock-5b.dtb:
	sh dtb/make_dtb.sh cp

kernel/linux-image-*_arm64.deb:
	sh kernel/make_kernel.sh

uboot/idbloader.img uboot/u-boot.itb:
	sh uboot/make_uboot.sh cp


.PHONY: debian dtb kernel uboot all package-* clean screen


