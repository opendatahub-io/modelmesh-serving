#!/bin/bash

source "$(dirname "$(realpath "$0")")/../env.sh"
source "$OPENDATAHUB_DIR/scripts/utils.sh"

export CURRENT_DIR=$(dirname "$(realpath "$0")")
export DEMO_HOME=/tmp/modelmesh/basic

cd ${ROOT_DIR}

# Deploy Opendatahub Modelserving 
# Deploy all required components to use such as minio,images and so on
STABLE_MANIFESTS=true CONTROLLERNAMESPACE=opendatahub NAMESPACE=modelmesh-serving make deploy-mm-for-odh  make deploy-fvt-for-odh

# Delete default ServingRuntime 
oc delete servingruntime --all --force

################## Custom Part ##################

# Create Openvino ServingRuntime has enable-route: true, enable-auth: "false"
oc apply -f ${COMMON_MANIFESTS_DIR}/openvino-serving-runtime.yaml -n ${TEST_MM_NS}

# Create a sample Inference Service 
oc apply -n ${TEST_MM_NS} -f  ${COMMON_MANIFESTS_DIR}/openvino-inference-service.yaml 

wait_for_pods_ready "-l modelmesh-service=modelmesh-serving" ${TEST_MM_NS}

success "Successfully deployed ModelMesh Serving/ODH Model Controller/NFS Provisioner/Sample Model!"
