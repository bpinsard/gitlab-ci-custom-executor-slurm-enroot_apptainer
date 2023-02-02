#!/usr/bin/env bash

# This script outputs a script that wraps another script
# into an enroot command

TOWRAP="$1"
[[ "$TOWRAP" =~ ^/ ]] || { echo "Needs absolute path to script to wrap." >&2; exit 22; }

MOUNT="$CUSTOM_ENV_CI_WS:$CUSTOM_ENV_CI_WS"

if [[ ! "$TOWRAP" =~ ^"${CUSTOM_ENV_CI_WS}"  ]]
then
    MOUNT="$TOWRAP":"$TOWRAP","$MOUNT"
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/enroot-containerlib.sh
source "$SRC"/enroot-containerlib.sh

# This line will print the environment variables
# shellcheck disable=SC2086
{ env | grep -qE '^ENROOT'; } && declare -p ${!ENROOT*}
cat <<EOF
COMMAND=(enroot start 
         --rw 
         --mount "$MOUNT"
         --
         "$CE_CONTAINER_NAME"
         "$TOWRAP")
"\${COMMAND[@]}"
status=\$?
if [[ "\$status" -ne 0 ]]
then 
    echo "Command failed with code \$status:"
    echo "\${COMMAND[@]}"
    exit "\$status"
fi
EOF
