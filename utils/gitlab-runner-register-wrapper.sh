#!/bin/bash


REPO="$(cd "$(dirname "${BASH_SOURCE[0]}" )/.." > /dev/null 2>&1 && pwd)"

set -e
getopt -Q --name gitlab-runner-register-wrapper \
    --longoptions url:,registration-token:,name:,description:,tags:,tag-list:,ce-repo: \
    -- "$0" "$@"

while [ $# -gt 0 ] 
do
case "$1" in
    --url)
        URL="$2"
        ;;
	--registration-token)
		REGISTRATION_TOKEN="$2"
		;;
	--name|--description)
		NAME="$2"
		;;
	--tags|--tag-list)
		TAGS="$2"
		;;
	--ce-repo)
		CE_REPO="$2"
		;;
    *)
        echo "Unexpected arguments or options:" "$@"
        ;;
esac
shift
shift
done

if [ -z "$URL" ]
then
    URL_DEFAULT="https://scs-gitlab.scc.kit.edu/"
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



SRC="$CE_REPO"/src

gitlab-runner register \
    --non-interactive \
    --name=\""$NAME"\" \
    --url="$URL" \
    --registration-token="$REGISTRATION_TOKEN" \
    --executor="custom" \
    --tag-list="$TAGS" \
    --builds-dir="$HOME/gitlab-runner/builds" \
    --cache-dir="$HOME/gitlab-runner/cache" \
    --custom_build_dir-enabled \
    --custom-config-exec="$SRC/configure-slurm.sh" \
    --custom-config-exec-timeout=200 \
    --custom-prepare-exec="$SRC/prepare-enroot.sh" \
    --custom-prepare-exec-timeout=200 \
    --custom-run-exec="$SRC/run.sh" \
    --custom-cleanup-exec="$SRC/cleanup-slurm.sh" \
    --custom-cleanup-exec-timeout=200 \
    --custom-graceful-kill-timeout=200 \
    --custom-force-kill-timeout=200

systemctl --user restart gitlab-runner.service
