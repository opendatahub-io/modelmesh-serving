#!/bin/bash

source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/utils.sh"

BASE_HOME=/tmp
DIR_NAME=modelmesh
POSTFIX=$(date  "+%Y%m%d%m%s")

export EXIST_MANIFESTS=model-mesh
export ODH_MODEL_CONTROLLER_BRANCH=main
create_new_dir=false

function showHelp() {
  echo "usage: $0 [flags]"
  echo
  echo "Flags:"
  echo "  -p, --stable-manifests       (optional) Use stable manifests. By default, it will use the latest manifests (default false)."
  echo "  -b, --clone-branch           (optional) Use other branch to clone. By default, it will use the main branch (default main)."
  echo "  -n, --create-new-dir         (optional) Use a new directory. By default, it uses the existing directory if it exists (default false)."
  echo
  echo "Generate odh-manifest for odh-model-controller"
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
  -b | --b | -clone-branch | --clone-branch)
    shift
    export ODH_MODEL_CONTROLLER_BRANCH="$1"
    ;;   
  -n | --n | -create-new-dir | --create-new-dir)
    create_new_dir=true
    ;;        
  -*)
    die "Unknown option: '${1}'"
    ;;       
  esac
  shift
done    

if [[ $ODH_MODEL_CONTROLLER_BRANCH == main ]] && [[ $EXIST_MANIFESTS != model-mesh ]];then
  die "You set --clone-branch without --stable-manifests. It is usually a mismatch so please check the right branch again(Refer to version file)"
elif [[ $ODH_MODEL_CONTROLLER_BRANCH != main ]] && [[ $EXIST_MANIFESTS != model-mesh_stable ]];then
  die "You set --stable-manifests without --clone-branch. It is usually a mismatch so please check the right branch again(Refer to version file)"
fi

if [[ $create_new_dir == "true" ]]; then
  rm $SCRIPT_DIR/.temp_new_modelmesh_manifests
fi
  
if [[ -f  $SCRIPT_DIR/.temp_new_modelmesh_manifests ]]; then
 export FULL_DIR_NAME=$(cat $SCRIPT_DIR/.temp_new_modelmesh_manifests)
else
  export FULL_DIR_NAME="$DIR_NAME-$POSTFIX"
  echo ${FULL_DIR_NAME} > $SCRIPT_DIR/.temp_new_modelmesh_manifests
fi 

export TARGET_DIR=${BASE_HOME}/${FULL_DIR_NAME}
export ODH_MODEL_CONTROLLER_DIR=${TARGET_DIR}/model-mesh_templates/odh-model-controller
ODH_MODEL_CONTROLLER_GIT=https://github.com/opendatahub-io/odh-model-controller.git

info "Generate opendatahub manifest in the ${TARGET_DIR}"
echo "TARGET DIR: ${TARGET_DIR}"
echo "--------------------------------------------------"
echo 

if [[ ! -d ${TARGET_DIR} ]]; then
  echo -n ".. Creating a ${TARGET_DIR} folder"
  mkdir -p ${TARGET_DIR}
else
  echo -n ".. ${TARGET_DIR} folder exist, it will reuse the existing folder"
fi
echo -e "\r ✓"
cd ${TARGET_DIR}

if [[ ! -d ${TARGET_DIR}/odh-model-controller ]]; then
  echo -n ".. Git Cloning odh-model-controller(branch: $ODH_MODEL_CONTROLLER_BRANCH)  to ${TARGET_DIR} folder"
  git clone  --quiet --branch $ODH_MODEL_CONTROLLER_BRANCH $ODH_MODEL_CONTROLLER_GIT
else
  echo -n ".. odh-model-controller folder exist,it will reuse the existing folder"
fi
echo -e "\r ✓"

# Copy manifests templates
if [[ ! -d ${TARGET_DIR}/model-mesh_templates ]]; then
  echo -n ".. Copying the model-mesh_templates to ${TARGET_DIR} folder"
  
  if [[ $EXIST_MANIFESTS == model-mesh ]]; then
    cp -R $ODH_MANIFESTS_DIR/model-mesh_templates ${TARGET_DIR}/
  else
    cp -R $ODH_MANIFESTS_DIR/model-mesh_templates_stable ${TARGET_DIR}/model-mesh_templates
  fi
else
  echo -n ".. model-mesh_template folder exist, it will reuse the existing folder"
fi
echo -e "\r ✓"

echo -n ".. Copying the odh-model-controller manifests to model-mesh_templates folder"
cp -R odh-model-controller/config/*  ${ODH_MODEL_CONTROLLER_DIR}/.
echo -e "\r ✓"

# Update manifests based on stable or latest
if [[ $EXIST_MANIFESTS == model-mesh ]]; then
  . ${SCRIPT_DIR}/gen-manifests/odh_model_manifests.sh
else 
  . ${SCRIPT_DIR}/gen-manifests/odh_model_manifests_stable.sh
fi

IS_IDENTICAL=$(diff -r ${TARGET_DIR}/model-mesh_templates/odh-model-controller/ ${ODH_MANIFESTS_DIR}/${EXIST_MANIFESTS}/odh-model-controller/)

if [[ z$IS_IDENTICAL == z ]]; then
  success "New Manifests are identical with previous one. You don't need to send any PR to ODH-MANIFESTS repo"
else
  info "diff -ruN ${ODH_MANIFESTS_DIR}/${EXIST_MANIFESTS}/odh-model-controller/ ${TARGET_DIR}/model-mesh_templates/odh-model-controller/"
  echo

  die "There are some changes between new manifests and previous one. You should validate the new manifests. If it works, you need to update opendatahub/odh-manifests/${EXIST_MANIFESTS} and opendatahub/odh-manifests/model-mesh_templates"
fi
