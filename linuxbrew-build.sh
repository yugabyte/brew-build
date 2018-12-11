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

. "${0%/*}/linuxbrew-common.sh"

export HOMEBREW_NO_AUTO_UPDATE=1

[[ -x ./bin/brew ]] || (echo "This script should be run inside Linuxbrew directory."; exit 1)

cd "$(realpath .)"
BREW_HOME=$PWD

LEN=${#BREW_HOME}
[[ $LEN -eq $ABS_PATH_LIMIT ]] || (echo "Linuxbrew absolute path should be exactly $ABS_PATH_LIMIT \
 bytes, but actual length is $LEN bytes: $BREW_HOME"; exit 1)

export HOMEBREW_ARCH=ivybridge

openssl_formula=./Library/Taps/homebrew/homebrew-core/Formula/openssl.rb
openssl_orig=./Library/Taps/homebrew/homebrew-core/Formula/openssl.rb.orig

if [[ ! -e "$openssl_orig" ]]; then
  # Run brew info, so brew download openssl formula which we want to patch.
  ./bin/brew info openssl >/dev/null
  cp "$openssl_formula" "$openssl_orig"
fi

cp "$openssl_orig" "$openssl_formula"
cat <<EOF | patch -n "$openssl_formula"
4c4
< class Openssl < Formula
---
> class Openssl < Formula
40c40,41
<       :x86_64 => %w[linux-x86_64],
---
>       :x86_64 => %w[linux-x86_64
>                     -march=ivybridge -mno-avx -mno-bmi -mno-bmi2 -mno-fma -no-abm -no-movbe],
EOF

./bin/brew install autoconf automake bzip2 flex gcc icu4c libtool libuuid maven ninja openssl \
readline s3cmd

if [[ ! -e VERSION_INFO ]]; then
  commit_id=$(git rev-parse HEAD)
  echo "Linuxbrew commit ID: $commit_id" >VERSION_INFO.tmp
  pushd $(pwd)
  cd Library/Taps/homebrew/homebrew-core
  commit_id=$(git rev-parse HEAD)
  popd
  echo "homebrew-core commit ID: $commit_id" >>VERSION_INFO.tmp
  mv VERSION_INFO.tmp VERSION_INFO
fi

echo "Updating symlinks ..."
find . -type l | while read f
do
  target="$(readlink "$f")"
  real_target="$(realpath "$f")"
  if [[ "$real_target" != "$BREW_HOME"* && "$real_target" != "$target" ]]; then
    # We want to convert relative links pointing outside of Linuxbrew to absolute links.
    ln -sfT "$real_target" "$f"
  fi
done

echo "Preparing list of files to be patched during installation ..."
find ./Cellar -type f | while read f
do
  if grep -q "$BREW_HOME" "$f"; then
    echo "$f"
  fi
done | sort >FILES_TO_PATCH

find . -type l | while read f
do
  if [[ "$(readlink "$f")" == "$BREW_HOME"* ]]; then
    echo "$f"
  fi
done | sort >LINKS_TO_PATCH

cat <<EOF >post_install.sh
#!/usr/bin/env bash

set -euo pipefail

BREW_HOME="\${0%/*}"
[[ -x \$BREW_HOME/bin/brew ]] || \
  (echo "This script should be located inside Linuxbrew directory."; exit 1)

ORIG_BREW_HOME="$BREW_HOME"
ORIG_LEN=\${#ORIG_BREW_HOME}

BREW_HOME="\$PWD"
LEN=\${#BREW_HOME}
[[ \$LEN -le \$ORIG_LEN ]] || (echo "Linuxbrew absolute path should be no more than \$ORIG_LEN \
bytes, but actual length is \$LEN bytes: \$BREW_HOME"; exit 1)

BREW_LINK="\$(echo "\$BREW_HOME-\$(head -c \$ORIG_LEN </dev/zero | tr '\0' x)" | \
  cut -c-\$ORIG_LEN)"
LINK_LEN=\${#BREW_LINK}
[[ \$LINK_LEN == \$ORIG_LEN ]] || (echo "Linuxbrew should be linked to a directory having absolute path \
length of \$ORIG_LEN bytes, but actual length is \$LINK_LEN bytes: \$BREW_LINK"; exit 1)

ln -sfT "\$BREW_HOME" "\$BREW_LINK"

cat FILES_TO_PATCH | while read f
do
  sed -i --binary "s%\$ORIG_BREW_HOME%\$BREW_LINK%g" "\$f"
done

cat LINKS_TO_PATCH | while read f
do
  target="\$(readlink "\$f")"
  target="\${target/\$ORIG_BREW_HOME/\$BREW_LINK}"
  ln -sfT "\$target" "\$f"
done
EOF
chmod +x post_install.sh

brew_home_dir=${BREW_HOME##*/}
distr_name="${brew_home_dir%-*}"
distr_path="$(realpath ../$distr_name.tar.gz)"
echo "Preparing Linuxbrew distribution archive: $distr_path ..."
tar zcf "$distr_path" . --transform s#^./#$distr_name/# --exclude ".git"
echo "Done"
