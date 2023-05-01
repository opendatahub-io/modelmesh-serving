#!/bin/bash

source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/utils.sh"

namespace=$1
tag=$2
img_name=$3
img_url=$4

TRITON_SERVER_IMG=nvcr.io/nvidia/tritonserver
ML_SERVER_IMG=seldonio/mlserver
TORCHSERVE_IMG=pytorch/torchserve

TRITON_SERVER_TAG=$(cat ${MANIFESTS_DIR}/runtimes/kustomization.yaml |grep ${TRITON_SERVER_IMG} -A1|grep "newTag"|cut -d: -f2|tr -d " ")
ML_SERVER_TAG=$(cat ${MANIFESTS_DIR}/runtimes/kustomization.yaml |grep ${ML_SERVER_IMG} -A1|grep "newTag"|cut -d: -f2|tr -d " ")
TORCHSERVE_TAG=$(cat ${MANIFESTS_DIR}/runtimes/kustomization.yaml |grep ${TORCHSERVE_IMG} -A1|grep "newTag"|cut -d: -f2|tr -d " ")

export TRITON_SERVER=${TRITON_SERVER_IMG}:${TRITON_SERVER_TAG}
export ML_SERVER=${ML_SERVER_IMG}:${ML_SERVER_TAG}
export TORCHSERVE=${TORCHSERVE_IMG}:${TORCHSERVE_TAG}
export OPENVINO=$(cat $MANIFESTS_DIR/params.env |grep odh-openvino|cut -d= -f2)
export MODELMESH=$(cat $MANIFESTS_DIR/params.env |grep odh-modelmesh=|cut -d= -f2)
export MODELMESH_RUNTIME=$(cat $MANIFESTS_DIR/params.env |grep odh-modelmesh-runtime-adapter=|cut -d= -f2)
export REST_PROXY=$(cat $MANIFESTS_DIR/params.env |grep odh-mm-rest-proxy=|cut -d= -f2)

# You can choose fast/stable for image tag to test easily
if [[ ${tag} == "fast" ]]; then
  info ".. TAG=fast is set"
  export MODELMESH=quay.io/opendatahub/modelmesh:fast
  export MODELMESH_RUNTIME=quay.io/opendatahub/modelmesh-runtime-adapter:fast
  export REST_PROXY=quay.io/opendatahub/rest-proxy:fast
elif [[ ${tag} == "stable" ]]; then
  info ".. TAG=stable is set"
  export MODELMESH=quay.io/opendatahub/modelmesh:stable
  export MODELMESH_RUNTIME=quay.io/opendatahub/modelmesh-runtime-adapter:stable
  export REST_PROXY=quay.io/opendatahub/rest-proxy:stable
fi

# You can set custom image for comoponents
if [[ z${img_name} != z ]]; then
  case $img_name in
    modelmesh)
      info ".. modelmesh image is set"
      export MODELMESH=${img_url}
      ;;
    modelmesh-runtime-adapter)
      info ".. modelmesh-runtime-adapter image is set"
      export MODELMESH_RUNTIME=${img_url}
      ;;
    rest-proxy)
      info ".. rest-proxy image is set"
      export REST_PROXY=${img_url}
      ;;
    modelmesh-controller)
      info ".. modelmesh-controller image is set"
      ;;
    odh-model-controller)
      info ".. odh-model-controller image is set"
      ;;
    *)
      echo "No components found"
      exit 1
      ;;
  esac
fi

images=(${TRITON_SERVER} ${ML_SERVER} ${OPENVINO} ${TORCHSERVE} ${MODELMESH} ${MODELMESH_RUNTIME} ${REST_PROXY})

echo 
info "Start dowonload the following images:"
info "${images[@]}"

cat <<EOF | oc apply -n $namespace -f -
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: image-downloader
spec:
  selector:
    matchLabels:
      app: image-downloader
  template:
    metadata:
      labels:
        app: image-downloader
    spec:
      containers:
      - name: triton-image-downloader
        image: ${TRITON_SERVER}
        command: ["/bin/sh"]
        args: ["-c", "sleep infinity"]
      - name: mlserver-image-downloader
        image: ${ML_SERVER}
        command: ["/bin/sh"]
        args: ["-c", "sleep infinity"]
      - name: openvino-image-downloader
        image: ${OPENVINO}
        command: ["/bin/sh"]
        args: ["-c", "sleep infinity"]
      - name: torchserve-image-downloader
        image: ${TORCHSERVE}
        command: ["/bin/sh"]
        args: ["-c", "sleep infinity"]
      - name: modelmesh-image-downloader
        image: ${MODELMESH}
        command: ["/bin/sh"]
        args: ["-c", "sleep infinity"]
      - name: modelmesh-runtime-image-downloader
        image: ${MODELMESH_RUNTIME}
        command: ["/bin/sh"]
        args: ["-c", "sleep infinity"]
      - name: rest-proxy-image-downloader
        image: ${REST_PROXY}
        command: ["/bin/sh"]
        args: ["-c", "sleep infinity"]
EOF

wait_downloading_images $images $namespace

echo 
info "Delete image downloading daemonset"
oc delete daemonset  image-downloader --force --grace-period=0

success "[SUCCESS] Downloaded necessary images on all nodes"
