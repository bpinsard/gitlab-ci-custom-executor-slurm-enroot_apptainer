#!/usr/bin/env bash

SCRIPT="${1}"
STEPNAME="${2}"

case "$STEPNAME" in
    prepare_script|step_*|build_script|after_script|cleanup_file_variables)
    SRC="$(cd "$(dirname "${BASH_SOURCE[0]}" )" > /dev/null 2>&1 && pwd)"

    # shellcheck source=./src/custom_executor_queue.sh
    source "$SRC"/custom_executor_queue.sh
    # shellcheck disable=SC1091
    source "$CUSTOM_ENV_CI_BUILDS_DIR"/.env

    submit_to_custom_executor_queue "$SCRIPT"

    BNAME="$(basename "$SCRIPT")"
    DONENAME="$CUSTOM_ENV_CI_BUILDS_DIR/DONE/$BNAME"
    OUTPUTNAME="$CUSTOM_ENV_CI_BUILDS_DIR/OUTPUT/$BNAME.out"
    while [ ! -f "$DONENAME" ]
    do
        sleep 1
    done
    TIME="$(date +"%s")"
    mv "$DONENAME" "$DONENAME"-"$TIME"
    cat "$OUTPUTNAME"

    ;;

get_sources|restore_cache|download_artifacts|archive_cache|archive_cache_on_failure|upload_artifacts_on_success|upload_artifacts_on_failure)

    "$SCRIPT"

    ;;

    *)
    ;;
esac
