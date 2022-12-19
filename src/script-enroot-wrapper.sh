#!/usr/bin/env bash

# This script outputs a script that wraps another script
# into an enroot command

TOWRAP="$1"
[[ "$TOWRAP" =~ ^/ ]] || { echo "Needs absolute path to script to wrap." >&2; exit 22; }

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/containerlib.sh
source "$SRC"/containerlib.sh


# shellcheck disable=SC2086
{ env | grep -qE '^ENROOT'; } && declare -p ${!ENROOT*}


MOUNT="$CUSTOM_ENV_CI_BUILDS_DIR:$CUSTOM_ENV_CI_BUILDS_DIR"

if [[ ! "$TOWRAP" =~ ^"${CUSTOM_ENV_CI_BUILDS_DIR}"  ]]
then
    MOUNT="$TOWRAP":"$TOWRAP","$MOUNT"
fi

cat <<EOF
enroot start \
    --rw \
    --mount "$MOUNT" \
    -- "$CE_CONTAINER_NAME" "$TOWRAP"
EOF
