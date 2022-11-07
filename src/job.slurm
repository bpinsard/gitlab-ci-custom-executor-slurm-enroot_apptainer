#!/bin/bash



SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

source "$SRC"/allocation_manager.sh

ALLOCATION_MANAGER_MAX_RUNTIME=$1
ALLOCATION_MANAGER_CYCLETIME=$2
ALLOCATION_MANAGER_WORKSPACE=$3


echo "Starting allocation manager"
start_allocation_manager "$ALLOCATION_MANAGER_MAX_RUNTIME" \
                         "$ALLOCATION_MANAGER_CYCLETIME" \
                         "$ALLOCATION_MANAGER_WORKSPACE"
