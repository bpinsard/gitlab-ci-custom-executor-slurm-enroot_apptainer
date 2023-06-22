#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}" )/.." > /dev/null 2>&1 && pwd)"
URL_DEFAULT="https://git.scc.kit.edu/"
CACHE_DIR_BASE_DEFAULT="$HOME/gitlab-runner/cache"
CI_WS_DEFAULT="$HOME/gitlab-runner"

function get_slurm_default_partition() {
   set -o pipefail
   { scontrol show partition | grep -e "dev_\(single\|cpuonly\)" | cut -d= -f2; } || echo dev_cpuonly
   set +o pipefail
}
DEFAULT_PARTITION_DEFAULT="$(get_slurm_default_partition)"

function show_help() {

cat <<EOF
This script eases the setup of the custom executor.
It accepts the following options:

    --url                 The url of the gitlab ci coordinator
                          default:
                          $URL_DEFAULT

    --registration-token  The registration token, to be obtained
                          from the project page
                          (Settings -> CI/CD -> Runners)
                          on the gitlab web interface

    --name|--description  A description for the runner

    --ce-repo             The location of the custom executor code
                          default:
                          $REPO

    --container-backend   The backend used for containerised jobs,
                          i.e., "enroot", "apptainer" or "none".

    --cache-dir-base      Directory where build cache is stored
                          It will be created if it does not exist.
                          Default:
                          $CACHE_DIR_BASE_DEFAULT/<container-backend>


    --ci-ws               Workspace for the internals
                          of the custom executor.
                          It will be created if it does not exist.
                          Default:
                          $CI_WS_DEFAULT


    --default-partition   The default Slurm partition to use
                          (can be overridden using the right
                          environment variables)
                          default:
                          $DEFAULT_PARTITION_DEFAULT

    --help                Show this help and exit.

In case some of the needed information is not provided using
command line options, it will be asked for in an interactive way.

EOF


}


OPTSTRING=""
OPTSTRING+="url:"
OPTSTRING+=",registration-token:"
OPTSTRING+=",name:"
OPTSTRING+=",description:"
OPTSTRING+=",ce-repo:"
OPTSTRING+=",container-backend:"
OPTSTRING+=",cache-dir-base:"
OPTSTRING+=",ci-ws:"
OPTSTRING+=",default-partition:"
OPTSTRING+=",help"

export OPTSTRING


URL=""
REGISTRATION_TOKEN=""
NAME=""
CE_REPO=""
CONTAINER_BACKEND=""
CACHE_DIR_BASE=""
CI_WS=""
DEFAULT_PARTITION=""

SANITIZED_OPTIONS=$(getopt --name gitlab-runner-register-wrapper --longoptions "$OPTSTRING" -- "$0" "$@")
eval set -- "$SANITIZED_OPTIONS"


while [ $# -gt 0 ]
do
case "$1" in
    --url)
        URL="$2"
        shift
        ;;
    --registration-token)
        REGISTRATION_TOKEN="$2"
        shift
        ;;
    --name|--description)
        NAME="$2"
        shift
        ;;
    --ce-repo)
        CE_REPO="$2"
        shift
        ;;
    --container-backend)
        CONTAINER_BACKEND="$2"
        shift
        ;;
    --cache-dir-base)
        CACHE_DIR_BASE="$2"
        shift
        ;;
    --ci-ws)
        CI_WS="$2"
        shift
        ;;
    --default-partition)
        DEFAULT_PARTITION="$2"
        shift
        ;;
    --help)
        show_help
        exit 0
        ;;
    --)
	break
        ;;
    *)
        echo "Unexpected arguments or options:" "$@"
        exit 22
        ;;

esac
shift
done


if [ -z "$URL" ]
then
	echo "Gitlab instance url ($URL_DEFAULT):"
	read -r URL
    if [ -z "$URL" ]
    then
        URL="$URL_DEFAULT"
    fi
fi
if [ -z "$REGISTRATION_TOKEN" ] 
then
	echo "Registration Token:"
	read -r REGISTRATION_TOKEN
fi
if [ -z "$NAME" ] 
then
	echo "Name or description:"
	read -r NAME
fi
if [ -z "$CE_REPO" ]
then
    CE_REPO_DEFAULT="$REPO"
	echo "Location of the custom executor repository ($CE_REPO_DEFAULT):"
	read -er CE_REPO
    if [ -z "$CE_REPO" ]
    then
        CE_REPO="$CE_REPO_DEFAULT"
    fi
fi
while [[ ! "$CONTAINER_BACKEND" =~ ^(enroot|apptainer|none)$ ]]
do
   echo "Container backend ('apptainer', 'enroot' or 'none' - type unquoted):"
   read -er CONTAINER_BACKEND
done

if [ -z "$CACHE_DIR_BASE" ]
then
	echo -n "Location of the cache directory"
    echo "- will be created if it does not exist ($CACHE_DIR_BASE_DEFAULT):"
	read -er CACHE_DIR_BASE
    if [ -z "$CACHE_DIR_BASE" ]
    then
        CACHE_DIR_BASE="$CACHE_DIR_BASE_DEFAULT"
    fi
fi
if [ -z "$CI_WS" ]
then
	echo "Location of the Custom Executor Workspace ($CI_WS_DEFAULT):"
	read -er CI_WS
    if [ -z "$CI_WS" ]
    then
        CI_WS="$CI_WS_DEFAULT"
    fi
fi
if [ -z "$DEFAULT_PARTITION" ]
then
	echo "Name of the Slurm partition to use by default ($DEFAULT_PARTITION_DEFAULT):"
	read -er DEFAULT_PARTITION
    if [ -z "$DEFAULT_PARTITION" ]
    then
        DEFAULT_PARTITION="$DEFAULT_PARTITION_DEFAULT"
    fi
fi
SRC="$CE_REPO"/src

echo "Creating directories:"
echo "- Cache dir: $CACHE_DIR_BASE/$CONTAINER_BACKEND"
mkdir -p "$CACHE_DIR_BASE/$CONTAINER_BACKEND"
echo "- CI Workspace: $CI_WS"
mkdir -p "$CI_WS"

echo "Registering runner using ${CONTAINER_BACKEND} backend"

gitlab-runner register \
    --non-interactive \
    --name="$NAME ($CONTAINER_BACKEND)" \
    --url="$URL" \
    --registration-token="$REGISTRATION_TOKEN" \
    --executor="custom" \
    --cache-dir="$CACHE_DIR_BASE/$CONTAINER_BACKEND" \
    --env CI_WS="$CI_WS" \
    --env DEFAULT_PARTITION="$DEFAULT_PARTITION" \
    --custom_build_dir-enabled \
    --custom-config-exec="$SRC/configure-slurm.sh" \
    --custom-config-exec-timeout=2000 \
    --custom-config-args="$CONTAINER_BACKEND" \
    --custom-prepare-exec="$SRC/prepare.sh" \
    --custom-prepare-exec-timeout=200 \
    --custom-prepare-args="$CONTAINER_BACKEND" \
    --custom-run-exec="$SRC/run.sh" \
    --custom-run-args="$CONTAINER_BACKEND" \
    --custom-cleanup-exec="$SRC/cleanup-slurm.sh" \
    --custom-cleanup-exec-timeout=200 \
    --custom-cleanup-args="$CONTAINER_BACKEND" \
    --custom-graceful-kill-timeout=200 \
    --custom-force-kill-timeout=200
