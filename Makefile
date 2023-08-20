
LDIST ?= $(shell cat "debian/make_debian_img.sh" | sed -n 's/\s*local deb_dist=.\([[:alpha:]]\+\)./\1/p')


all: uboot dtb debian kernel
	@echo "all binaries ready"

debian: uboot dtb debian/mmc_2g.img
	@echo "debian image ready"

dtb: dtb/rk3588-rock-5b.dtb
	@echo "device tree binaries ready"

kernel: kernel/linux-image-*_arm64.deb
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

debian/mmc_2g.img:
	sudo sh debian/make_debian_img.sh nocomp

dtb/rk3588-rock-5b.dtb:
	sh dtb/make_dtb.sh cp

kernel/linux-image-*_arm64.deb:
	@echo need to build kernel
#	sh kernel/make_kernel.sh

uboot/idbloader.img uboot/u-boot.itb:
	sh uboot/make_uboot.sh cp


.PHONY: debian dtb uboot all package-* clean

