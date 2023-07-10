#!/bin/bash

source "$(dirname "$(realpath "$0")")/../env.sh"
source "${OPENDATAHUB_DIR}/scripts/utils.sh"

export CURRENT_DIR=$(dirname "$(realpath "$0")")
export DEMO_HOME=/tmp/modelmesh/basic

cd ${ROOT_DIR}
STABLE_MANIFESTS=true CONTROLLERNAMESPACE=opendatahub NAMESPACE=modelmesh-serving  C_MM_TEST=true C_MM_CTRL_KFCTL=true make cleanup-for-odh
