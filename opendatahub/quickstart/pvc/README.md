# Quick Start Guide - PVC Feature

This Quick Start Guide provides instructions for deploying the OpenDataHub Modelserving component along with NFS Provisioner, Minio, and a sample PVC. Additionally, it automatically deploys a sample model and allows you to test OpenDataHub Modelserving using its inference service.

## Prerequisites

You can check prerequisites from [this doc](../README.md)

## Install OpenDataHub ModelServing

Please refer to [this doc](../docs/modelmesh-install.md)

## Deploy a Sample Model from PVC

The `deploy.sh` also deployed a sample model so you don't need to create additional inference service. However, to help you understand, here's a brief description of the inference service manifests yaml.

These are the yaml files that quick start used. There are 2 ways to specify a model path: `storageUri`, `storeagePath`

- **storeagePath**
~~~
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: example-sklearn-isvc
  annotations:
    serving.kserve.io/deploymentMode: ModelMesh
spec:
  predictor:
    model:
      modelFormat:
        name: sklearn
      runtime: mlserver-0.x
      storage:
        parameters:
          type: pvc
          name: model-pvc
        path: sklearn/mnist-svm.joblib
~~~

- **storeageUri**
~~~
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: example-sklearn-isvc
  annotations:
    serving.kserve.io/deploymentMode: ModelMesh
spec:
  predictor:
    model:
      modelFormat:
        name: sklearn
      runtime: mlserver-0.x
      storageUri: pvc://model-pvc/sklearn/mnist-svm.joblib
~~~

### ModelMesh configuration to attach PVC

Modelmesh provide a parameter to a allow runtime pod to attach PVC. `deploy.sh` already created the following configmap in `opendatahub namespace`
~~~
apiVersion: v1
kind: ConfigMap
metadata:
  name: model-serving-config
data:
  config.yaml: |
    allowAnyPVC: true
~~~


### How to check model deployment status
Please refer to [this doc](../basic/README.md#how-to-check-model-deployment-status)

## Perform an inference request

Now that a model is loaded and available, you can then perform inference. OpenDataHub ModelServing has another controller `odh-model-controller` that is responsible for creating OpenShift Route for the model. You can manage the feature with the annotation `enable-route: "true"` in the ServingRuntime. Plus, the controller also manages authentication with the annotation  `enable-auth: "true"` in the ServingRuntime. (By default, both features are disabled but for this quick start, `enable-route` was set to `true`)

**Curl Test wit no authentication enabled**

- *Model Name=isvc-pvc-storage-path*
  ~~~
  export MODEL_NAME=isvc-pvc-storage-path

  export HOST_URL=$(oc get route ${MODEL_NAME} -ojsonpath='{.spec.host}' -n ${TEST_MM_NS})
  export HOST_PATH=$(oc get route ${MODEL_NAME}  -ojsonpath='{.spec.path}' -n ${TEST_MM_NS})

  curl   --silent --location --fail --show-error --insecure https://${HOST_URL}${HOST_PATH}/infer -d  @${COMMON_MANIFESTS_DIR}/input-sklean.json
  ~~~

- *Model Name=isvc-pvc-storage-uri*
  ~~~
  export MODEL_NAME=isvc-pvc-storage-uri

  export HOST_URL=$(oc get route ${MODEL_NAME} -ojsonpath='{.spec.host}' -n ${TEST_MM_NS})
  export HOST_PATH=$(oc get route ${MODEL_NAME}  -ojsonpath='{.spec.path}' -n ${TEST_MM_NS})

  curl   --silent --location --fail --show-error --insecure https://${HOST_URL}${HOST_PATH}/infer -d  @${COMMON_MANIFESTS_DIR}/input-sklean.json
  ~~~

**gRPC Curl Test wit no authentication enabled**

- *Model Name=isvc-pvc-storage-path*
  ~~~
  kubectl port-forward --address 0.0.0.0 service/modelmesh-serving 8033 -n ${TEST_MM_NS} 

  cd ${COMMON_MANIFESTS_DIR}
  export MODEL_NAME=isvc-pvc-storage-path

  grpcurl \
    -plaintext \
    -proto ./proto/grpc_predict_v2.proto \
    -d "$(envsubst <grpc-input-sklean.json )" \
    localhost:8033 \
    inference.GRPCInferenceService.ModelInfer

  cd -
  ~~~
- *Model Name=isvc-pvc-storage-uri*
  ~~~
  kubectl port-forward --address 0.0.0.0 service/modelmesh-serving 8033 -n ${TEST_MM_NS} 

  cd ${COMMON_MANIFESTS_DIR}
  export MODEL_NAME=isvc-pvc-storage-uri

  grpcurl \
    -plaintext \
    -proto ./proto/grpc_predict_v2.proto \
    -d "$(envsubst <grpc-input-sklean.json )" \
    localhost:8033 \
    inference.GRPCInferenceService.ModelInfer

  cd -
  ~~~

## Cleanup

Please refer to [this doc](../docs/modelmesh-cleanup.md)


## Tip

**Copy a sample model into PVC**

It requires Minio exist in the same namespace.

~~~
cat <<EOF|oc create -f -
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: model-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 30G
EOF

cat <<EOF|oc create -f -
kind: Pod
apiVersion: v1
metadata:
  name: model-copy-pod
  labels:
    name: model-copy-pod
spec:
  containers:
  - name: target
    command:  
    - /bin/sh
    - -c
    - 'trap : TERM INT; sleep 1d'
    image: docker.io/openshift/origin-cli
    volumeMounts:
      - name: model-pvc
        mountPath: "data"
  restartPolicy: "Never"
  volumes:
    - name: model-pvc
      persistentVolumeClaim:
        claimName: model-pvc
EOF
        
check_pod_ready name=model-copy-pod ${test_mm_ns}  

oc rsync ${COMMON_MANIFESTS_DIR}/sklearn  model-copy-pod:/data

oc delete pod model-copy-pod --force
~~~
