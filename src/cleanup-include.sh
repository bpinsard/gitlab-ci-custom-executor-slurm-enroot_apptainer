#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"
# shellcheck source=src/include.sh
source "$SRC"/include.sh

function cleanup_containers() {

    local CONTAINERISATION_BACKEND="$1"
    echo -n "[CLEANUP] "; validate_containerisation_backend \
                                "$CONTAINERISATION_BACKEND" \
                                "$CUSTOM_ENV_CI_JOB_IMAGE"  \
                                "$CUSTOM_ENV_IMAGEFILE"


    if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]] || [[ -n "$CUSTOM_ENV_IMAGEFILE" ]]
    then
        SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"


        case "$CONTAINERISATION_BACKEND" in
            enroot)
                echo "[CLEANUP] Invoking cleanup for $CONTAINERISATION_BACKEND"
                # shellcheck source=./src/cleanup-enroot.sh
                source "$SRC/cleanup-enroot.sh"
                ;;
            apptainer)
                echo "[CLEANUP] Invoking cleanup for $CONTAINERISATION_BACKEND"
                # shellcheck source=./src/cleanup-apptainer.sh
                source "$SRC/cleanup-apptainer.sh"
                ;;
            *)
                echo "[CLEANUP] ERROR: Not a valid backend: $CONTAINERISATION_BACKEND"
                exit "$SYSTEM_FAILURE_EXIT_CODE"
                ;;
        esac
    fi
}
