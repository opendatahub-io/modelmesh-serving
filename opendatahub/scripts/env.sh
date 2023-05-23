#!/bin/bash

export SCRIPT_DIR=$(dirname "$(realpath "$0")")
export MANIFESTS_DIR=$SCRIPT_DIR/manifests
export OPENDATAHUB_DIR=$(dirname "$SCRIPT_DIR")
export ROOT_DIR=${OPENDATAHUB_DIR}/..
export ODH_MANIFESTS_DIR=$OPENDATAHUB_DIR/odh-manifests
export MM_HOME_DIR=/tmp/modelmesh-e2e
export KFDEF_FILE=${MM_HOME_DIR}/kfdef.yaml

export PATH=${ROOT_DIR}/bin:$PATH
# echo $SCRIPT_DIR
# echo $MANIFESTS_DIR
# echo $OPENDATAHUB_DIR
# echo $ODH_MANIFESTS_DIR
