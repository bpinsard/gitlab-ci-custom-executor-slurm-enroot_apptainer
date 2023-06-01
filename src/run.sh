#!/usr/bin/env bash

if [[ "$#" -ne 3 ]]
then
    echo "Usage: run.sh <containerisation_backend> <script> <stepname>" >&2
    exit "$SYSTEM_FAILURE_EXIT_CODE"
fi

CONTAINERISATION_BACKEND="${1}"
ORIGINAL_SCRIPT="${2}"
STEPNAME="${3}"
echo "[RUN] Running script:$2 step:$3 on backend:$1"

if [[ -z "$CE_QUEUE_WORKSPACE" ]]
then
    echo "[RUN] CE_QUEUE_WORKSPACE not defined." >&2
    exit "$SYSTEM_FAILURE_EXIT_CODE"
fi


SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=./src/run-include.sh
source "$SRC"/run-include.sh

echo -n "[RUN] "; validate_containerisation_backend \
                     "$CONTAINERISATION_BACKEND" \
                     "$CUSTOM_ENV_CI_JOB_IMAGE" \
                     "$CUSTOM_ENV_IMAGEFILE"


if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]]
then
    case "$CONTAINERISATION_BACKEND" in
        enroot)
            WRAPPER_NAME=wrap_enroot
            ;;
        apptainer)
            WRAPPER_NAME=wrap_apptainer
            ;;
        *)
            echo "[RUN] Error: No valid container backend specified"
            echo "[RUN]        (i.e., apptainer or enroot)"
            echo "[RUN]        but job requires a container image."
            exit 22
            ;;
    esac
    case "$STEPNAME" in
        prepare_script|\
            step_*|\
            build_script|\
            after_script|\
            cleanup_file_variables)

        F="$WRAPPER_NAME"

        _BNAME="$(basename "$ORIGINAL_SCRIPT")"
        SCRIPT=$(mktemp "$CE_QUEUE_WORKSPACE/cp-XXXXXX${_BNAME}")
        cat "$ORIGINAL_SCRIPT" > "$SCRIPT"
        chmod +x "$SCRIPT"

        ;;

        get_sources|\
            restore_cache|\
            download_artifacts|\
            archive_cache|\
            archive_cache_on_failure|\
            upload_artifacts_on_success|\
            upload_artifacts_on_failure)

        F="nowrap"
        SCRIPT="$ORIGINAL_SCRIPT"

        ;;

        *)
            echo "[RUN] Step name not recognized: $STEPNAME" >&2
            exit "$SYSTEM_FAILURE_EXIT_CODE"
        ;;
    esac
else
    F="nowrap"
    SCRIPT="$ORIGINAL_SCRIPT"
fi

# shellcheck source=./src/custom_executor_queue.sh
source "$SRC/custom_executor_queue.sh"
# shellcheck disable=SC1091
source "$CE_QUEUE_WORKSPACE/.env"

WRAPPED="$("$F" "$SCRIPT")"

echo "[RUN] Submitting wrapped script ($WRAPPED) to custom executor queue..."
echo "[RUN] Wrap to be executed (credentials redacted):" >&2
if [[ "$WRAPPED" == "$ORIGINAL_SCRIPT" ]]
then
    echo "<same as received>"
else
    grep -vi "PASSWORD\|USERNAME" "$WRAPPED" >&2
fi

submit_to_custom_executor_queue_and_wait "$WRAPPED" "JOB_$CUSTOM_ENV_CI_JOB_ID"
