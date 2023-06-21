## linux kernel for the rock-5b

<i>Note: This script is intended to be run from a 64 bit arm device such as an odroid m1 or a raspberry pi4.</i>

<br/>

**start a screen session**
```
screen
```

<i>* note: the kernel build takes 40 minutes on a rock 5b, and multiple hours on an odroid m1</i><br/>
<i>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;therefore, it is important to run the build from a screen session so it is not interrupted</i>

<br/>

**build the kernel**
```
sh make_kernel.sh
```

<i>* note: kernel .deb package is linked in the ```kernel``` directory when the build finishes successfully</i>

<br/>

**install the kernel to mmc image**
```
cd ../debian
sudo sh install_kernel.sh
```

<br/>

