#!/bin/bash

source "$(dirname "$0")/env.sh"
source "$(dirname "$0")/utils.sh"

namespace=$1 
controllerns=$2
nsscope=$3

retry=10
count=1

if [[ z$controllerns == z ]]; then
  controllerns=${namespace}
fi

if [[ z$nsscope == z ]]; then
  nsscope=false
fi

info "* Start FVT test"
echo "namespace=${namespace}, controllerns=${controllerns}, nsscope=${nsscope}"

echo CONTROLLERNAMESPACE=$controllerns NAMESPACE=$namespace NAMESPACESCOPEMODE=$nsscope make fvt
CONTROLLERNAMESPACE=$controllerns NAMESPACE=$namespace NAMESPACESCOPEMODE=$nsscope make fvt

fvt_result=$?
echo "$fvt_result"
while [[ $fvt_result != 0 ]]
do
  if [[ $retry != $count ]];then
    info "fvt test failed. Retry it : retry count($count)"
    echo "Rollback minio storage secret"
    sed "s/controller_namespace/${namespace}/g" opendatahub/scripts/manifests/fvt/minio-storage-secret.yaml | oc apply -n $namespace  -f -
    
    echo "Restart ServingRuntime and controllers"
    oc delete pod -n $namespace -l modelmesh-service=modelmesh-serving 
    oc delete pod -n $controllerns -l app=odh-model-controller 
    oc delete pod -n $controllerns -l control-plane=modelmesh-controller
    
    wait_for_pods_ready "-l control-plane=modelmesh-controller" "$controllerns"
    
    # wait_for_pods_ready "-l app=odh-model-controller" "$controllerns" 

    echo "Waiting 60 secs before retrying"
    sleep 60 
    count=$((count+1))
    CONTROLLERNAMESPACE=$controllerns NAMESPACE=$namespace NAMESPACESCOPEMODE=$nsscope make fvt
    fvt_result=$?
  else
    die "fvt test failed with $count retries"
  fi
done

success "[SUCCESS] FVT Test Passed!"
