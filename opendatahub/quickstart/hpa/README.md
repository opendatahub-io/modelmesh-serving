# Quick Start Guide - HPA Feature

The feature we'll be discussing in this article is the Horizontal Pod Autoscaler, or HPA. By default, HPA-specific features are managed through annotations in ServingRuntime, which is different from kserve/kserve being managed through annotations or predictor specs in inference service. This is because by design, multiple models in a modelmesh share a single ServingRuntime. [HPA](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/) is a default object provided by kubernetes, and ModelMesh relies on this HPA object to autoscale the ServingRuntime Pods.

<p align="center">
  <img src="./HPA_in_Modelmesh.png" alt="HPA in ModelMesh"/>
</p>

## Prerequisites

You can check prerequisites from [this doc](../README.md)

## Install OpenDataHub ModelServing

Please refer to [this doc](../docs/modelmesh-install.md)

## Deploy a Sample Model from PVC

The `deploy.sh` also deployed a sample model so you don't need to create additional inference service. 

### How to check model deployment status
Please refer to [this doc](../basic/README.md#how-to-check-model-deployment-status)

## Perform an inference request

**Curl Test wit no authentication enabled**
~~~
export HOST_URL=$(oc get route example-onnx-mnist -ojsonpath='{.spec.host}' -n ${TEST_MM_NS})
export HOST_PATH=$(oc get route example-onnx-mnist  -ojsonpath='{.spec.path}' -n ${TEST_MM_NS})

curl   --silent --location --fail --show-error --insecure https://${HOST_URL}${HOST_PATH}/infer -d  @${COMMON_MANIFESTS_DIR}/input-onnx.json
~~~

**gRPC Curl Test wit no authentication enabled**

~~~
kubectl port-forward --address 0.0.0.0 service/modelmesh-serving 8033 -n ${TEST_MM_NS} 

cd ${COMMON_MANIFESTS_DIR}

grpcurl \
  -plaintext \
  -proto ./proto/grpc_predict_v2.proto \
  -d "$(envsubst <grpc-input-onnx.json )" \
  localhost:8033 \
  inference.GRPCInferenceService.ModelInfer

cd -  
~~~

## HPA Feature Test

Since the deploy.sh script has already enabled the HPA feature, you can see that hpa has been created by executing the command below.

~~~
oc get hpa
~~~

### Use Cases
Let's take a look at the HPA feature through the use case below.

**Enable Autoscaler**
~~~
oc annotate servingruntime ovms-1.x serving.kserve.io/autoscalerClass=hpa
~~~

**Disable Autoscaler**
~~~
oc annotate servingruntime ovms-1.x serving.kserve.io/autoscalerClass-
~~~

**Change Max pods**
~~~
oc annotate servingruntime ovms-1.x serving.kserve.io/max-scale=3
~~~

**Change Min pods**
~~~
oc annotate servingruntime ovms-1.x serving.kserve.io/min-scale=2
~~~

**Change targetUtilizationPercentage**
~~~
 oc annotate servingruntime ovms-1.x  serving.kserve.io/targetUtilizationPercentage=50
~~~

**Change metrics type**
~~~
oc annotate servingruntime ovms-1.x serving.kserve.io/metrics=memory
~~~

## Cleanup

Please refer to [this doc](../docs/modelmesh-cleanup.md)
