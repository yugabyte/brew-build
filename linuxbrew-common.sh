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
  if [[ $len -gt $ABS_PATH_LIMIT ]]; then
    echo "Linuxbrew link absolute path should be no more than $ABS_PATH_LIMIT bytes, but actual" \
         "length is $len bytes: $brew_link" >&2
    exit 1
  fi
  echo "$brew_link"
}

# Prepend 'x' symbols to source path up to specified length.
# Parameters:
#   path - source path.
#   len - required output path length. Optional parameter, if absent uses $ABS_PATH_LIMIT.
get_fixed_length_path() {
  local path="$1"
  local len="${2:-$ABS_PATH_LIMIT}"
  # Take $len number of '\0' from /dev/zero, replace '\0' with 'x', then prepend to
  # "$brew_link-" and keep first $len symbols, so we have a path of a fixed length.
  echo "$path-$(head -c $len </dev/zero | tr '\0' x)" | cut -c-$len
}

# Escape special characters in source string, so it can be used with sed as simple string pattern.
# https://stackoverflow.com/a/28783790/461529
# https://stackoverflow.com/a/29613573/461529
get_escaped_sed_re() {
  # Every character except ^ is placed in its own character set [...] expression to treat it as a
  # literal. Then, ^ characters are escaped as \^.
  sed 's/[^^]/[&]/g; s/\^/\\^/g' <<<$1
}

# Escape special characters in source string, so it can be used with sed as a replacement string.
# https://stackoverflow.com/a/28783790/461529
# https://stackoverflow.com/a/29613573/461529
get_escaped_sed_replacement_str() {
  # The replacement string in a sed s/// command is not a regex, but it recognizes placeholders
  # that refer to either the entire string matched by the regex (&) or specific capture-group
  # results by index (\1, \2, ...), so these must be escaped, along with the (customary) regex
  # delimiter, /.
  local delim=${2:-/}
  sed "s/[$delim&\]/\\\\&/g" <<<$1
}
