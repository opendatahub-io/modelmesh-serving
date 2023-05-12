#!/bin/bash

source "$(dirname "$(realpath "$0")")/../env.sh"
source "$OPENDATAHUB_DIR/scripts/utils.sh"

export DEMO_HOME=/tmp/modelmesh/pvc

cd ${ROOT_DIR}

# Deploy Opendatahub Modelserving 
# Deploy all required components to use such as minio,images and so on
STABLE_MANIFESTS=true CONTROLLERNAMESPACE=opendatahub NAMESPACE=modelmesh-serving make deploy-mm-for-odh  make deploy-fvt-for-odh

oc get cm model-serving-config -n $ODH_NS || oc create -f ${COMMON_MANIFESTS_DIR}/allowAnyPvc-config.yaml -n $ODH_NS
oc delete pod -l control-plane=modelmesh-controller -n $ODH_NS
wait_for_pods_ready "-l control-plane=modelmesh-controller" "$ODH_NS"

# Enable Route
oc annotate servingruntime mlserver-0.x enable-route=true enable-auth=false    

# Deploy sample sklearn model from the pvc 
# using URI
oc create -f ${FVT_TEST_DIR}/isvcs/isvc-pvc-uri.yaml
# using PATH
oc create -f ${FVT_TEST_DIR}/isvcs/isvc-pvc-path.yaml

wait_for_pods_ready "-l modelmesh-service=modelmesh-serving" "$TEST_MM_NS"
