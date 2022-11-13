#!/bin/bash

set -o nounset
set -o errexit
set -o pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

source "$SRC"/allocation_manager.sh

ALLOCATION_MANAGER_WORKSPACE=$1


echo "Starting allocation manager" >&2
start_allocation_manager "$ALLOCATION_MANAGER_WORKSPACE"
