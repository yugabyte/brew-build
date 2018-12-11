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

show_help() {
  cat >&2 <<-EOT
linuxbrew-copy.sh creates a copy of linuxbrew installation in current directory and updates \
it with new linuxbrew home path.
Usage: ${0##*/} <source linux brew home path>
EOT
  exit 1
}

if [[ $# -lt 1 ]]; then
  show_help
fi

SRC_BREW_HOME=$(realpath $1)
[[ -x $SRC_BREW_HOME/bin/brew ]] || \
  (echo "<source linux brew home path> should point to Linuxbrew directory."; show_help)

BREW_DIRNAME="linuxbrew-$(date +%Y%m%dT%H%M%S)"
BREW_LINK="$(realpath .)/$BREW_DIRNAME"
LEN=${#BREW_LINK}
[[ $LEN -le $ABS_PATH_LIMIT ]] || (echo "Linuxbrew link absolute path should be no more than\
 $ABS_PATH_LIMIT bytes, but actual length is $LEN bytes: $BREW_LINK"; exit 1)

BREW_HOME=$(echo "$BREW_LINK-$(head -c $ABS_PATH_LIMIT </dev/zero | tr '\0' x)" | \
  cut -c-$ABS_PATH_LIMIT)

echo "Copying to $BREW_HOME ..."
mkdir -p "$BREW_HOME"
rsync -rlH "$SRC_BREW_HOME/" "$BREW_HOME/"

echo "Patching files ..."
find "$BREW_HOME" -type f | while read f
do
  sed -i --binary "s%$SRC_BREW_HOME%$BREW_HOME%g" "$f"
done

echo "Updating symlinks ..."
find "$BREW_HOME" -type l | while read f
do
  target="$(readlink "$f")"
  if [[ "$target" == "$SRC_BREW_HOME"* ]]; then
    target="${target/$SRC_BREW_HOME/$BREW_HOME}"
    ln -sfT "$target" "$f"
  fi
done
echo "Done"

ln -s "$BREW_HOME" "$BREW_LINK"
echo "Created link: $BREW_LINK -> $BREW_HOME"
