#!/bin/bash

source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/utils.sh"

export BASE_HOME=/tmp
export DIR_NAME=modelmesh
export POSTFIX=$(date  "+%Y%m%d%m%s")

export EXIST_MANIFESTS=model-mesh
export MODELMESH_CONTROLLER_BRANCH=main
export CURRENT_CONFIG_DIR=$ROOT_DIR/config
create_new_dir=false
copy_current_config_dir=false

function showHelp() {
  echo "usage: $0 [flags]"
  echo
  echo "Flags:"
  echo "  -p, --stable-manifests         (optional) Use stable manifests. By default, it will use the latest manifests (default false)."
  echo "  -b, --clone-branch             (optional) Use other branch to clone. By default, it will use the main branch (default main)."
  echo "  -n, --create-new-dir           (optional) Use a new directory. By default, it uses the existing directory if it exists (default false)."
  echo "  -c, --copy-current-config-dir  (optional) Use a current config directory to compare. By default, it uses the existing config directory instead of cloning git repository (default false)."
  echo
  echo "Generate odh-manifest for odh-modelmesh-controller"
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
    export MODELMESH_CONTROLLER_BRANCH="$1"
    ;;   
  -n | --n | -create-new-dir | --create-new-dir)
    create_new_dir=true
    ;;   
  -c | --c | -copy-current-config-dir | --copy-current-config-dir)
    copy_current_config_dir=true
    ;;            
  -*)
    die "Unknown option: '${1}'"
    ;;       
  esac
  shift
done    

if [[ $MODELMESH_CONTROLLER_BRANCH == main ]] && [[ $EXIST_MANIFESTS != model-mesh ]];then
  die "You set --clone-branch without --stable-manifests. It is usually a mismatch so please check the right branch again(Refer to version file)"
elif [[ $MODELMESH_CONTROLLER_BRANCH != main ]] && [[ $EXIST_MANIFESTS != model-mesh_stable ]];then
  die "You set --stable-manifests without --clone-branch. It is usually a mismatch so please check the right branch again(Refer to version file)"
fi

if [[ $create_new_dir == "true" ]]; then
  rm $SCRIPT_DIR/.temp_new_modelmesh_manifests
fi

if [[ -f  $SCRIPT_DIR/.temp_new_modelmesh_manifests ]]; then
 export FULL_DIR_NAME=$(cat $SCRIPT_DIR/.temp_new_modelmesh_manifests)
else
  FULL_DIR_NAME="$DIR_NAME-$POSTFIX"
  echo ${FULL_DIR_NAME} > $SCRIPT_DIR/.temp_new_modelmesh_manifests
fi 

export TARGET_DIR=${BASE_HOME}/${FULL_DIR_NAME}
export MODELMESH_CONTROLLER_DIR=${TARGET_DIR}/model-mesh_templates/odh-modelmesh-controller
MODELMESH_CONTROLLER_GIT=https://github.com/opendatahub-io/modelmesh-serving.git

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

if [[ $copy_current_config_dir == "false" ]]; then
  if [[ ! -d ${TARGET_DIR}/odh-modelmesh-controller ]]  then
      echo -n ".. Git Cloning odh-modelmesh-controller(branch: $MODELMESH_CONTROLLER_BRANCH) to ${TARGET_DIR} folder"
      git clone --quiet --branch $MODELMESH_CONTROLLER_BRANCH $MODELMESH_CONTROLLER_GIT odh-modelmesh-controller
  else
    echo -n ".. odh-modelmesh-controller folder exist,it will reuse the existing folder"
  fi
  echo -e "\r ✓"
fi

# Copy manifests templates
if [[ $copy_current_config_dir == "false" ]]; then
  echo -n ".. Copying the odh-modelmesh-controller manifests to model-mesh_templates folder"
  cp -R odh-modelmesh-controller/config/*  ${MODELMESH_CONTROLLER_DIR}/.
else 
  echo -n ".. Copy config folder to ${TARGET_DIR} folder"
  cp -R ${CURRENT_CONFIG_DIR}/*  ${MODELMESH_CONTROLLER_DIR}/.
fi
echo -e "\r ✓"

# Update manifests based on stable or latest
if [[ $EXIST_MANIFESTS == model-mesh ]]; then
  . ${SCRIPT_DIR}/gen-manifests/odh_modelmesh_manifests.sh
else 
  . ${SCRIPT_DIR}/gen-manifests/odh_modelmesh_manifests_stable.sh
fi

IS_IDENTICAL=$(diff -r ${TARGET_DIR}/model-mesh_templates/odh-modelmesh-controller/ ${ODH_MANIFESTS_DIR}/${EXIST_MANIFESTS}/odh-modelmesh-controller/)

if [[ z$IS_IDENTICAL == z ]]; then
  success "New Manifests are identical with previous one. You don't need to send any PR to ODH-MANIFESTS repo"
else
  info "diff -ruN ${ODH_MANIFESTS_DIR}/${EXIST_MANIFESTS}/odh-modelmesh-controller/ ${TARGET_DIR}/model-mesh_templates/odh-modelmesh-controller/ "
  echo
  
  die "There are some changes between new manifests and previous one. You should validate the new manifests. If it works, you need to update opendatahub/odh-manifests/${EXIST_MANIFESTS} and opendatahub/odh-manifests/model-mesh_templates"
fi
