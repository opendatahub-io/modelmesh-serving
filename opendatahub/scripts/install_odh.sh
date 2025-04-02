#!/bin/bash

source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/utils.sh"

tag=none
ctrlnamespace=opendatahub
img_map=none
img_name=
img_url=
mm_user=opendatahub-io
mm_branch=main
odhoperator=true
repo_uri=local
stable_manifests=false

function showHelp() {
  echo "usage: $0 [flags]"
  echo
  echo "Flags:"
  echo "  -c, --ctrl-namespace           (optional) Kubernetes namespace to deploy modelmesh controller to(default opendatahub)."
  echo "  -t, --tag                      (optional) Set tag fast,stable to change images quickly(default none)."
  echo "  -r, --repo-uri                 (optional) Set repo-uri local,remote to change repo uri to use local gzip(default local)."
  echo "  -i, --image                    (optional) Set custom image (default none). Example: --image odh-model-controller=quay.io/spolti/odh-model-controller-test:1.0"
  echo "  -p, --stable-manifests         (optional) Use stable manifests. By default, it will use the latest manifests (default false)."
  echo "  -op, --operator                (optional) Install opendatahub operator"
  echo "  -u, --user                     (optional) Set odh-manifests repo user to be used for deployment(default opendatahub-io) - modelmesh/odh-modelmesh-controller/modelmesh-runtime-adapter/rest-proxy/odh-model-controller."
  echo "                                   ex) -u opendatahub-io"
  echo "                                   meaning > https://api.github.com/repos/opendatahub-io"
  echo "  -b, --branch                   (optional) Set odh-manifests repo branch to be used for deployment (default main)."
  echo "                                   ex) -i rest-proxy=quay.io/opendatahub/rest-proxy:pr-89"
  echo
  echo "Installs modelmesh controller."
}


while (($# > 0)); do
  case "$1" in
  -h | --h | --he | --hel | --help)
    showHelp
    exit 2
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
    echo $img_name=$img_url
    ;;    
  -t | --t | -tag | --tag)
    shift
    tag="$1"
    ;;    
  -op | --op | -operator | --operator)
    odhoperator=true
    ;;    
  -u | --u | -user | --user)
    shift
    mm_user="$1"
    ;;    
  -b | --b | -branch | --branch)
    shift
    mm_branch="$1"
    ;;    
  -r | --r | -repo-uri | --repo-uri)
    shift
    repo_uri="$1"
    ;;   
  -p | --p | -stable-manifests | --stable-manifests)
    stable_manifests=true
    if [[ $repo_uri != "local" ]];then
      die "Do NOT allow to set '--stable-manifests=true' and '--repo-uri=remote' together"
    fi
    ;;         
  -*)
    die "Unknown option: '${1}'"
    ;;       
  esac
  shift
done    

install_binaries

allowedImgName=false
if [[ ${img_map} != none ]]; then
  checkAllowedImage "${img_name}"
  if [[ $? == 0 ]]; then
    allowedImgName=true
  fi
fi

if [[ -d ${MM_HOME_DIR} ]]; then
  info "Delete the exising ${MM_HOME_DIR} folder"
  rm -rf "${MM_HOME_DIR}"
fi

info "Creating a ${MM_HOME_DIR} folder"
mkdir -p "${MM_HOME_DIR}"


oc project ${ctrlnamespace} || oc new-project ${ctrlnamespace}

if [[ ${odhoperator} == "true" ]]; then
  oc apply -f ${MANIFESTS_DIR}/subs_odh_operator.yaml

  op_ready=$(oc get csv -n ${ctrlnamespace} |grep opendatahub|grep Succeeded|wc -l)
  while [[ $op_ready != 1 ]]
  do
    info ".. Waiting for opendatahub operator running"
    op_ready=$(oc get csv -n ${ctrlnamespace} |grep opendatahub|grep Succeeded|wc -l)
    echo ".. Will check it 30 Secs later"
    sleep 30
  done
  info ".. Opendatahub operator is ready"
  info ".. Creating the DSC in ${ctrlnamespace}"
  oc apply -n ${ctrlnamespace} -f "${MANIFESTS_DIR}/dsc.yaml" 
else
  info ".. Archiving odh-manifests"
  archive_root_folder="/tmp"
  archive_folder="${archive_root_folder}/modelmesh-serving"
  rm -rf ${archive_folder}
  mkdir ${archive_folder}
  cp -R "${MM_MANIFESTS_DIR}" ${archive_folder}/config/
  cp -R "${MANIFESTS_DIR}" ${archive_folder}/.

  PARAMS="${archive_folder}/config/overlays/odh/params.env"

  if [[ ${stable_manifests} == "true" ]]; then
    info "Stable Manifest is Set, using release tag."
    sed "s/fast/stable/g" -i "${PARAMS}"
  else
    info "Latest Manifest will be used, fast tag"
  fi


  info ".. Deploying ModelMesh with kustomize"
  # here need to update the images
  if [[ ${allowedImgName} == "true" ]]; then
    if  [[ (${tag} == "fast") || (${tag} == "stable") ]] ; then
      if [[ ${img_name} == "odh-modelmesh-controller" ]]; then
        sed "s+quay.io/.*modelmesh-controller:.*$+${img_url}+g" -i "${PARAMS}"
      else
        sed "s+quay.io/.*${img_name}:.*$+${img_url}+g" -i "${PARAMS}"
      fi
    elif [[ ${tag} == "none" ]] || [[ ${tag} == "local" ]]; then
      custom_name="${img_name}"
      custom_value="${img_url}"
      echo "${img_name}" "${img_url}"
      sed "s|^${img_name}=.*$|${img_name}=${img_url}|" -i "${PARAMS}"
    fi
  fi

  # append namespace param:
  echo "mesh-namespace=${ctrlnamespace}" >> "${PARAMS}"
  info "params.env:"
  info "$(cat ${PARAMS})"

  # info "installing namespaced rbac"
  kustomize build "${archive_folder}"/config/rbac/namespace-scope | oc apply -n modelmesh-serving  f -

  # we want mm namespaced
  kustomize build "${archive_folder}"/config/namespace-runtimes  | oc apply -n "${ctrlnamespace}" -f -
  kustomize build "${archive_folder}"/config/overlays/odh | oc apply -n "${ctrlnamespace}" -f -
fi

wait_for_pods_ready "-l control-plane=modelmesh-controller" "${ctrlnamespace}"

success "[SUCCESS] ModelMesh is Running"
