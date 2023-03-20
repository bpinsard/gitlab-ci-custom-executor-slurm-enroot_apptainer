#!/bin/bash


REPO="$(cd "$(dirname "${BASH_SOURCE[0]}" )/.." > /dev/null 2>&1 && pwd)"
URL_DEFAULT="https://scs-gitlab.scc.kit.edu/"
BUILDS_DIR_DEFAULT="$HOME/gitlab-runner/builds"
CACHE_DIR_DEFAULT="$HOME/gitlab-runner/cache"


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

    --tags|--tag-list     A comma-separated list of tags
                          associated to the runner being registered

    --ce-repo             The location of the custom executor code
                          default:
                          $REPO

    --container-backends  The backend used for containerised jobs,
                          i.e., "enroot", "singularity" or "both".
                          When using "both", two runners will be
                          registered, and one will have the
                          "enroot" tag added to its tag list, while
                          the other will have the "singularity" tag
                          added to its tag list.

    --builds-dir          Directory where builds are stored
                          default:
                          $BUILDS_DIR_DEFAULT

    --cache-dir           Directory where build cache is stored
                          default:
                          $CACHE_DIR_DEFAULT

    --help                Show this help and exit.

In case some of the needed information is not provided using
command line options, it will be asked for in an interactive way.

EOF



}



set -e

OPTSTRING=""
OPTSTRING+="url:"
OPTSTRING+=",registration-token:"
OPTSTRING+=",name:"
OPTSTRING+=",description:"
OPTSTRING+=",tags:"
OPTSTRING+=",tag-list:"
OPTSTRING+=",ce-repo:"
OPTSTRING+=",container-backends:"
OPTSTRING+=",builds-dir:"
OPTSTRING+=",cache-dir:"
OPTSTRING+=",help"

export OPTSTRING

SANITIZED_OPTS=$(getopt --name gitlab-runner-register-wrapper --longoptions "$OPTSTRING" -- "$0" "$@")

URL=""
REGISTRATION_TOKEN=""
NAME=""
TAGS=""
CE_REPO=""
CONTAINER_BACKENDS=""
BUILDS_DIR=""
CACHE_DIR=""

eval set -- "$SANITIZED_OPTS"


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
    --tags|--tag-list)
        TAGS="$2"
        shift
        ;;
    --ce-repo)
        CE_REPO="$2"
        shift
        ;;
    --container-backends)
        CONTAINER_BACKENDS="$2"
        shift
        ;;
    --builds-dir)
        BUILDS_DIR="$2"
        shift
        ;;
    --cache-dir)
        CACHE_DIR="$2"
        shift
        ;;
    --help)
        show_help
        exit 0
        ;;
    --)
        echo "-- reached"
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
if [ -z "$TAGS" ] 
then
	echo "Tags for the runner:"
	read -r TAGS
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
while [[ ! "$CONTAINER_BACKENDS" =~ ^(enroot|singularity|both)$ ]]
do
   echo "Container backend (singularity or enroot):"
   read -er CONTAINER_BACKENDS
done

if [ -z "$BUILDS_DIR" ]
then
	echo "Location of the custom executor repository ($BUILDS_DIR_DEFAULT):"
	read -er BUILDS_DIR
    if [ -z "$BUILDS_DIR" ]
    then
        BUILDS_DIR="$BUILDS_DIR_DEFAULT"
    fi
fi
if [ -z "$CACHE_DIR" ]
then
	echo "Location of the custom executor repository ($CACHE_DIR_DEFAULT):"
	read -er CACHE_DIR
    if [ -z "$CACHE_DIR" ]
    then
        CACHE_DIR="$CACHE_DIR_DEFAULT"
    fi
fi

SRC="$CE_REPO"/src

declare -A TAGS_ARR

if [[ "$CONTAINER_BACKENDS" == singularity ]]
then
    CONTAINER_BACKENDS_ARR=( singularity )
    TAGS_ARR[singularity]="$TAGS"
elif [[ "$CONTAINER_BACKENDS" == enroot ]]
then
    CONTAINER_BACKENDS_ARR=( enroot )
    TAGS_ARR[enroot]="$TAGS"
else
    CONTAINER_BACKENDS_ARR=(enroot singularity)
    TAGS_ARR[singularity]="$TAGS",singularity
    TAGS_ARR[enroot]="$TAGS",enroot
fi

for CONTAINER_BACKEND in ${CONTAINER_BACKENDS_ARR[@]}
do
   echo "Runner using ${CONTAINER_BACKEND} backend set with tags=\"${TAGS_ARR[$CONTAINER_BACKEND]}\""

   gitlab-runner register \
       --non-interactive \
       --name="$NAME" \
       --url="$URL" \
       --registration-token="$REGISTRATION_TOKEN" \
       --executor="custom" \
       --tag-list="${TAGS_ARR[$CONTAINER_BACKEND]}" \
       --builds-dir="$BUILDS_DIR" \
       --cache-dir="$CACHE_DIR" \
       --custom_build_dir-enabled \
       --custom-config-exec="$SRC/configure-slurm.sh" \
       --custom-config-exec-timeout=200 \
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
done

