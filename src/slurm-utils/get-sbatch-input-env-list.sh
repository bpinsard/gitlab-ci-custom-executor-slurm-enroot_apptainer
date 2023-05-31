#!/usr/bin/env bash

function _at_scc () {
    [[ $(hostname) =~ (uc2n|hkn)[[:digit:]]{3,4}\.localdomain ]]
}

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

if _at_scc
then
    "$DIR"/_get-sbatch-input-env-list.sh
else
    "$DIR"/../../tests/mocks/bin/get-sbatch-input-env-list.sh
fi
