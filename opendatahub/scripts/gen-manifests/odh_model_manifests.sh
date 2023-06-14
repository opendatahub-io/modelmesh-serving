#!/bin/bash

echo -n ".. Delete crd folder"
rm -rf ${ODH_MODEL_CONTROLLER_DIR}/crd
echo -e "\r ✓"

echo -n ".. Update kustomization.yaml in default folder"
if [[ $(grep external ${ODH_MODEL_CONTROLLER_DIR}/default/kustomization.yaml|wc -l) != 0 ]]; then
  sed '/external/d' -i ${ODH_MODEL_CONTROLLER_DIR}/default/kustomization.yaml
  sed '/namespace/d' -i ${ODH_MODEL_CONTROLLER_DIR}/default/kustomization.yaml
  sed '/^$/d' -i ${ODH_MODEL_CONTROLLER_DIR}/default/kustomization.yaml
fi
echo -e "\r ✓"

echo -n ".. Update kustomization.yaml in manager folder"
sed '/namespace.yaml/d' -i ${ODH_MODEL_CONTROLLER_DIR}/manager/kustomization.yaml
if [[ $(grep images ${ODH_MODEL_CONTROLLER_DIR}/manager/kustomization.yaml|wc -l) != 0 ]]; then
  sed '/images/,$d' -i ${ODH_MODEL_CONTROLLER_DIR}/manager/kustomization.yaml
  sed '$d' -i ${ODH_MODEL_CONTROLLER_DIR}/manager/kustomization.yaml
fi
echo -e "\r ✓"

if [[ -f ${ODH_MODEL_CONTROLLER_DIR}/manager/namespace.yaml ]]; then
  echo -n ".. Delete namespace.yaml file"
  rm ${ODH_MODEL_CONTROLLER_DIR}/manager/namespace.yaml
else
  echo -n ".. namespace.yaml file was already deleted"
fi
echo -e "\r ✓"

echo -n ".. Add mesh-namespace into role_binding.yaml in rbac folder"
sed 's+odh-model-controller-rolebinding$+odh-model-controller-rolebinding-$(mesh-namespace)+g' -i ${ODH_MODEL_CONTROLLER_DIR}/rbac/role_binding.yaml
echo -e "\r ✓"
