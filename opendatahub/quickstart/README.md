# Overview of the OpenDataHub's ModelServing Quick Starts

The purpose of these quick starts is help you learn how to use OpenDataHub's ModelServing. They describe features in the OpenDataHub ModelMesh or odh-model-controller and provide relevant examples.

**Note:** These quick starts have been verified for accuracy at the time of their creation, but the manifests or scripts might become outdated and not function as originally intended.

## List of quick starts

- [Sample Model Deployment](./basic/README.md)
- [Sample Model Deployment and Autoscaler](./hpa/README.md)
- [Sample Model Deployment by using a Persistent Volume Claim](./pvc/README.md)

## Quick start files

Each quick start folder contains the following files:

```
|-- deploy.sh   # Script to deploy the OpenDataHub ModelMesh and all quick start objects
|-- clean.sh    # Script to delete all quick start objects
|-- README.md   # Documentation that describes how to run the quick start
```

## Requirements for running the quick starts

- OpenShift Cluster 4.11+
- Default StorageClass
- OpenShift CLI 4.11+
- At least 8 vCPU and 16 GB memory. For more details, see [Getting Started with ODH ModelMesh Serving](../docs/get-started-odh-modelserving.md).
- You must have `cluster-admin` access to the OpenShift cluster.
