#!/usr/bin/env bash

function _on_horeka () {
    hostname | grep -q -E "hkn[0-9]{4}.localdomain"
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

if _on_horeka
then
    $DIR/_get-sbatch-input-env-list.sh
else
    $DIR/../../tests/mocks/bin/get-sbatch-input-env-list.sh
fi
