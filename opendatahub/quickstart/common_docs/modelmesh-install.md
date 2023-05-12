# Install OpenDataHub ModelServing

## Get the latest release
~~~
git clone https://github.com/opendatahub-io/modelmesh-serving.git
cd modelmesh-serving
~~~

## Run install script
~~~
source ../env.sh
cd opendatahub/quickstart/basic

./deploy.sh
~~~

This will install OpenDataHub ModelServing Controller in the `opendatahub` namespace and NFS Provisioner in the `nfs-provisioner` namespace. The test components such as Minio and PVC will be created in the `modelmesh-serving` namespace. Eventually after running this script, you should see a `Successfully deployed ModelMesh Serving/ODH Model Controller/NFS Provisioner/Sample Model!` message.

**Note**: These NFS Provisioner and MinIO deployments are intended for development/experimentation and not for production. Moreover, `deploy.sh` install modelserving without OpenDataHub operator. For the production, I strongly recommend that you deploy ModelServing with OpenDataHub operator. Please refer to [this site](http://opendatahub.io/docs/getting-started/quick-installation.html)

## Verify installation
~~~
$ oc get pod -n opendatahub
NAME                                    READY   STATUS    RESTARTS   AGE
etcd-6c4699b675-nvl62                   1/1     Running   0          94s
modelmesh-controller-59b4546559-2tcgb   1/1     Running   0          94s
modelmesh-controller-59b4546559-m82px   1/1     Running   0          94s
modelmesh-controller-59b4546559-tzkjl   1/1     Running   0          94s
odh-model-controller-7c87fd685-2nhpk    1/1     Running   0          94s
odh-model-controller-7c87fd685-zkm25    1/1     Running   0          94s
odh-model-controller-7c87fd685-zxlss    1/1     Running   0          94s

$ oc get pod -n nfs-provisioner
NAME                              READY   STATUS    RESTARTS   AGE
nfs-provisioner-f7c7b56bc-c425b   1/1     Running   0          60s

$ oc get pod -n modelmesh-serving
NAME                                          READY   STATUS      RESTARTS   AGE
minio-5f6cf8dd56-5v96n                        1/1     Running     0          76s
modelmesh-serving-ovms-1.x-6d84c548bb-68xp5   5/5     Running     0          44s
modelmesh-serving-ovms-1.x-6d84c548bb-j6fdz   5/5     Running     0          44s
pvc-init-zrqqv                                0/1     Completed   0          76s
pvc-reader                                    1/1     Running     0          76s
~~~

Check available ServingRuntimes:
~~~
$ oc get servingruntimes -n modelmesh-serving
NAME       DISABLED   MODELTYPE     CONTAINERS   AGE
ovms-1.x              openvino_ir   ovms         78s
~~~

You can see openvino model server runtime here but you can easily create custom runtimes such as mlserver, triton and so on. For test purpose, you can create the runtimes with the following command:
~~~
kustomize build ${OPENDATAHUB_DIR}/scripts/manifests/runtimes | oc create -f -
~~~

Check other servingruntimes.
~~~
$ oc get servingruntimes -n modelmesh-serving
NAME             DISABLED   MODELTYPE     CONTAINERS   AGE
mlserver-0.x                sklearn       mlserver     6s
ovms-1.x                    openvino_ir   ovms         17m
torchserve-0.x              pytorch-mar   torchserve   6s
triton-2.x                  keras         triton       6s
~~~

The current mappings of ServingRuntime and Frameworks is as follows:

| ServingRuntime | Supported Frameworks                |
| -------------- | ----------------------------------- |
| mlserver-0.x   | sklearn, xgboost, lightgbm          |
| ovms-1.x       | openvino_ir, onnx                   |
| torchserve-0.x | pytorch-mar                         |
| triton-2.x     | tensorflow, pytorch, onnx, tensorrt |
