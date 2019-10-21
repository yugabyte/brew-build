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

show_usage() {
  cat <<-EOT
Usage: ${0##*/} [<options>]
Options:
  -h, --help
    Show usage
  --work-dir <work_dir>
    Use the given work directory instead of a temporary directory. The directory will be kept at
    the end.
  --sse4-only
    Only build the configuration supporting SSE4.
EOT
}

script_dir=$( cd "${0%/*}" && pwd )
. "$script_dir/brew-common.sh"

cleanup() {
  exit_code=$?
  if "$delete_work_dir" && [[ -n ${work_dir:-} ]]; then
    cd /tmp
    log "Removing temporary directory: $work_dir"
    rm -rf "$work_dir"
  fi
  if [[ $exit_code -ne 0 ]]; then
    log "TEST FAILED, exit code: $exit_code"
  fi
  exit "$exit_code"
}

find_latest_brew_dir() {
  latest_brew_dir=$(
    ls -td $(
      find . -mindepth 1 -maxdepth 1 -type d -name "$YB_BREW_TYPE_LOWERCASE-*"
    ) | head -1
  )
  if [[ ! -d $latest_brew_dir ]]; then
    log "In directory $PWD, found latest brew directory: $latest_brew_dir"
    ( set -x; ls -l )
    fatal "Unable to find the latest Homebrew/Linuxbrew installation in $PWD"
  fi
  latest_brew_dir=$( cd "$latest_brew_dir" && pwd )
}

# -------------------------------------------------------------------------------------------------
# Parsing command-line arguments
# -------------------------------------------------------------------------------------------------

delete_work_dir=true
while [[ $# -gt 0 ]]; do
  case $1 in
    --work-dir)
      work_dir=$2
      delete_work_dir=false
      shift
    ;;
    -h|--help)
      show_usage
      exit
    ;;
    --sse4-only)
      export YB_BREW_BUILD_SSE4_ONLY=1
    ;;
    *)
      echo "Invalid argument: $1" >&2
      exit 1
  esac
  shift
done

# -------------------------------------------------------------------------------------------------
# Main script
# -------------------------------------------------------------------------------------------------

delete_work_dir=true
if [[ -z ${work_dir:-} ]]; then
  if [[ $OSTYPE == linux* ]]; then
    tmp_dir=/tmp
  else
    # If we try to use /tmp on macOS, Homebrew says:
    # "Your HOMEBREW_PREFIX is in the Homebrew temporary directory"
    # (https://github.com/Homebrew/brew/blob/master/Library/Homebrew/brew.sh).
    # So we use ~/tmp.
    tmp_dir=$HOME/tmp
    mkdir -p "$tmp_dir"
  fi
  work_dir=$tmp_dir/ybbrewtst-$$-$(date +%Y%m%dT%H%M)
  trap cleanup EXIT
fi
mkdir -p "$work_dir"
cd "$work_dir"

export YB_BREW_BUILD_UNIT_TEST_MODE=1
"$script_dir/brew-clone-and-build-all.sh"

find_latest_brew_dir
brew_home=$latest_brew_dir
log "Will use the directory $brew_home for further testing"

heading "Testing post_install.sh"

( set -x; cd /; rm -rf "$brew_home/.git"; "$brew_home/post_install.sh" )

heading "Testing brew-copy.sh"

if [[ -z $brew_home ]]; then
  fatal "Could not find a subdirectory starting with '$YB_BREW_TYPE_LOWERCASE-' in $PWD"
fi
"$script_dir/brew-copy.sh" "$brew_home"

heading "Testing post_install.sh after brew-copy.sh"
find_latest_brew_dir
if [[ $latest_brew_dir == $brew_home ]]; then
  fatal "brew-copy.sh failed to produce a new Homebrew/Linuxbrew directory in $PWD"
fi
( set -x; "$latest_brew_dir/post_install.sh" )

log "TEST SUCCEEDED"
