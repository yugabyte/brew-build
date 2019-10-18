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

. "${0%/*}/brew-common.sh"

readonly script_name=${BASH_SOURCE##*/}

show_help_and_exit() {
  cat >&2 <<-EOT
$script_name creates a copy of Homebrew/Linuxbrew installation in current directory and updates \
it with new Homebrew/Linuxbrew home path.
Usage: ${0##*/} <source_brew_home_path>
EOT
  exit 1
}

if [[ $# -lt 1 ]]; then
  show_help_and_exit
fi

if [[ -z "$1" ]]; then
  fatal "Empty path specified"
fi

SRC_BREW_HOME=$(realpath "$1")
if [[ ! -x $SRC_BREW_HOME/bin/brew ]]; then
  fatal "<source_brew_home_path> should point to a Homebrew/Linuxbrew directory."
fi

git_sha1_path="$SRC_BREW_HOME/GIT_SHA1"
if [[ ! -f $git_sha1_path ]]; then
  fatal "File '$git_sha1_path' not found"
fi
git_sha1=$( cat "$git_sha1_path" )
get_brew_path_prefix
BREW_LINK=$brew_path_prefix
get_fixed_length_path "$BREW_LINK" "$ABS_PATH_LIMIT" "$git_sha1"
BREW_HOME=$fixed_length_path
if [[ -e $BREW_HOME ]]; then
  fatal "Directory or file '$BREW_HOME' already exists"
fi

log "Copying existing Homebrew/Linuxbrew installation from $SRC_BREW_HOME to $BREW_HOME"

(
  set -x
  mkdir -p "$BREW_HOME"

  # Recursively copy files tree, copy symlinks as symlinks, preserve hard links.
  time rsync -rlH "$SRC_BREW_HOME/" "$BREW_HOME/"
)

log "Patching files ..."
SRC_BREW_HOME_ESCAPED=$(get_escaped_sed_re "$SRC_BREW_HOME")
BREW_HOME_ESCAPED=$(get_escaped_sed_replacement_str "$BREW_HOME")


find "$BREW_HOME" -type f | while read f
do
  # Regarding LC_ALL=C:
  # https://stackoverflow.com/questions/19242275/re-error-illegal-byte-sequence-on-mac-os-x
  LC_ALL=C sed -i --binary "s/$SRC_BREW_HOME_ESCAPED/$BREW_HOME_ESCAPED/g" "$f"
done

echo "Updating symlinks ..."
find "$BREW_HOME" -type l | while read f
do
  target=$(readlink "$f")
  if [[ $target == $SRC_BREW_HOME* ]]; then
    target="${target/$SRC_BREW_HOME/$BREW_HOME}"
    # -f to allow relinking. -T to avoid linking inside directory if $f already exists as directory.
    create_symlink "$target" "$f"
  fi
done
echo "Done"

create_symlink "$BREW_HOME" "$BREW_LINK"
echo "Created link: $BREW_LINK -> $BREW_HOME"
