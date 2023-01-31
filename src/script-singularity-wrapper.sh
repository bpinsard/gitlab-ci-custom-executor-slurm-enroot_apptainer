#!/usr/bin/env bash

TOWRAP="$1"
[[ "$TOWRAP" =~ ^/ ]] || { echo "Needs absolute path to script to wrap." >&2; exit 22; }

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/enroot-containerlib.sh
source "$SRC"/singularity-containerlib.sh

# This line will print the environment variables
# shellcheck disable=SC2086
{ env | grep -qE '^SINGULARITY'; } && declare -p ${!SINGULARITY*}

cat <<EOF

COMMAND=(singularity exec
         --bind "$CUSTOM_ENV_CI_WS,$TOWRAP"
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
