## u-boot v2024.01-rc4 for the rock-5b

<i>Note: This script is intended to be run from a 64 bit arm device such as a rock-5b or an odroid m1.</i>

<br/>

**1. build u-boot images for the rock-5b**
```
sh make_uboot.sh
```

<i>the build will produce the target files idbloader.img, and u-boot.itb</i>

<br/>

**2. copy u-boot to mmc or file image**
```
sudo dd bs=4K seek=8 if=idbloader.img of=/dev/sdX conv=notrunc
sudo dd bs=4K seek=2048 if=u-boot.itb of=/dev/sdX conv=notrunc,fsync
```
* note: to write to emmc while booted from mmc, use ```/dev/mmcblk1``` for ```/dev/sdX```

<br/>

**4. optional: clean target**
```
sh make_uboot.sh clean
```

<br/>

---
## booting from spi nor flash

**1. boot from removable mmc**

[Follow the instructions](https://github.com/inindev/rock-5b/blob/main/README.md#debian-bookworm-setup) for creating bootable mmc media.
Insert the mmc media and boot the device.

Note: The mmc media has a one-time reboot during first setup as it expands to the size of the mmc media.

<br/>

**2. install mtd-utils**

once linux is booted from the removable mmc, install mtd-utils
```
sudo apt update
sudo apt install mtd-utils
```

<br/>

**3. erase spi flash**
```
sudo flash_erase /dev/mtd0 0 0
sudo flash_erase /dev/mtd1 0 0
sudo flash_erase /dev/mtd2 0 0
sudo flash_erase /dev/mtd3 0 0
```

<br/>

**4. write u-boot to spi flash**
```
wget https://github.com/inindev/rock-5b/releases/download/v13-6.7-rc4/idbloader.img
wget https://github.com/inindev/rock-5b/releases/download/v13-6.7-rc4/u-boot.itb
sudo flashcp -vA idbloader.img /dev/mtd0
sudo flashcp -vA u-boot.itb /dev/mtd2
```

<br/>

Once the spi flash has been written, the boot sequence should prefer removable mmc media if present, otherwise boot m.2 nvme ssd.
