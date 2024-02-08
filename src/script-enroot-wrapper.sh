#!/usr/bin/env bash

# This script outputs a script that wraps another script
# into an enroot command
set -o errexit
set -o pipefail
set -o nounset

SCRIPTFILETOWRAP="$1"
[[ "$SCRIPTFILETOWRAP" =~ ^/ ]] || { echo "Needs absolute path to script to wrap." >&2; exit 22; }

MOUNTS="--mount $CUSTOM_ENV_CI_WS:$CUSTOM_ENV_CI_WS"

if [[ ! "$SCRIPTFILETOWRAP" =~ ^"${CUSTOM_ENV_CI_WS}"  ]]
then
    MOUNTS="--mount $SCRIPTFILETOWRAP:$SCRIPTFILETOWRAP $MOUNTS"
fi

if [[ ! "$CUSTOM_ENV_CI_BUILDS_DIR" =~ ^"${CUSTOM_ENV_CI_WS}"  ]]
then
    MOUNTS="--mount $CUSTOM_ENV_CI_BUILDS_DIR:$CUSTOM_ENV_CI_BUILDS_DIR $MOUNTS"
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/containerlib-enroot.sh
source "$SRC"/containerlib-enroot.sh
# shellcheck source=./src/include.sh
source "$SRC"/include.sh

DECLARATIONS=$(mktemp)

cat <<EOF
set -o errexit
set -o pipefail
set -o nounset
EOF

# This line will print the environment variables
# shellcheck disable=SC2086
{ env | grep -qE '^ENROOT'; } && declare -p ${!ENROOT*} > "$DECLARATIONS"

cat "$DECLARATIONS"

cat <<EOF
COMMAND=(enroot start 
         --rw 
         $MOUNTS
         --
         "$CE_CONTAINER_NAME"
         "$SCRIPTFILETOWRAP")
"\${COMMAND[@]}"
status=\$?
if [[ "\$status" -ne 0 ]]
then 
    echo "Command failed with code \$status:"
    echo "\${COMMAND[@]}"
    exit "\$status"
fi
EOF

cat_verbose "$DECLARATIONS" 1>&2
rm "$DECLARATIONS"
