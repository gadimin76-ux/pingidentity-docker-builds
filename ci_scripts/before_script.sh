#!/usr/bin/env sh
# Copyright © 2025 Ping Identity Corporation

set -xe
echo "hello from before script"

pwd
env | sort
echo "${USER}"
type jq
type python
python --version
type aws
aws --version

#Uncomment these lines and update docker-builds-runner image if azure_tools.lib.sh is used in the pipeline. See $PIPELINE_BUILD_REGISTRY_VENDOR.
#type az
#az --version

type docker
docker info
type docker-compose
docker-compose version
type envsubst
envsubst --version
type kubectl
kubectl version --client=true

#Uncomment these lines and update docker-builds-runner image if google_tools.lib.sh is used in the pipeline. See $PIPELINE_BUILD_REGISTRY_VENDOR.
#type gcloud
#gcloud --version

type git
git --version
type notary
notary version
