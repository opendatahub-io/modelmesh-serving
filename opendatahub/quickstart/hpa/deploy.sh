#!/bin/bash

source "$(dirname "$(realpath "$0")")/../env.sh"
source "$OPENDATAHUB_DIR/scripts/utils.sh"

export DEMO_HOME=/tmp/modelmesh/hpa

cd ${ROOT_DIR}

# Deploy Opendatahub Modelserving 
# Deploy all required components to use such as minio,images and so on
TAG=fast CONTROLLERNAMESPACE=opendatahub NAMESPACE=modelmesh-serving make deploy-mm-for-odh  make deploy-fvt-for-odh

# Delete default ServingRuntime 
oc delete servingruntime --all --force

# Create Openvino ServingRuntime has enable-route: true, enable-auth: "false"
oc apply -f ${COMMON_MANIFESTS_DIR}/openvino-serving-runtime.yaml -n ${TEST_MM_NS}

# Enable HPA feature
oc annotate servingruntime ovms-1.x serving.kserve.io/autoscalerClass=hpa

# Create a sample Inference Service 
oc apply -n ${TEST_MM_NS} -f  ${COMMON_MANIFESTS_DIR}/openvino-inference-service.yaml 
oc wait isvc/example-onnx-mnist --for=condition=READY 

wait_for_pods_ready "-l modelmesh-service=modelmesh-serving" "$TEST_MM_NS"
