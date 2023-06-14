# Cleaning up an OpenDataHub ModelServing installation

Run one of the following commands to cleanup up the Quick Start files:

- If you want to try another quick start, run this command to delete the `modelmesh` and modelmesh test namespaces (`minio` and `pvc`):

```
./cleanup.sh
```

- If you are done with all of the quickstarts, run this command to deletes the `modelmesh` and modelmesh test namespaces (`minio` and `pvc`) and NFS provisioner:

```
C_FULL=true ./cleanup.sh
```
