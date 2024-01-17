#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
#shellcheck source=src/configure-include.sh
source "$SRC"/configure-include.sh

function print_json_output_noslurm(){
    local CI_BUILDS_DIR
    CI_BUILDS_DIR="$1"
    local TMPFILE
    TMPFILE="$(mktemp -t CI-conf-slurm-output-"$USER"-XXXXXX)"
    cat <<EOF > "$TMPFILE"
{
  "builds_dir": "$CI_BUILDS_DIR",
  "driver": {
    "name": "Slurm driver+enroot/apptainer",
    "version": "v0.0.1"
  }
}
EOF
    cat "$TMPFILE"
    cat "$TMPFILE" 1>&2
    rm "$TMPFILE"

}
