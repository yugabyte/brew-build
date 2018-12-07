#!/usr/bin/env bash
set -euo pipefail

ABS_PATH_LIMIT=85

BREW_DIRNAME="linuxbrew-$(date +%Y%m%dT%H%M%S)"
BREW_LINK="$(realpath .)/$BREW_DIRNAME"
LEN=${#BREW_LINK}
[[ $LEN -le $ABS_PATH_LIMIT ]] || (echo "Linuxbrew link absolute path should be no more than\
 $ABS_PATH_LIMIT bytes, but actual length is $LEN bytes: $BREW_LINK"; exit 1)

BREW_HOME=$(echo "$BREW_LINK-$(head -c $ABS_PATH_LIMIT </dev/zero | tr '\0' x)" | \
  cut -c-$ABS_PATH_LIMIT)
git clone https://github.com/Linuxbrew/brew.git "$BREW_HOME"
ln -s "$BREW_HOME" "$BREW_LINK"
echo "Created link: $BREW_LINK -> $BREW_HOME"
