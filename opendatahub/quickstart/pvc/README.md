# Quick Start - Sample Model Deployment by using a Persistent Volume Claim

Welcome to the quick start for deploying the OpenDataHub ModelServing component along with NFS Provisioner, Minio, and a sample Persistent Volume Claim (PVC). Additionally, this quick start deploys a sample model with an inference service so that you can test OpenDataHub ModelServing.

The `deploy.sh` script deploys a sample model and includes an inference service.

There are two inference service manifest YAML files that this quick start uses to specify a model path: `storageUri` or `storagePath`

- **storagePath**

```
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
```

- **storageUri**

```
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
```

## Prerequisites

- Verify that you meet the requirements for running the quick starts listed in [Overview of the OpenDataHub's ModelServing Quick Starts](../README.md).
- Install OpenDataHub ModelServing as described in [Installing OpenDataHub ModelServing](../common_docs/modelmesh-install.md).
- Verify that Minio exists in the same namespace as the OpenDataHub ModelServing instance.

## Deploy a Sample Model from PVC

1. Deploy the sample model:

```
./deploy.sh
```

The `deploy.sh` script creates the following configmap in the `opendatahub` namespace. The configmap enables the ModelMesh `allowAnyPVC` parameter that allows a runtime pod to attach to any available PVC.:

```
apiVersion: v1
kind: ConfigMap
metadata:
  name: model-serving-config
data:
  config.yaml: |
    allowAnyPVC: true
```

2. [Check the model deployment status](../basic/README.md#check-model-deployment-status).

## Perform an inference request

After the model has deployed, you can perform inference requests. OpenDataHub ModelServing includes the `odh-model-controller` controller that is responsible for creating an OpenShift Route for the model and for authentication. These features are set with the `enable-route` and `enable-auth` ServingRuntime annotations. By default, both features are disabled (the annotations are set to `false`), but for this quick start, `enable-route` is set to `true`.

The following `curl` examples demonstrate how to perform inference requests.

**Curl test without authentication enabled**

- _Model Name=isvc-pvc-storage-path_

  ```
  export MODEL_NAME=isvc-pvc-storage-path

  export HOST_URL=$(oc get route ${MODEL_NAME} -ojsonpath='{.spec.host}' -n ${TEST_MM_NS})
  export HOST_PATH=$(oc get route ${MODEL_NAME}  -ojsonpath='{.spec.path}' -n ${TEST_MM_NS})

  curl   --silent --location --fail --show-error --insecure https://${HOST_URL}${HOST_PATH}/infer -d  @${COMMON_MANIFESTS_DIR}/input-sklean.json
  ```

- _Model Name=isvc-pvc-storage-uri_

  ```
  export MODEL_NAME=isvc-pvc-storage-uri

  export HOST_URL=$(oc get route ${MODEL_NAME} -ojsonpath='{.spec.host}' -n ${TEST_MM_NS})
  export HOST_PATH=$(oc get route ${MODEL_NAME}  -ojsonpath='{.spec.path}' -n ${TEST_MM_NS})

  curl   --silent --location --fail --show-error --insecure https://${HOST_URL}${HOST_PATH}/infer -d  @${COMMON_MANIFESTS_DIR}/input-sklean.json
  ```

**gRPC Curl test without authentication enabled**

- _Model Name=isvc-pvc-storage-path_

  ```
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
  ```

- _Model Name=isvc-pvc-storage-uri_

  ```
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
  ```

## Cleanup

Follow the steps in [Cleaning up an OpenDataHub ModelServing installation](../common_docs/modelmesh-cleanup.md).

## Tip

**Copy a sample model into PVC**

```
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
```
