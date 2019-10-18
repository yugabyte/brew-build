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

# This script creates a new Homebrew/Linuxbrew directory by cloning the upstream GitHub repository.
# The directory path is chosen to be of a fixed length, and a more human-readable symlink is created
# to point to the resulting directory.

set -euo pipefail

. "${0%/*}/brew-common.sh"

get_brew_path_prefix
if [[ -d $brew_path_prefix ]]; then
  fatal "Directory $brew_path_prefix already exists, cannot clone the repo."
fi

git clone https://github.com/Homebrew/brew "$brew_path_prefix"
get_fixed_length_path "$brew_path_prefix"
brew_home=$fixed_length_path
if [[ -d $brew_home ]]; then
  if [[ $brew_prefix_path == $brew_home ]]; then
    log "Directory path $brew_home is already of correct length."
  elif [[ ${YB_BREW_REUSE_PREBUILT:-} == "1" ]]; then
    log "Directory $brew_home already exists, will reuse it."
    rm -rf "$brew_path_prefix"
  else
    fatal "Directory $brew_home already exists!"
  fi
else
  mv "$brew_path_prefix" "$brew_home"
  ln -sfT "${brew_home##*/}" "$brew_path_prefix"
fi

echo "$brew_home" >"$brew_home/ORIG_BREW_HOME"
( cd "$brew_home" && git rev-parse HEAD ) >"$brew_home/GIT_SHA1"

echo "$brew_home" >latest_brew_clone_dir.txt
echo "$brew_path_prefix" >latest_brew_path_prefix.txt
