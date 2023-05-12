# Quick Start 

This documentation aims to assist you in utilizing OpenDataHub's ModelServing effectively. It focuses on explaining new features introduced in the OpenDataHub modelmesh or odh-model-controller and provides relevant examples to enhance comprehension.

Please note that while these documents have been verified for accuracy at the time of their creation, there is a possibility that manifests or scripts may become outdated and not function as intended over time.

Our objective is to provide comprehensive and professional guidance to ensure seamless utilization of OpenDataHub's ModelServing.

The folder structure for the Quickstart is as follows:
~~~
|-- basic
     |-- deploy.sh   # Script to deploy ODH Modelmesh and Quickstart objects
     |-- clean.sh    # Script to delete all Quickstart objects
     |-- README.md   # Documentation providing an explanation of the Quickstart
~~~

## Requirement
- OpenShift Cluster 4.11+
- Default StorageClass
- OpenShift CLI 4.11+
- At least 8 vCPU and 16 GB memory. For more details, please see [here](../docs/get-started-odh-modelserving.md).
- User have cluster-admin role.

## Quick Start List

- [Sample Model Deployment](./basic/README.md)
- [Autoscaler Feature](./hpa/README.md)
- [PVC Feature](./pvc/README.md) 
