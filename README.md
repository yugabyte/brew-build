# linuxbrew-build

This set of wrappers scripts allows to build a customized version of Linuxbrew used by the YugaByte DB
build process. We pre-install the Linuxbrew packages that we need, built with the appropriate compiler
flags. We ensure that the full path to the root directory of the Linuxbrew installation is long enough so that we can
replace it in place with a different path by patching binaries on the destination machine. This patching
is done as part of the [`post_install.sh`](https://github.com/YugaByte/yugabyte-db/blob/master/build-support/post_install.sh) script.
This allows glibc and other libraries to properly locate files such as locales that are referenced using hard-coded parts.

## Using the scripts

```
mkdir -p ~/code
cd ~/code
git clone https://github.com/yugabyte/linuxbrew-build.git

mkdir -p ~/linuxbrew_versions
~/code/linuxbrew-build/linuxbrew-clone-and-build-all.sh
```

This will build both SSE4-enabled and SSE4-disabled versions of Linuxbrew.
