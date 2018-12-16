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

show_help_and_exit() {
  cat >&2 <<-EOT
linuxbrew-copy.sh creates a copy of linuxbrew installation in current directory and updates \
it with new linuxbrew home path.
Usage: ${0##*/} <source_linuxbrew_home_path>
EOT
  exit 1
}

if [[ $# -lt 1 ]]; then
  show_help_and_exit
fi

SRC_BREW_HOME=$(realpath $1)
if [[ ! -x $SRC_BREW_HOME/bin/brew ]]; then
  echo "<source linux brew home path> should point to Linuxbrew directory." >&2
  show_help_and_exit
fi

BREW_LINK=$(get_brew_link)
BREW_HOME=$(get_fixed_length_path "$BREW_LINK")

echo "Copying to $BREW_HOME ..."
mkdir -p "$BREW_HOME"
# Recursively copy files tree, copy symlinks as symlinks, preserve hard links.
rsync -rlH "$SRC_BREW_HOME/" "$BREW_HOME/"

echo "Patching files ..."
SRC_BREW_HOME_ESCAPED=$(get_escaped_sed_re "$SRC_BREW_HOME")
BREW_HOME_ESCAPED=$(get_escaped_sed_replacement_str "$BREW_HOME")

find "$BREW_HOME" -type f | while read f
do
  sed -i --binary "s/$SRC_BREW_HOME_ESCAPED/$BREW_HOME_ESCAPED/g" "$f"
done

echo "Updating symlinks ..."
find "$BREW_HOME" -type l | while read f
do
  target=$(readlink "$f")
  if [[ $target == $SRC_BREW_HOME* ]]; then
    target="${target/$SRC_BREW_HOME/$BREW_HOME}"
    # -f to allow relinking. -T to avoid linking inside directory if $f already exists as directory.
    ln -sfT "$target" "$f"
  fi
done
echo "Done"

ln -s "$BREW_HOME" "$BREW_LINK"
echo "Created link: $BREW_LINK -> $BREW_HOME"
