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

export HOMEBREW_CACHE=$PWD/linuxbrew_cache
export HOMEBREW_LOGS=$PWD/linuxbrew_logs

"$YB_LINUXBREW_BUILD_ROOT"/linuxbrew-clone.sh

BREW_HOME=$( cat "latest_brew_home.txt" )
BREW_HOME_BASENAME=${BREW_HOME##*/}
BREW_LINK=$( cat "latest_brew_link.txt" )
BREW_LINK_NOSSE4=$BREW_LINK-nosse4
BREW_HOME_NOSSE4=$( get_fixed_length_path "$BREW_LINK_NOSSE4" )
(
  set -x
  cp -R "$BREW_HOME" "$BREW_HOME_NOSSE4"
  ln -s "$BREW_HOME_NOSSE4" "$BREW_LINK_NOSSE4"
)

logs_dir=$PWD/logs
mkdir -p "$logs_dir"
log_path=$logs_dir/$BREW_HOME_BASENAME.log
echo "Writing log to $log_path"
(
  time (
    for YB_USE_SSE4 in 1 0; do
      export YB_USE_SSE4
      if [[ $YB_USE_SSE4 == "1" ]]; then
        current_brew_home=$BREW_HOME
      else
        current_brew_home=$BREW_HOME_NOSSE4
      fi
      (
        set -x
        cd "$current_brew_home"
        time "$YB_LINUXBREW_BUILD_ROOT"/linuxbrew-build.sh
      )
    done
  )
) 2>&1 | tee "$log_path"

echo "Log available at $log_path"
