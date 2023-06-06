## linux device tree for the rock-5b

<br/>

**build device the tree for the rock-5b**
```
sh make_dtb.sh
```

<i>the build will produce the target file rk3588-rock-5b.dtb</i>

<br/>

**optional: create symbolic links**
```
sh make_dtb.sh links
```

<i>convenience link to rk3588-rock-5b.dts and other relevant device tree files will be created in the project directory</i>

<br/>

**optional: clean target**
```
sh make_dtb.sh clean
```

