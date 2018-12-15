#@IgnoreInspection BashAddShebang

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

if [[ $BASH_SOURCE == $0 ]]; then
  echo "$BASH_SOURCE must be sourced, not executed" >&2
  exit 1
fi

declare -i -r ABS_PATH_LIMIT=85

get_brew_link() {
  local brew_dirname="linuxbrew-$(date +%Y%m%dT%H%M%S)"
  local brew_link="$(realpath .)/$brew_dirname"
  local len=${#brew_link}
  [[ $len -le $ABS_PATH_LIMIT ]] || (echo "Linuxbrew link absolute path should be no more than\
 $ABS_PATH_LIMIT bytes, but actual length is $len bytes: $brew_link"; exit 1)
  echo $brew_link
}

get_brew_fixed_length_home_path() {
  local brew_link="$1"
  echo "$brew_link-$(head -c $ABS_PATH_LIMIT </dev/zero | tr '\0' x)" | \
    cut -c-$ABS_PATH_LIMIT
}