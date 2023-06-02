# Quick Start - Sample Model Deployment

Welcome to the quick start for deploying a sample model and testing OpenDataHub ModelServing by using its provided inference service.

## Description of the inference service manifest YAML files

There are two inference service manifest YAML files that this quick start uses to specify a model path: `storageUri` or `storagePath`

- **storagePath**
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

- **storageUri**
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

## Prerequisites

- Verify that you meet the requirements for running the quick starts listed in [Overview of the OpenDataHub's ModelServing Quick Starts](../README.md).
- Install OpenDataHub ModelServing as described in [Installing OpenDataHub ModelServing](../common_docs/modelmesh-install.md).

## Deploy a Sample Model

Deploy the sample model:
~~~
./opendatahub/quickstart/basic/deploy.sh
~~~

## Check the model deployment status

1. Check whether your model is ready by getting the OpenDataHub ModelServing's inference service:
~~~
$ oc get isvc -n modelmesh-serving
~~~
You should see a result similar to the following:
~~~
NAME                 URL                                               READY   PREV   LATEST   PREVROLLEDOUTREVISION   LATESTREADYREVISION   AGE
example-onnx-mnist   grpc://modelmesh-serving.modelmesh-serving:8033   True                                                                  4m
~~~
Note that this result includes the `gRPC` URL that you can use to access the model.

2. To obtain the `HTTP` URL for the model, use the command to get routes:
~~~
$ oc get routes
~~~
You should see a result similar to the following:
~~~
NAME                 HOST/PORT                                                                       PATH                            SERVICES            PORT   TERMINATION     WILDCARD
example-onnx-mnist   example-onnx-mnist-modelmesh-serving.apps.jlee-test.l9ew.p1.openshiftapps.com   /v2/models/example-onnx-mnist   modelmesh-serving   8008   edge/Redirect   None
~~~

## Perform inference requests

After the model has deployed, you can perform inference requests. OpenDataHub ModelServing includes the `odh-model-controller` controller that is responsible for creating an OpenShift Route for the model and for authentication. These features are set with the `enable-route` and `enable-auth` ServingRuntime annotations. By default, both features are disabled (the annotations are set to `false`), but for this quick start, `enable-route` is set to `true`.

The following `curl` examples demonstrate how to perform inference requests.

**Curl test without authentication enabled**
~~~
export HOST_URL=$(oc get route example-onnx-mnist -ojsonpath='{.spec.host}' -n modelmesh-serving)

export HOST_PATH=$(oc get route example-onnx-mnist -ojsonpath='{.spec.path}' -n modelmesh-serving)

##If you give commands echo $HOST_URL and echo $HOST_PATH you should get a similar output to the following:
echo $HOST_URL
example-onnx-mnist-modelmesh-serving.apps.user.dev.datahub.redhat.com
echo $HOST_PATH
/v2/models/example-onnx-mnist


cd opendatahub/quickstart/common_manifests/
curl -k --insecure https://${HOST_URL}${HOST_PATH}/infer -d  @input-onnx.json

{"model_name":"example-onnx-mnist__isvc-b29c3d91f3","model_version":"1","outputs":[{"name":"Plus214_Output_0","datatype":"FP32","shape":[1,10],"data":[-8.233053,-7.7497034,-3.4236815,12.3630295,-12.079103,17.266596,-10.570976,0.7130762,3.321715,1.3621228]}]}
~~~

**Note**: If authentication is enabled, the route port should be `8080`.

~~~
$ oc get route
~~~
You should see a result similar to the following:
~~~
NAME                 HOST/PORT                                                                       PATH                            SERVICES            PORT   TERMINATION     WILDCARD
example-onnx-mnist   example-onnx-mnist-modelmesh-serving.apps.jlee-test.l9ew.p1.openshiftapps.com   /v2/models/example-onnx-mnist   modelmesh-serving   8008   edge/Redirect   None
~~~

**gRPC Curl test by using port-forward**

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

**Curl test with authentication enabled**

You can enable authentication for testing purposes by setting the `enable-auth` annotation in the ServingRuntime to `true`. When you enable authentication, you should also send the token of the user with access to the route.
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

**Note**: If authentication is enabled, the route port should be `8443`.
~~~
$ oc get route
~~~
You should see a result similar to the following:
~~~
NAME                 HOST/PORT                                                                       PATH                            SERVICES            PORT   TERMINATION          WILDCARD
example-onnx-mnist   example-onnx-mnist-modelmesh-serving.apps.jlee-test.l9ew.p1.openshiftapps.com   /v2/models/example-onnx-mnist   modelmesh-serving   8443   reencrypt/Redirect   None
~~~

## Cleanup

Follow the steps in [Cleaning up an OpenDataHub ModelServing installation](../common_docs/modelmesh-cleanup.md).