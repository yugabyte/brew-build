# brew-build

This set of wrappers scripts allows to build a customized version of Homebrew/Linuxbrew used by the
YugaByte DB build process. We pre-install the Homebrew/Linuxbrew packages that we need, built with
the appropriate compiler flags. We ensure that the full path to the root directory of the
Homebrew/Linuxbrew installation is long enough so that we can replace it in place with a different
path by patching binaries on the destination machine. This patching is done as part of the
[`post_install.sh`](https://github.com/YugaByte/yugabyte-db/blob/master/build-support/post_install.sh)
script.  This allows glibc and other libraries to properly locate files such as locales that are
referenced using hard-coded parts.

## Using the scripts

```
mkdir -p ~/code
cd ~/code
git clone https://github.com/yugabyte/brew-build.git

mkdir -p ~/brew_versions
cd ~/code/brew_versions
~/code/brew-build/brew-clone-and-build-all.sh
```

This will build both SSE4-enabled and SSE4-disabled versions of Homebrew/Linuxbrew.
