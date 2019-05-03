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

BREW_LINK=$(get_brew_link)
BREW_HOME=$(get_fixed_length_path "$BREW_LINK")
git clone https://github.com/Homebrew/brew.git "$BREW_HOME"
ln -s "$BREW_HOME" "$BREW_LINK"
echo "Created link: $BREW_LINK -> $BREW_HOME"

echo "$BREW_HOME" >latest_brew_home.txt
echo "$BREW_LINK" >latest_brew_link.txt
