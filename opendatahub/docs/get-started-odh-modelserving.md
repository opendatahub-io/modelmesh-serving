# Getting Started

## Prerequisites

- **OpenShift cluster** - A OpenShift cluster is required. You will need `cluster-admin` or `dedicated-admin` authority in order to complete all of the prescribed steps.

- **OpenShift cli** - The installation will occur via the terminal using [oc](https://docs.openshift.com/container-platform/4.11/cli_reference/openshift_cli/getting-started-cli.html#cli-installing-cli_cli-developer-commands).

- **Model storage** - The model files have to be stored in a compatible form of remote storage or on a Kubernetes Persistent Volume. 

We provide an deploy script to quickly run OpenDataHub ModelMesh Serving with a provisioned etcd server. This may be useful for experimentation or development but should not be used in production.

## Namespace Scope

ModelMesh Serving can be used in either cluster scope or namespace scope mode but OpenDataHub ModelServing only support namespace scope mode.

- **Namespace scope mode** - All of its components must exist within a single namespace and only one instance of ModelMesh Serving can be installed per namespace. Multiple ModelMesh Serving instances can be installed in separate namespaces within the cluster.


## Deployed Components

|            | Type             | Pod                        | Count   | Default CPU request/limit per-pod | Default mem request/limit per-pod          |
| ---------- | ---------------- | -------------------------- | ------- | --------------------------------- | ------------------------------------------ |
| 1          | Controller       | Modelmesh Controller pod  | 3       | 50m / 1                           | 96Mi / 2Gi                               |
| 2          | Object Storage   | MinIO pod (optional)       | 1       | 0m / 0m                       | 0Mi / 0Mi                              |
| 3          | Metastore        | ETCD pod                   | 1       | 200m / 300m                       | 100Mi / 200Mi                              |
| 4          | Built-in Runtime | The OVMS Runtime Pods      | 0 \(\*) | 500m / 5     | 1Gi / 1Gi |
| 5          | ODH Model Controller   | ODH Model Controller pod        | 3       | 10m / 500m                       | 64Mi / 2Gi                              |
| **totals** |                  |                            | 3       | 880m / 9.4                        | 1.58Gi / 13.2Gi                             |
