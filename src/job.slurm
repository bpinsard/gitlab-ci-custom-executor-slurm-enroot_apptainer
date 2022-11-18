#!/bin/bash

if [[ "${TRACE-0}" == "1" ]]; then set -o xtrace; fi
set -o nounset
set -o errexit
set -o pipefail

ALLOCATION_MANAGER_WORKSPACE=$1
SRC=$2

source "$SRC"/allocation_manager.sh


echo "Starting allocation manager" >&2
start_allocation_manager "$ALLOCATION_MANAGER_WORKSPACE"
