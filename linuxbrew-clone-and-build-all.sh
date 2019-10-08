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

export HOMEBREW_CACHE=$PWD/brew_cache
export HOMEBREW_LOGS=$PWD/brew_logs

set_brew_timestamp

time (
  for YB_USE_SSE4 in 0 1; do
    export YB_USE_SSE4
    if [[ $YB_USE_SSE4 == "1" ]]; then
      export YB_BREW_SUFFIX=""
    else
      export YB_BREW_SUFFIX="nosse4"
    fi
    rm -f "latest_brew_clone_dir.txt"
    "$YB_LINUXBREW_BUILD_ROOT"/linuxbrew-clone.sh
    set -x
    brew_home=$( cat "latest_brew_clone_dir.txt" )
    brew_path_prefix=$( cat "latest_brew_path_prefix.txt" )
    archive_path=$brew_path_prefix.tar.gz
    if [[ -d $brew_home && -e $archive_path ]]; then
      if [[ ${YB_BREW_REUSE_PREBUILT:-} == "1" ]]; then
        log "File $archive_path already exists, will not rebuild."
        continue
      else
        fatal "File $archive_path already exists"
      fi
    fi
    (
      set -x
      cd "$brew_home"
      time "$YB_LINUXBREW_BUILD_ROOT"/linuxbrew-build.sh
    )
  done
)
