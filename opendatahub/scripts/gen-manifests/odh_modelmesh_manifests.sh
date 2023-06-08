#!/bin/bash

# Update files for Opendatahub
echo -n ".. Comment out ClusterServingRuntime"
sed 's+- bases/serving.kserve.io_clusterservingruntimes.yaml+# - bases/serving.kserve.io_clusterservingruntimes.yaml+g' -i ${MODELMESH_CONTROLLER_DIR}/crd/kustomization.yaml
echo -e "\r ✓"

echo -n ".. Remove builtInServerTypes"
sed '/builtInServerTypes/,$d' -i ${MODELMESH_CONTROLLER_DIR}/default/config-defaults.yaml
echo -e "\r ✓"

echo -n ".. Add parameter variable into modelmesh-controller-rolebinding"
sed 's+modelmesh-controller-rolebinding$+modelmesh-controller-rolebinding-$(mesh-namespace)+g' -i ${MODELMESH_CONTROLLER_DIR}/rbac/cluster-scope/role_binding.yaml
echo -e "\r ✓"

# Update images to adopt dynamic value using params.env
echo -n ".. Replace each image of the parameter variable 'images'"
sed 's+kserve/modelmesh$+$(odh-modelmesh)+g' -i ${MODELMESH_CONTROLLER_DIR}/default/config-defaults.yaml
sed 's+kserve/rest-proxy$+$(odh-mm-rest-proxy)+g' -i ${MODELMESH_CONTROLLER_DIR}/default/config-defaults.yaml
sed 's+kserve/modelmesh-runtime-adapter$+$(odh-modelmesh-runtime-adapter)+g' -i ${MODELMESH_CONTROLLER_DIR}/default/config-defaults.yaml
sed '/tag:/d' -i ${MODELMESH_CONTROLLER_DIR}/default/config-defaults.yaml

sed 's+modelmesh-controller:replace$+$(odh-modelmesh-controller)+g' -i ${MODELMESH_CONTROLLER_DIR}/manager/manager.yaml

sed 's+ovms-1:replace$+$(odh-openvino)+g' -i ${MODELMESH_CONTROLLER_DIR}/runtimes/ovms-1.x.yaml
echo -e "\r ✓"

echo -n ".. Replace replicas of odh modelmesh controller to 3"
yq e '.spec.replicas = 3' -i ${MODELMESH_CONTROLLER_DIR}/manager/manager.yaml
echo -e "\r ✓"

echo -n ".. Increase manager limit memory size to 2G"
yq e '.spec.template.spec.containers[0].resources.limits.memory = "2Gi"' -i  ${MODELMESH_CONTROLLER_DIR}/manager/manager.yaml
echo -e "\r ✓"

echo -n ".. Add trustAI option into config-defaults.yaml"
yq eval '."payloadProcessors" = ""'  -i ${MODELMESH_CONTROLLER_DIR}/default/config-defaults.yaml
echo -e "\r ✓"

echo -n ".. Remove CertManager related from default/kustomization.yaml"
sed '/certmanager/d' -i ${MODELMESH_CONTROLLER_DIR}/default/kustomization.yaml

licenseNum=$(grep -n vars ${MODELMESH_CONTROLLER_DIR}/default/kustomization.yaml |cut -d':' -f1)
configMapGeneratorStartLine=$(grep -n configMapGenerator  ${MODELMESH_CONTROLLER_DIR}/default/kustomization.yaml |cut -d':' -f1)
configMapGeneratorBeforeLine=$((configMapGeneratorStartLine-1))
sed -i "${licenseNum},${configMapGeneratorBeforeLine}d"  ${MODELMESH_CONTROLLER_DIR}/default/kustomization.yaml

# remove webhookcainjection_patch.yaml
sed -i '/webhookcainjection_patch.yaml/d'  ${MODELMESH_CONTROLLER_DIR}/default/kustomization.yaml
echo -e "\r ✓"

echo -n ".. Add serving-cert-secret-name to webhook/service.yaml"
yq eval '.metadata.annotations."service.beta.openshift.io/serving-cert-secret-name"="modelmesh-webhook-server-cert"' -i  ${MODELMESH_CONTROLLER_DIR}/webhook/service.yaml
echo -e "\r ✓"

echo -n ".. Add inject-cabundle into webhook/kustomization.yaml"
yq eval '.commonAnnotations += {"service.beta.openshift.io/inject-cabundle": "true"}' -i ${MODELMESH_CONTROLLER_DIR}/webhook/kustomization.yaml

echo -n ".. Remove namespace "
sed '/namespace/d' -i  ${MODELMESH_CONTROLLER_DIR}/webhook/service.yaml
echo -e "\r ✓"
