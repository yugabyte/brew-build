#!/usr/bin/env bash

# Copyright (c) YugaByte, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.  You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software distributed under the License
# is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express
# or implied.  See the License for the specific language governing permissions and limitations
# under the License.
#

set -euo pipefail

readonly COMMON_SH="${0%/*}/brew-common.sh"
. "$COMMON_SH"

# -------------------------------------------------------------------------------------------------
# Constants
# -------------------------------------------------------------------------------------------------

readonly YB_USE_SSE4=${YB_USE_SSE4:-1}
export HOMEBREW_NO_AUTO_UPDATE=1
BREW_FROM_SRC_PACKAGES=(
  autoconf
  automake
  bzip2
  flex
  gcc
  icu4c
  libtool
  ninja
  openssl
  readline
  s3cmd
)

BREW_BIN_PACKAGES=()

if [[ $OSTYPE == linux* ]]; then
  BREW_BIN_PACKAGES+=( gcc@8 libuuid )
else
  BREW_FROM_SRC_PACKAGES+=( gnu-tar )
fi

# -------------------------------------------------------------------------------------------------
# Functions
# -------------------------------------------------------------------------------------------------

brew_install_packages() {
  local package
  for package in "$@"; do
    if ( set -x; ./bin/brew install $install_args "$package" ); then
      successful_packages+=( "$package" )
    else
      log "Failed to install package: $package"
      failed_packages+=( "$package" )
    fi
  done
}

# -------------------------------------------------------------------------------------------------
# Main script
# -------------------------------------------------------------------------------------------------

if [[ ! -x ./bin/brew ]]; then
  fatal "This script should be run inside Homebrew/Linuxbrew directory."
fi

cd "$(realpath .)"
BREW_HOME=$PWD

echo
echo "============================================================================================"
echo "Building Homebrew/Linuxbrew in $BREW_HOME"
echo "YB_USE_SSE4=$YB_USE_SSE4"
echo "============================================================================================"
echo

LEN=${#BREW_HOME}
if [[ $LEN -ne $ABS_PATH_LIMIT ]]; then
  fatal "Homebrew absolute path should be exactly $ABS_PATH_LIMIT bytes, but actual length is" \
        "$LEN bytes: $BREW_HOME"
fi

openssl_formula=./Library/Taps/homebrew/homebrew-core/Formula/openssl.rb
openssl_orig=./Library/Taps/homebrew/homebrew-core/Formula/openssl.rb.orig

if [[ ! -e "$openssl_orig" ]]; then
  # Run brew info, so that brew downloads the openssl formula which we want to patch.
  ./bin/brew info openssl >/dev/null
  cp "$openssl_formula" "$openssl_orig"
fi

sse4_flags=""
if [[ $YB_USE_SSE4 == "0" ]]; then
  echo "YB_USE_SSE4=$YB_USE_SSE4, disabling use of SSE4"
  sse4_flags="-mno-sse4.1 -mno-sse4.2"
  export HOMEBREW_ARCH="core2"
else
  echo "YB_USE_SSE4=$YB_USE_SSE4, enabling use of SSE4"
  # export HOMEBREW_ARCH="ivybridge"
  # https://arnon.dk/which-architecture-should-i-compile-for/
  # Ivy Bridge (Intel iN 3XXX and Xeons E3-12xx v2-series, E5-14xx v2/24xx v2-series, E5-16xx
  # v2/26xx v2/46xx v2-series, E7-28xx v2/48xx v2/88xx v2-series) – -march=core-avx-i
  export HOMEBREW_ARCH="core-avx-i"
fi

extra_flags="-mno-avx -mno-bmi -mno-bmi2 -mno-fma -no-abm -no-movbe"

cp "$openssl_orig" "$openssl_formula"
openssl_rb_extra_line="args += %w[-march=$HOMEBREW_ARCH $extra_flags $sse4_flags]"
if [[ $OSTYPE == linux* ]]; then
  cat <<EOF | patch "$openssl_formula"
@@ -61,6 +61,7 @@ class Openssl < Formula
       end
       args << "enable-md2"
     end
+    $openssl_rb_extra_line
     system "perl", "./Configure", *args
     system "make", "depend"
     system "make"
EOF
else
  cat <<EOF | patch "$openssl_formula"
diff --git a/Formula/openssl.rb b/Formula/openssl.rb
index 5810436..83b213d 100644
--- a/Formula/openssl.rb
+++ b/Formula/openssl.rb
@@ -38,6 +38,7 @@ class Openssl < Formula
       darwin64-x86_64-cc
       enable-ec_nistp_64_gcc_128
     ]
+    $openssl_rb_extra_line
     system "perl", "./Configure", *args
     system "make", "depend"
     system "make"
EOF
fi
unset sse4_flags

# -------------------------------------------------------------------------------------------------
# Package installation
# -------------------------------------------------------------------------------------------------

if [[ ${YB_BREW_BUILD_UNIT_TEST_MODE:-0} == "1" ]]; then
  BREW_FROM_SRC_PACKAGES=()
  BREW_BIN_PACKAGES=( patchelf )
fi

successful_packages=()
failed_packages=()

install_args=""
if [[ ${#BREW_BIN_PACKAGES[@]} -gt 0 ]]; then
  brew_install_packages "${BREW_BIN_PACKAGES[@]}"
fi
install_args="--build-from-source"
if [[ ${#BREW_FROM_SRC_PACKAGES[@]} -gt 0 ]]; then
  brew_install_packages "${BREW_FROM_SRC_PACKAGES[@]}"
fi
unset install_args

log "Successfully installed packages: ${successful_packages[*]}"

if [[ ${#failed_packages[@]} -gt 0 ]]; then
  fatal "Failed to install packages: ${failed_packages[*]}"
fi

if [[ ! -e VERSION_INFO ]]; then
  commit_id=$(git rev-parse HEAD)
  echo "Homebrew/Linuxbrew commit ID: $commit_id" >VERSION_INFO.tmp
  pushd Library/Taps/homebrew/homebrew-core
  commit_id=$(git rev-parse HEAD)
  popd
  echo "homebrew-core commit ID: $commit_id" >>VERSION_INFO.tmp
  mv VERSION_INFO.tmp VERSION_INFO
fi

log "Updating symlinks ..."
find . -type l | while read f
do
  target=$(readlink "$f")
  if [[ -e $f ]]; then
    real_target=$(realpath "$f")
    if [[ $real_target != $BREW_HOME* && $real_target != $target ]]; then
      # We want to convert relative links pointing outside of Homebrew/Linuxbrew to absolute links.
      # -f to allow relinking. -T to avoid linking inside directory if $f already exists as
      # directory.
      create_symlink "$real_target" "$f"
    fi
  else
    log "Link $f seems broken"
  fi
done

log "Preparing list of files to be patched during installation ..."
find ./Cellar -type f | while read f
do
  if grep -q "$BREW_HOME" "$f"; then
    echo "$f"
  fi
done | sort >FILES_TO_PATCH

find . -type l | while read f
do
  if [[ -e "$f" && $(readlink "$f") == $BREW_HOME* ]]; then
    echo "$f"
  fi
done | sort >LINKS_TO_PATCH

for repo_dir in "" Library/Taps/*/*; do
  (
    cd "$repo_dir"
    log "Creating GIT_SHA1 and GIT_URL files in directory $PWD"
    git rev-parse HEAD >GIT_SHA1
    log "Git SHA1: $( cat GIT_SHA1 )"
    git remote -v | egrep '^origin.*[(]fetch[)]$' | awk '{print $2}' >GIT_URL
    log "Git URL: $( cat GIT_URL )"
  )
done

BREW_HOME_ESCAPED=$(get_escaped_sed_replacement_str "$BREW_HOME")

cp "$COMMON_SH" .
sed "s/{{ orig_brew_home }}/$BREW_HOME_ESCAPED/g" "${0%/*}/post_install.template" >post_install.sh
chmod +x post_install.sh

brew_home_dir=${BREW_HOME##*/}
distr_name=${brew_home_dir%-*}
archive_name=$distr_name.tar.gz
distr_path=$(realpath "../$archive_name")
echo "Preparing Homebrew/Linuxbrew distribution archive: $distr_path ..."
distr_name_escaped=$(get_escaped_sed_replacement_str "$distr_name" "%")
run_tar zcf "$distr_path" --exclude ".git" --transform s%^./%$distr_name_escaped/% .
pushd ..
sha256sum "$archive_name" >$archive_name.sha256
popd
log "Done"
