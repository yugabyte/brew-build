# linuxbrew-build

This set of wrappers scripts allows to build a customized version of Linuxbrew used by the YugaByte DB
build process. We pre-install the Linuxbrew packages that we need, built with the appropriate compiler
flags. We ensure that the root directory of the Linuxbrew installation is long enough so that we can
replace it with a different path and patch binaries in place on the destination machine. This allows
all hard-coded paths to work properly.

## Using the scripts

Suppose these scripts are checked out to `~/code/linuxbrew-build` and we also have a scratch space
directory `/share/linuxbrew` where we will do our build.

``bash
cd /share/linuxbrew
~/code/linuxbrew-build/linuxbrew-clone.sh
```

This will produce a directory named like `linuxbrew-20190415T234057`. 
Now let's build Linuxbrew packages there:

```
cd "$( ls -td linuxbrew-* | head -1 )"
~/code/linuxbrew-build/linuxbrew-build.sh
```
