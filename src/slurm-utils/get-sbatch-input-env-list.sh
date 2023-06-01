#!/usr/bin/env bash

function sbatch_man_available () {
    man sbatch &> /dev/null
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

if sbatch_man_available
then
    "$DIR"/_get-sbatch-input-env-list.sh
else
    "$DIR"/../../tests/mocks/bin/get-sbatch-input-env-list.sh
fi
