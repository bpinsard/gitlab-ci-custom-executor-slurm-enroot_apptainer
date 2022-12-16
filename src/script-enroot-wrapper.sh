#!/usr/bin/env bash

# This script outputs a script that wraps another script
# into an enroot command

TOWRAP="$1"

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/containerlib.sh
source "$SRC"/containerlib.sh

# shellcheck disable=SC2086
{ env | grep -qE '^ENROOT'; } && declare -p ${!ENROOT*}

cat <<EOF
# TODO: fix this
enroot start -- $TOWRAP

EOF
