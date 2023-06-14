# Getting Started with ODH ModelMesh Serving

The provided deploy script allows you to quickly run OpenDataHub ModelMesh Serving with a provisioned `etcd` server. This deploy script is intended for experimentation or development purposes only. It is not intended for production purposes.

## Prerequisites

- You have `cluster-admin` access to an OpenShift cluster.

- You have installed the **OpenShift CLI** as described in [Installing the OpenShift CLI by downloading the binary](https://docs.openshift.com/container-platform/4.11/cli_reference/openshift_cli/getting-started-cli.html#cli-installing-cli_cli-developer-commands).

- Your model files are stored in a compatible form of remote storage or on a Kubernetes persistent volume.

## Namespace Scope

While ModelMesh Serving is available in either cluster scope or namespace scope mode, OpenDataHub ModelServing only supports namespace scope mode.

With Namespace scope, you can configure more than one ModelMesh Serving instance on a cluster. However, you must configure each instance of ModelMesh Serving in a separate namespace and all of the ModelMesh Serving instance components must exist within that single namespace.

## Deployed Components

The following table describes the components deployed for each ModelMesh Serving instance.

| Component Type       | Pod Name                 | Number of Pods | Default CPU Request/Limit per Pod | Default Memory request/Limit per Pod |
| -------------------- | ------------------------ | -------------- | --------------------------------- | ------------------------------------ |
| Controller           | Modelmesh Controller pod | 3              | 50m / 1                           | 96Mi / 2Gi                           |
| Object Storage       | MinIO pod (optional)     | 1              | 0m / 0m                           | 0Mi / 0Mi                            |
| Metastore            | ETCD pod                 | 1              | 200m / 300m                       | 100Mi / 200Mi                        |
| Built-in Runtime     | The OVMS Runtime Pods    | 0 \(\*)        | 500m / 5                          | 1Gi / 1Gi                            |
| ODH Model Controller | ODH Model Controller pod | 3              | 10m / 500m                        | 64Mi / 2Gi                           |
| **Totals**           |                          | 3              | 880m / 9.4                        | 1.58Gi / 13.2Gi                      |
