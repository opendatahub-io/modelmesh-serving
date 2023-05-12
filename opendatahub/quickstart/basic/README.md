# Quick Start Guide - Sample Model Deployment

This Quick Start Guide provides instructions for deploying the OpenDataHub Modelserving component along with NFS Provisioner, Minio, and a sample PVC. Additionally, it automatically deploys a sample model and allows you to test OpenDataHub Modelserving using its inference service.

## Prerequisites

You can check prerequisites from [this doc](../README.md)

## Install OpenDataHub ModelServing

Please refer to [this doc](../docs/modelmesh-install.md)

## Deploy a Sample Model

The `deploy.sh` also deployed a sample model so you don't need to create additional inference service. However, to help you understand, here's a brief description of the inference service manifests yaml.

These are the yaml files that quick start used. There are 2 ways to specify a model path: `storageUri`, `storeagePath`

- **storeagePath**
~~~
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: example-onnx-mnist
  annotations:
    serving.kserve.io/deploymentMode: ModelMesh
spec:
  predictor:
    model:
      modelFormat:
        name: onnx
      runtime: ovms-1.x
      storage:
        key: localMinIO
        path: onnx/mnist.onnx
~~~

- **storeageUri**
~~~
apiVersion: serving.kserve.io/v1beta1
kind: InferenceService
metadata:
  name: example-onnx-mnist
  annotations:
    serving.kserve.io/deploymentMode: ModelMesh
spec:
  predictor:
    model:
      modelFormat:
        name: onnx
      runtime: ovms-1.x
      storageUri: s3://modelmesh-example-models/onnx/mnist.onnx
~~~

### How to check model deployment status
You can check if your model is ready by checking the inference service, where you can get the `gRPC` URL to access your model.
~~~
$ oc get isvc -n modelmesh-serving
NAME                 URL                                               READY   PREV   LATEST   PREVROLLEDOUTREVISION   LATESTREADYREVISION   AGE
example-onnx-mnist   grpc://modelmesh-serving.modelmesh-serving:8033   True                                                                  4m
~~~

For the `HTTP` URL, you can check routes.
~~~
$ oc get routes
NAME                 HOST/PORT                                                                       PATH                            SERVICES            PORT   TERMINATION     WILDCARD
example-onnx-mnist   example-onnx-mnist-modelmesh-serving.apps.jlee-test.l9ew.p1.openshiftapps.com   /v2/models/example-onnx-mnist   modelmesh-serving   8008   edge/Redirect   None
~~~
## Perform an inference request

Now that a model is loaded and available, you can then perform inference. OpenDataHub ModelServing has another controller `odh-model-controller` that is responsible for creating OpenShift Route for the model. You can manage the feature with the annotation `enable-route: "true"` in the ServingRuntime. Plus, the controller also manages authentication with the annotation  `enable-auth: "true"` in the ServingRuntime. (By default, both features are disabled but for this quick start, `enable-route` was set to `true`)

**Curl Test with no authentication enabled**
~~~
export HOST_URL=$(oc get route example-onnx-mnist -ojsonpath='{.spec.host}' -n ${TEST_MM_NS})
export HOST_PATH=$(oc get route example-onnx-mnist  -ojsonpath='{.spec.path}' -n ${TEST_MM_NS})

curl   --silent --location --fail --show-error --insecure https://${HOST_URL}${HOST_PATH}/infer -d  @${COMMON_MANIFESTS_DIR}/input-onnx.json

{"model_name":"example-onnx-mnist__isvc-b29c3d91f3","model_version":"1","outputs":[{"name":"Plus214_Output_0","datatype":"FP32","shape":[1,10],"data":[-8.233053,-7.7497034,-3.4236815,12.3630295,-12.079103,17.266596,-10.570976,0.7130762,3.321715,1.3621228]}]}
~~~

**Note**: If Authentication is enabled, the route port should be `8080`.
~~~
$ oc get route
NAME                 HOST/PORT                                                                       PATH                            SERVICES            PORT   TERMINATION     WILDCARD
example-onnx-mnist   example-onnx-mnist-modelmesh-serving.apps.jlee-test.l9ew.p1.openshiftapps.com   /v2/models/example-onnx-mnist   modelmesh-serving   8008   edge/Redirect   None
~~~

**gRPC Curl Test using port-forward**
~~~
oc port-forward --address 0.0.0.0 service/modelmesh-serving 8033 -n ${TEST_MM_NS} 

cd ${COMMON_MANIFESTS_DIR}

grpcurl \
  -plaintext \
  -proto ./proto/grpc_predict_v2.proto \
  -d "$(envsubst <grpc-input-onnx.json )" \
  localhost:8033 \
  inference.GRPCInferenceService.ModelInfer

cd -    
~~~

**Curl Test with authentication enabled**

Here we also show the case of enabling authentication for testing purposes. This can be done by simply setting the annotation 'enable-auth` in the servingrungime to true. When this feature is enabled, the token of the user who has access to this route should be sent along with it.

~~~
# Enable Auth for OVMS ServingRuntime
oc apply -f  ${COMMON_MANIFESTS_DIR}/sa_user.yaml -n ${TEST_MM_NS}
sed 's/    enable-auth: "false"/    enable-auth: "true"/g'  ${COMMON_MANIFESTS_DIR}/openvino-serving-runtime.yaml | oc apply -n ${TEST_MM_NS} -f -

export Token=$(oc create token user-one -n ${TEST_MM_NS})
export HOST_URL=$(oc get route example-onnx-mnist -ojsonpath='{.spec.host}' -n ${TEST_MM_NS})
export HOST_PATH=$(oc get route example-onnx-mnist  -ojsonpath='{.spec.path}' -n ${TEST_MM_NS})

curl  -H "Authorization: Bearer ${Token}" --silent --location --fail --show-error --insecure https://${HOST_URL}${HOST_PATH}/infer -d  @${COMMON_MANIFESTS_DIR}/input-onnx.json

{"model_name":"example-onnx-mnist__isvc-b29c3d91f3","model_version":"1","outputs":[{"name":"Plus214_Output_0","datatype":"FP32","shape":[1,10],"data":[-8.233053,-7.7497034,-3.4236815,12.3630295,-12.079103,17.266596,-10.570976,0.7130762,3.321715,1.3621228]}]}
~~~

**Note**: If Authentication is enabled, the route port should be `8443`.
~~~
$ oc get route
NAME                 HOST/PORT                                                                       PATH                            SERVICES            PORT   TERMINATION          WILDCARD
example-onnx-mnist   example-onnx-mnist-modelmesh-serving.apps.jlee-test.l9ew.p1.openshiftapps.com   /v2/models/example-onnx-mnist   modelmesh-serving   8443   reencrypt/Redirect   None
~~~

## Cleanup

Please refer to [this doc](../docs/modelmesh-cleanup.md)
