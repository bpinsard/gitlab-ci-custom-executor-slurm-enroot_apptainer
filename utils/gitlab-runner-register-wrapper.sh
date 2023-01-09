#!/bin/bash

set -e
while [ $# -gt 0 ] 
do
case "$1" in
	--registration-token)
		REGISTRATION_TOKEN="$2"
		shift
		shift
		;;
	--name|--description)
		NAME="$2"
		shift
		shift
		;;
	--tags)
		TAGS="$2"
		shift
		shift
		;;
	--ce-repo)
		CE_REPO="$2"
		shift
		shift
		;;
esac
done

if [ -z "$REGISTRATION_TOKEN" ] 
then
	echo "Registration Token:"
	read REGISTRATION_TOKEN
fi
if [ -z "$NAME" ] 
then
	echo "Name or description:"
	read NAME
fi
if [ -z "$TAGS" ] 
then
	echo "Tags for the runner:"
	read TAGS 
fi
if [ -z "$CE_REPO" ] 
then
	echo "Location of the custom executor repository:"
	read -e CE_REPO 
fi



SRC="$CE_REPO"/src

gitlab-runner register \
    --non-interactive \
    --name="$NAME" \
    --url=https://scs-gitlab.scc.kit.edu/ \
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

	               

