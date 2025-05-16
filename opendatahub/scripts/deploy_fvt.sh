#!/bin/bash

source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/utils.sh"

set -Eeuo pipefail

namespace=modelmesh-serving
ctrlnamespace=opendatahub
tag=none
force=false
img_map=none
img_name=
img_url=
stable_manifests=false
target_modelmesh_dir=model-mesh

function showHelp() {
  echo "usage: $0 [flags]"
  echo
  echo "Flags:"
  echo "  -n, --namespace                (optional) Kubernetes namespace to deploy FVT test components to (default modelmesh-serving)."
  echo "  -c, --ctrl-namespace           (optional) Kubernetes namespace to deploy modelmesh controller to (default modelmesh-serving)."
  echo "  -i, --image                    (optional) Set custom image (default none)."
  echo "  -p, --stable-manifests         (optional) Use stable manifests. By default, it will use the latest manifests (default false)."
  echo "  -t, --tag                      (optional) Set tag fast,stable to change images quickly(default none)."
  echo "  -f, --force                    (optional) Copy fvt manifests from opendatahub/odh-manifest(default false)."
  echo
  echo "Installs components related to fvt test"
}


while (($# > 0)); do
  case "$1" in
  -h | --h | --he | --hel | --help)
    showHelp
    exit 2
    ;;
  -n | --n | -namespace | --namespace)
    shift
    namespace="$1"
    ;;
  -c | --c | -ctrl-namespace | --ctrl-namespace)
    shift
    ctrlnamespace="$1"
    ;;   
  -i | --i | -image | --image)
    shift
    img_map="$1"
    img_name=$(echo ${img_map}|cut -d'=' -f1)
    img_url=$(echo ${img_map}|cut -d'=' -f2)
    ;;      
  -t | --t | -tag | --tag)
    shift
    tag="$1"
    ;;
  -f | --f | -force | --force)
    force=true
    ;;    
  -p | --p | -stable-manifests | --stable-manifests)
    stable_manifests=true
    ;;       
  -*)
    die "Unknown option: '${1}'"
    ;;       
  esac
  shift
done    

if [[ ${tag} == "stable" ]];then
  stable_manifests=true
fi


install_binaries

echo "* Start to prepare FVT test environment"
allowedImgName=false
if [[ ${img_map} != none ]]; then
  info "Checking the custom image is in allow image list" 
  checkAllowedImage ${img_name}
  if [[ $? == 0 ]]; then
    info "The image ${img_name} is allowed to use"
    allowedImgName=true
  fi
fi

if [[ ${stable_manifests} == "true" ]]; then
  target_modelmesh_dir=model-mesh_stable
fi

# Copy fvt tests manifests into manifest folder
if [[ ! -d $MANIFESTS_DIR/fvt ]] || [[ ${force} == "true" ]];then
  info ".. Copying fvt tests manifests into manifest folder"
  cp -R $MANIFESTS_DIR/fvt_templates $MANIFESTS_DIR/fvt
  cp -R $ODH_MANIFESTS_DIR/${target_modelmesh_dir}/odh-modelmesh-controller/dependencies/* $MANIFESTS_DIR/fvt/.
  # Convert imaes to use quay.io image (avoid dockerhub pull limit)
  minio_tag=$(grep kserve/modelmesh-minio-dev-examples opendatahub/scripts/manifests/fvt/fvt.yaml |cut -d: -f3)
  sed "s+kserve/modelmesh-minio-dev-examples:${minio_tag}+quay.io/rh-ee-allausas/modelmesh-minio-dev-examples:${minio_tag}+g" -i opendatahub/scripts/manifests/fvt/fvt.yaml
  sed "s+kserve/modelmesh-minio-examples:${minio_tag}+quay.io/rh-ee-allausas/modelmesh-minio-examples:${minio_tag}+g" -i opendatahub/scripts/manifests/fvt/fvt.yaml
  sed 's+ubuntu+quay.io/fedora/fedora:38+g' -i opendatahub/scripts/manifests/fvt/fvt.yaml
fi

# Copy opendatahub params.env into manifests folder to get the right images
if [[ ! -f $MANIFESTS_DIR/params.env ]] || [[ ${force} == "true" ]];then
  info ".. Copying opendatahub params.env into manifests folder to get the right images"
  cp -R $ODH_MANIFESTS_DIR/${target_modelmesh_dir}/base/params.env $MANIFESTS_DIR/.
fi

# The upstream use ClusterServingRuntime so this replace ClusterServingRuntime to ServingRuntime.
if [[ ! -d $MANIFESTS_DIR/runtimes ]] || [[ ${force} == "true" ]];then
  info ".. The upstream use ClusterServingRuntime so this replace ClusterServingRuntime to ServingRuntime."
  rm -rf $MANIFESTS_DIR/runtimes/*-*.yaml
  cp -R $ODH_MANIFESTS_DIR/${target_modelmesh_dir}/odh-modelmesh-controller/runtimes $MANIFESTS_DIR/.
  # Remove not supported runtimes
  pushd $MANIFESTS_DIR/runtimes
    kustomize edit remove transformer ../default/metadataLabelTransformer.yaml
    sed 's+ClusterServingRuntime+ServingRuntime+g' -i ./*

    openvino_img=$(cat $MANIFESTS_DIR/params.env |grep odh-openvino|cut -d= -f2)
    sed "s+\$(odh-openvino)+${openvino_img}+g" -i ./*
  popd
fi

# $SCRIPT_DIR/deploy_nfs_provisioner.sh $namespace
echo "* Deploying NFS provisioner for RWM PVCs"
oc get ns nfs-provisioner|| $SCRIPT_DIR/deploy_nfs_provisioner.sh nfs-provisioner

info ".. Creating a namespace for fvt test"
oc get ns $namespace || oc new-project $namespace #for openshift-ci
oc project $namespace || echo "ignored this due to openshift-ci"
oc apply -f $MANIFESTS_DIR/mm-configmap.yaml -n $namespace 

# Download images on each node
echo "* Download Images on Nodes"
if [[ ${allowedImgName} == "true" ]]; then
  echo "NAMESPACE=$namespace TAG=$tag IMAGE_NAME=$img_name IMAGE_URL=$img_url"
  $SCRIPT_DIR/download_images_on_nodes.sh $namespace $tag $img_name $img_url
else
  echo "NAMESPACE=$namespace TAG=$tag"
  $SCRIPT_DIR/download_images_on_nodes.sh $namespace $tag
fi

# Deploy fvt
info ".. Deploying fvt objects"
pushd $MANIFESTS_DIR/fvt
kustomize edit set namespace "${namespace}"
popd

kustomize build $MANIFESTS_DIR/fvt/ |oc apply -f -

info ".. Waiting for dependent pods to be up ..."
wait_for_pods_ready "-l app=minio" "${namespace}"

# pvc initialize for fvt test.
info ".. Waiting for FVT PVC storage to be initialized ..."
oc wait --for=condition=complete --timeout=180s job/pvc-init -n "${namespace}"

# Setup the namespace for modelmesh test
info ".. Adding modelmesh-enabled label to namespace"
oc label namespace ${namespace} modelmesh-enabled=true --overwrite=true

info ".. Deploying servingRuntime"
kustomize build $MANIFESTS_DIR/runtimes/ |oc apply -n "${namespace}" -f -

info ".. Creating a rolebinding for sa 'modelmesh-seving-sa' which is managed by odh-model-controller with inferenceservice"
oc get sa modelmesh-serving-sa -n "${namespace}" || oc create sa modelmesh-serving-sa -n "${namespace}"
oc get clusterrolebinding "${namespace}"-modelmesh-serving-sa-auth-delegator || sed "s/%namespace%/${namespace}/g" $MANIFESTS_DIR/modelmesh-serving-sa-rolebinding.yaml | oc apply -n "${namespace}" -f -

# Create a SA "prometheus-ns-access" becuase odh-model-controller create rolebinding "prometheus-ns-access" with the SA where namespaces have modelmesh-enabled=true label
oc get sa prometheus-ns-access -n "${namespace}" || oc create sa prometheus-ns-access -n "${namespace}"

cat <<EOF | oc apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-all
  namespace: modelmesh-serving
spec:
  podSelector: {} 
  ingress:
  - {}  
  egress:
  - {}  
  policyTypes:
  - Ingress
  - Egress
EOF

success "[SUCCESS] Ready to do fvt test"
