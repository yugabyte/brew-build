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

# This script creates a new Linuxbrew directory by cloning the upstream GitHub repository. The
# directory path is chosen to be of a fixed length, and a more human-readable symlink is created
# to point to the resulting directory.

set -euo pipefail

. "${0%/*}/linuxbrew-common.sh"

brew_path_prefix=$(get_brew_path_prefix)
if [[ -d $brew_path_prefix ]]; then
  fatal "Directory $brew_path_prefix already exists, cannot clone the repo."
fi

set -x
git clone https://github.com/Homebrew/brew "$brew_path_prefix"
brew_home=$(get_fixed_length_path "$brew_path_prefix")
if [[ -d $brew_home ]]; then
  if [[ ${YB_BREW_REUSE_PREBUILT:-} == "1" ]]; then
    log "Directory $brew_home already exists, will reuse it."
    rm -rf "$brew_path_prefix"
  else
    fatal "Directory $brew_home already exists!"
  fi
else
  mv "$brew_path_prefix" "$brew_home"
fi

echo "$brew_home" >latest_brew_clone_dir.txt
echo "$brew_path_prefix" >latest_brew_path_prefix.txt
