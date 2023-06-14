#!/bin/bash

source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/utils.sh"

export BASE_HOME=/tmp
export DIR_NAME=modelmesh
export POSTFIX=$(date  "+%Y%m%d%m%s")

export EXIST_MANIFESTS=model-mesh

function showHelp() {
  echo "usage: $0 [flags]"
  echo
  echo "Flags:"
  echo "  -p, --stable-manifests         (optional) Use stable manifests. By default, it will use the latest manifests (default false)."
  echo
  echo "Copy the generated new odh-manifest to opendatahub/odh-manifests/model-mesh,model-mesh_stable"
}

while (($# > 0)); do
  case "$1" in
  -h | --h | --he | --hel | --help)
    showHelp
    exit 2
    ;;
  -p | --p | -stable-manifests | --stable-manifests)
    export EXIST_MANIFESTS=model-mesh_stable
    ;;       
  -*)
    die "Unknown option: '${1}'"
    ;;       
  esac
  shift
done   


if [[ -f  $SCRIPT_DIR/.temp_new_modelmesh_manifests ]]; then
 export FULL_DIR_NAME=$(cat $SCRIPT_DIR/.temp_new_modelmesh_manifests)
else
  FULL_DIR_NAME="$DIR_NAME-$POSTFIX"
  echo ${FULL_DIR_NAME} > $SCRIPT_DIR/.temp_new_modelmesh_manifests
fi 

export TARGET_DIR=${BASE_HOME}/${FULL_DIR_NAME}

if [[ ! -d ${TARGET_DIR}/model-mesh_templates ]]; then
  die "You must execute gen_odh_model_manifests.sh/gen_odh_modelmesh_manifests.sh first"
else
  if [[ ! -d ${ODH_MANIFESTS_DIR}/${EXIST_MANIFESTS}_ori ]]; then
    echo -n ".. Change existing manifest from $EXIST_MANIFESTS to ${EXIST_MANIFESTS}_ori"
    mv ${ODH_MANIFESTS_DIR}/${EXIST_MANIFESTS} ${ODH_MANIFESTS_DIR}/${EXIST_MANIFESTS}_ori
  else 
    die ".. ${EXIST_MANIFESTS}_ori exist, if you want to overwrite it, you need to remove the folder manually"
  fi
  echo -e "\r ✓"

  echo -n ".. Copy the patched new manifests into $ODH_MANIFESTS_DIR/$EXIST_MANIFESTS folder for test"
  cp -R ${TARGET_DIR}/model-mesh_templates  ${ODH_MANIFESTS_DIR}/${EXIST_MANIFESTS}
fi
echo -e "\r ✓"
