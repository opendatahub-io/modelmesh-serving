#!/bin/bash

die() {
  color_red='\e[31m'
  color_yellow='\e[33m'
  color_reset='\e[0m'
  printf "${color_red}FATAL:${color_yellow} $*${color_reset}\n" 1>&2
  exit 10
}

info() {
  color_blue='\e[34m'
  color_reset='\e[0m'
  printf "${color_blue}$*${color_reset}\n" 1>&2
}

success() {
  color_green='\e[32m'
  color_reset='\e[0m'
  printf "${color_green}$*${color_reset}\n" 1>&2
}

images_name=(modelmesh odh-modelmesh-controller modelmesh-runtime-adapter rest-proxy odh-model-controller)

checkAllowedImage() {  
  local img_name=$1
  for img in "${images_name[@]}"
  do
    if [[ $img == ${img_name} ]];then    
      return 0
      break
    fi
  done

  die "The image ${img_name} is not in allow list"
  return 1
}

check_pod_status() {
  local -r JSONPATH="{range .items[*]}{'\n'}{@.metadata.name}:{@.status.phase}:{range @.status.conditions[*]}{@.type}={@.status};{end}{end}"
  local -r pod_selector="$1"
  local -r pod_namespace="$2"
  local pod_status
  local pod_entry

  pod_status=$(oc get pods $pod_selector -n $pod_namespace -o jsonpath="$JSONPATH") 
  kubectl_exit_code=$? # capture the exit code instead of failing

  if [[ $kubectl_exit_code -ne 0 ]]; then
    # kubectl command failed. print the error then wait and retry
    echo "Error running kubectl command."
    echo $pod_status
    return 1
  elif [[ ${#pod_status} -eq 0 ]]; then
    echo -n "No pods found with selector $pod_selector in $pod_namespace. Pods may not be up yet."
    return 1
  else
    # split string by newline into array
    IFS=$'\n' read -r -d '' -a pod_status_array <<<"$pod_status"

    for pod_entry in "${pod_status_array[@]}"; do
      local pod=$(echo $pod_entry | cut -d ':' -f1)
      local phase=$(echo $pod_entry | cut -d ':' -f2)
      local conditions=$(echo $pod_entry | cut -d ':' -f3)
      if [ "$phase" != "Running" ] && [ "$phase" != "Succeeded" ]; then
        return 1
      fi
      if [[ $conditions != *"Ready=True"* ]]; then
        return 1
      fi
    done
  fi
  return 0
}

wait_for_pods_ready() {
  local -r JSONPATH="{.items[*]}"
  local -r pod_selector="$1"
  local -r pod_namespace=$2
  local wait_counter=0
  local kubectl_exit_code=0
  local pod_status

  while true; do
    pod_status=$(oc get pods $pod_selector -n $pod_namespace -o jsonpath="$JSONPATH") 
    kubectl_exit_code=$? # capture the exit code instead of failing

    if [[ $kubectl_exit_code -ne 0 ]]; then
      # kubectl command failed. print the error then wait and retry
      echo $pod_status
      echo -n "Error running kubectl command."
    elif [[ ${#pod_status} -eq 0 ]]; then
      echo -n "No pods found with selector '$pod_selector' -n '$pod_namespace'. Pods may not be up yet."
    elif check_pod_status "$pod_selector" "$pod_namespace"; then
      echo "All $pod_selector pods in '$pod_namespace' namespace are running and ready."
      return
    else
      echo -n "Pods found with selector '$pod_selector' in '$pod_namespace' namespace are not ready yet."
    fi

    if [[ $wait_counter -ge 60 ]]; then
      echo
      oc get pods $pod_selector -n $pod_namespace
      die "Timed out after $((10 * wait_counter / 60)) minutes waiting for pod with selector: $pod_selector"
    fi

    wait_counter=$((wait_counter + 1))
    echo " Waiting 10 secs ..."
    sleep 10
  done
}

wait_downloading_images(){
  images=$1
  namespace=$2

  nodeCount=$(oc get node|grep worker|grep -v infra|wc -l)
  expectedTotalCount=$((${#images[@]}*${nodeCount}))
  totalCount=0
  retries=0
  max_retries=10
  echo "Node: ${nodeCount}, Required Images: ${#images[@]}, Expected Downloading Count: ${expectedTotalCount}"

  sleep 10s
  while [[ $totalCount -lt $expectedTotalCount ]]
  do
    totalCount=0
    echo "Downloading required images.. please wait!"    
    for element in "${images[@]}"
    do
      case "$element" in
        *triton*)
            isDownloaded=$(oc describe pod -n $namespace -l app=image-downloader|grep "Successfully pulled image \"${TRITON_SERVER}\""|wc -l)
            existImage=$(oc describe pod -n $namespace -l app=image-downloader|grep "Container image \"${TRITON_SERVER}\" already present on machine"|wc -l)
            if [[ ${isDownloaded} != 0 || ${existImage} != 0 ]]; then
                triton_server_count=$(( ${isDownloaded} + ${existImage} ))
                totalCount=$((totalCount + ${triton_server_count}))
                echo "triton-server-count count: ${triton_server_count} - ${element}"
            fi 
            ;;
        *model_server*)
            isDownloaded=$(oc describe pod -n $namespace -l app=image-downloader|grep "Successfully pulled image \"${OPENVINO}\""|wc -l)
            existImage=$(oc describe pod -n $namespace -l app=image-downloader|grep "Container image \"${OPENVINO}\" already present on machine"|wc -l)
            if [[ ${isDownloaded} != 0 || ${existImage} != 0 ]]; then
                openvino_count=$(( ${isDownloaded} + ${existImage} ))
                totalCount=$((totalCount + ${openvino_count}))
                echo "openvino downloaded: ${openvino_count} - ${element}"
            fi
            ;;

        *mlserver*)
            isDownloaded=$(oc describe pod -n $namespace -l app=image-downloader|grep "Successfully pulled image \"${ML_SERVER}\""|wc -l)
            existImage=$(oc describe pod -n $namespace -l app=image-downloader|grep "Container image \"${ML_SERVER}\" already present on machine"|wc -l)
            if [[ ${isDownloaded} != 0 || ${existImage} != 0 ]]; then
                ml_server_count=$(( ${isDownloaded} + ${existImage} ))
                totalCount=$((totalCount + ${ml_server_count} ))
                echo "ml-server downloaded: ${ml_server_count} - ${element}"
            fi
            ;;

        *torchserve*)
            isDownloaded=$(oc describe pod -n $namespace -l app=image-downloader|grep "Successfully pulled image \"${TORCHSERVE}\""|wc -l)
            existImage=$(oc describe pod -n $namespace -l app=image-downloader|grep "Container image \"${TORCHSERVE}\" already present on machine"|wc -l)
            if [[ ${isDownloaded} != 0 || ${existImage} != 0 ]]; then
                torchserve_count=$(( ${isDownloaded} + ${existImage} ))
                totalCount=$((totalCount + ${torchserve_count} ))
                echo "torchserve downloaded: ${torchserve_count} - ${element}"
            fi
            ;;

        *modelmesh:*)
            isDownloaded=$(oc describe pod -n $namespace -l app=image-downloader|grep "Successfully pulled image \"${MODELMESH}\""|wc -l)
            existImage=$(oc describe pod -n $namespace -l app=image-downloader|grep "Container image \"${MODELMESH}\" already present on machine"|wc -l)
            if [[ ${isDownloaded} != 0 || ${existImage} != 0 ]]; then
                modelmesh_count=$(( ${isDownloaded} + ${existImage} ))
                totalCount=$((totalCount + ${modelmesh_count}))
                echo "modelmesh downloaded: ${modelmesh_count} -${element}"
            fi
            ;;

        *modelmesh-runtime*)
            isDownloaded=$(oc describe pod -n $namespace -l app=image-downloader|grep "Successfully pulled image \"${MODELMESH_RUNTIME}\""|wc -l)
            existImage=$(oc describe pod -n $namespace -l app=image-downloader|grep "Container image \"${MODELMESH_RUNTIME}\" already present on machine"|wc -l)
            if [[ ${isDownloaded} != 0 || ${existImage} != 0 ]]; then
                modlemesh_runtime_count=$(( ${isDownloaded} + ${existImage} ))
                totalCount=$((totalCount + ${modlemesh_runtime_count} ))
                echo "modelmesh-runtime downloaded: ${modlemesh_runtime_count} - ${element}"
            fi
            ;;

        *rest-proxy*)
            isDownloaded=$(oc describe pod -n $namespace -l app=image-downloader|grep "Successfully pulled image \"${REST_PROXY}\""|wc -l)
            existImage=$(oc describe pod -n $namespace -l app=image-downloader|grep "Container image \"${REST_PROXY}\" already present on machine"|wc -l)
            if [[ ${isDownloaded} != 0 || ${existImage} != 0 ]]; then
                rest_proxy_count=$(( ${isDownloaded} + ${existImage} ))
                totalCount=$((totalCount + ${rest_proxy_count} ))
                echo "rest-proxy downloaded: ${rest_proxy_count} - ${element}"
            fi
            ;;
        *pipeline*)
            isDownloaded=$(oc describe pod -n $namespace -l app=image-downloader|grep "Successfully pulled image \"${element}\""|wc -l)
            existImage=$(oc describe pod -n $namespace -l app=image-downloader|grep "Container image \"${element}\" already present on machine"|wc -l)
            if [[ ${isDownloaded} != 0 || ${existImage} != 0 ]]; then
                custom_img_count=$(( ${isDownloaded} + ${existImage} ))
                totalCount=$((totalCount + ${custom_img_count} ))
                echo "custom image downloaded: ${custom_img_count} - ${element}"
            fi
            ;;
        *)
          echo "Not expected images(${element})"
          exit 1
          ;;
      esac
    done
    # echo "2- $totalCount"
    # echo "3- $expectedTotalCount"
    # echo "4- $retries"
    # echo "5- $max_retries"

    if [[ $totalCount -lt $expectedTotalCount ]]; then
      if [[ ${retries} -lt ${max_retries} ]]; then
        echo 
        retries=$((retries + 1 ))
        echo "Reset totalCount = 0 and checking it again after 60s"
        sleep 60s
      else 
        echo "Exceed max retries(${max_retries})"
        return 1
      fi
    else
      echo "All images are downloaded"
    fi
  done
}

# install required binaries based on current architecture
install_binaries() {
  ARCH=$(uname -m)
  # Replace x86_64 with amd64 if necessary
  if [ "${ARCH}" == "x86_64" ]; then
      ARCH="amd64"
  fi
  OS=$(uname | tr '[:upper:]' '[:lower:]')

  info ".. Downloading binaries"
  if [[ ! -d ${ROOT_DIR}/bin ]]; then
    info ".. Creating a bin folder"
    mkdir -p ${ROOT_DIR}/bin
  fi

  if type yq &> /dev/null; then
    info "yq already installed."
  else
    info "Installing yq."
    # Download and install yq
    curl -sSLf --output /tmp/yq.tar.gz "https://github.com/mikefarah/yq/releases/download/v4.33.3/yq_${OS}_${ARCH}.tar.gz"
    tar xvf /tmp/yq.tar.gz -C /tmp
    mv /tmp/yq_linux_amd64 "${ROOT_DIR}/bin/yq"
    rm /tmp/yq.tar.gz
  fi

  KUSTOMIZE_VERSION=5.2.1
  if type kustomize &> /dev/null; then
    INSTALLED_KUSTOMIZE_VERSION=$(kustomize version | grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+')
    if [ "v${KUSTOMIZE_VERSION}" = "$INSTALLED_KUSTOMIZE_VERSION" ]; then
      info "kustomize already installed with correct version..."
    else
      install_kustomize "${KUSTOMIZE_VERSION}"
    fi
  else
    install_kustomize "${KUSTOMIZE_VERSION}"
  fi
}

install_kustomize() {
  KUSTOMIZE_VERSION=$1
  info "Installing kustomize."
  curl -sSLf --output /tmp/kustomize.tar.gz https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_${OS}_${ARCH}.tar.gz
  tar -xvf /tmp/kustomize.tar.gz -C /tmp
  mv /tmp/kustomize  ${ROOT_DIR}/bin
  chmod a+x  ${ROOT_DIR}/bin
  rm /tmp/kustomize.tar.gz
  info "installed kustomize version $(kustomize version)"
}

