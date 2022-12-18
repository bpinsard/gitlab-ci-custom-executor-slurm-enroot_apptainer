#!/usr/bin/env bash

SCRIPT="${1}"
STEPNAME="${2}"

if [[ -z "$CE_QUEUE_ENV_PATH" ]]
then
    echo "CE_QUEUE_ENV_PATH not defined." >&2
    exit "$SYSTEM_FAILURE_EXIT_CODE"
fi


SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

# shellcheck source=./src/run-include.sh
source "$SRC"/run-include.sh


if [[ -n "$CUSTOM_ENV_CI_JOB_IMAGE" ]]
then
case "$STEPNAME" in
    prepare_script|\
        step_*|\
        build_script|\
        after_script|\
        cleanup_file_variables)

    F="wrap_enroot"

    ;;

    get_sources|\
        restore_cache|\
        download_artifacts|\
        archive_cache|\
        archive_cache_on_failure|\
        upload_artifacts_on_success|\
        upload_artifacts_on_failure)

    F="nowrap"

    ;;

    *)
        echo "Step name not recognized: $STEPNAME" >&2
        exit "$SYSTEM_FAILURE_EXIT_CODE"
    ;;
esac
else
    F="nowrap"
fi

# shellcheck source=./src/custom_executor_queue.sh
source "$SRC/custom_executor_queue.sh"
# shellcheck disable=SC1090
source "$CE_QUEUE_ENV_PATH"


WRAPPED="$("$F" "$SCRIPT")"
submit_to_custom_executor_queue "$WRAPPED"
BNAME="$(basename "$WRAPPED")"
# shellcheck disable=SC1090
source "$CE_QUEUE_ENV_PATH"

DONENAME="$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/DONE/$BNAME"
OUTPUTNAME="$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/OUTPUT/$BNAME.out"
EXITVALUEFNAME="$CUSTOM_EXECUTOR_QUEUE_WORKSPACE/OUTPUT/$BNAME.exitcode"
while [ ! -f "$DONENAME" ]
do
    sleep 1
done
TIME="$(date +"%s")"
mv "$DONENAME" "$DONENAME"-"$TIME"
cat "$OUTPUTNAME"
read -r EXITVALUE < "$EXITVALUEFNAME"
exit "$EXITVALUE"
