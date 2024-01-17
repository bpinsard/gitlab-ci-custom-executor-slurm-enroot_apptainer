#!/usr/bin/env bash

if [[ "$#" -ne 4 ]]
then
    echo "Usage: run.sh <containerisation_backend> <{use,no}slurm> <script> <stepname>" >&2
    exit "$SYSTEM_FAILURE_EXIT_CODE"
fi

CONTAINERISATION_BACKEND="${1}"
USESLURM="${2}"
ORIGINAL_SCRIPT="${3}"
STEPNAME="${4}"

echo "[RUN] Running script:$ORIGINAL_SCRIPT step:$STEPNAME on backend:$1 ($2)"


SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=./src/run-include.sh
source "$SRC"/run-include.sh

if [[ "$USESLURM" == "useslurm" ]]
then
    if [[ -z "$CE_QUEUE_WORKSPACE" ]]
    then
        echo "[RUN] CE_QUEUE_WORKSPACE not defined." >&2
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    fi
    # shellcheck source=./src/slurm-include.sh
    source "$SRC/slurm-include.sh"
elif [[ "$USESLURM" == "noslurm" ]]
then

    # shellcheck source=./src/include.sh
    source "$SRC/include.sh"
fi

echo -n "[RUN] "; validate_containerisation_backend \
                     "$CONTAINERISATION_BACKEND" \
                     "$CUSTOM_ENV_CI_JOB_IMAGE" \
                     "$CUSTOM_ENV_IMAGEFILE"


if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]] || [[ -n "$CUSTOM_ENV_IMAGEFILE" ]]
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


        if [[ "$USESLURM" == "useslurm" ]]
        then
           PATH_TO_USE=$CE_QUEUE_WORKSPACE
        elif [[ "$USESLURM" == "noslurm" ]]
        then
           PATH_TO_USE=$CUSTOM_ENV_CI_WS
        fi

        _BNAME="$(basename "$ORIGINAL_SCRIPT")"
        SCRIPT=$(mktemp "$PATH_TO_USE/cp-XXXXXX${_BNAME}")
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

WRAPPED="$("$F" "$SCRIPT")"

echo "[RUN] Wrap to be executed (credentials redacted):" >&2
if [[ "$WRAPPED" == "$ORIGINAL_SCRIPT" ]]
then
    echo "<same as received>"
else
    grep -vi "PASSWORD\|USERNAME" "$WRAPPED" >&2
fi

echo "[RUN] Output:" >&2
if [[ "$USESLURM" ==  "useslurm" ]]
then
    echo "[RUN] Submitting wrapped script ($WRAPPED) to custom executor queue..."
    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC/custom_executor_queue.sh"
    # shellcheck disable=SC1091
    source "$CE_QUEUE_WORKSPACE/.env"
    submit_to_custom_executor_queue_and_wait "$WRAPPED" "JOB_$CUSTOM_ENV_CI_JOB_ID"
elif [[ "$USESLURM" == "noslurm" ]]
then
    "$WRAPPED" "JOB_$CUSTOM_ENV_CI_JOB_ID"
fi

EXIT_CODE=$?
echo "[RUN] Exit code: $EXIT_CODE" >&2
echo "[RUN] End of Output:" >&2
exit "$EXIT_CODE"
