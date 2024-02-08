#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset
SCRIPTFILETOWRAP="$1"
[[ "$SCRIPTFILETOWRAP" =~ ^/ ]] || { echo "Needs absolute path to script to wrap." >&2; exit 22; }

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=./src/containerlib-apptainer.sh
source "$SRC"/containerlib-apptainer.sh

cat <<EOF
set -o errexit
set -o pipefail
set -o nounset
EOF

# This line will print the environment variables
# shellcheck disable=SC2086
{ env | grep -qE '^APPTAINER'; } && declare -p ${!APPTAINER*} 1>&2

# shellcheck disable=SC2086
{ env | grep -qE '^APPTAINER'; } && declare -p ${!APPTAINER*}

set +o nounset
if [ -z "$CUSTOM_ENV_APPTAINER_EXEC_OPTIONS" ]
then
   CUSTOM_ENV_APPTAINER_EXEC_OPTIONS=""
fi
set -o nounset

cat <<EOF
COMMAND=(apptainer exec
         --bind "$CUSTOM_ENV_CI_WS,$SCRIPTFILETOWRAP,$CUSTOM_ENV_CI_BUILDS_DIR"
         $CUSTOM_ENV_APPTAINER_EXEC_OPTIONS
         "$CE_IMAGEFILE"
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
