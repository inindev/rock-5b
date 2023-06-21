## debian bookworm linux for the rock-5b

<i>Note: This script is intended to be run from a 64 bit arm device such as an odroid m1 or a raspberry pi4.</i>

<br/>

**build debian bookworm using debootstrap**
```
sudo sh make_debian_img.sh nocomp
```

<i>the build will produce the target file ```mmc_2g.img```</i>

<br/>

**install the kernel**
```
sudo sh install_kernel.sh
```

<i>* note: kernel .deb package needs to be built and available in the ```../kernel``` directory</i>

<br/>

**copy the image to mmc media**
```
sudo su
cat mmc_2g.img > /dev/sdX
sync
```

<br/>

**multiple build options are available by editing make_debian_img.sh**
```
media='mmc_2g.img' # or block device '/dev/sdX'
deb_dist='bookworm'
hostname='rock5b-arm64'
acct_uid='debian'
acct_pass='debian'
disable_ipv6=true
extra_pkgs='curl, pciutils, sudo, u-boot-tools, unzip, wget, xxd, xz-utils, zip, zstd'
```
