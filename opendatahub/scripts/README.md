# Opendatahub Scripts

This folder consists of two main parts: scripts and manifests.
manifests are the part that deploys the components required for fvt (functional validation test) of the modelmesh deployed through opendatahub manifests, and the template folder exists so that these manifests can be recreated at any time. And finally, there are manifests that are copied from upstream to create ServingRuntime for FVT.

## Manifests

- fvt
  - deploy components for fvt tests.
- fvt_templates
  - fvt templates manifest to make fvt folder based on the latest upstream version.
- runtimes
  - deploy ServingRuntimes
- subs_odh_operator.yaml
  - deploy the latest opendatahub operator.
- modelmesh-serving-sa-rolebinding.yaml
  - create a rolebinding to give token creation permission to `modelmesh-serving-sa`
  - This will be created by odh-model-operator when you create a namespace through odh console.

## Scripts

The scripts in this folder help you run fvt tests or compare odh manifests. However, it is not recommended to use these scripts directly without familiarizing yourself with them. [This doc has make examples](../docs/makefile-cheatsheet.md) of using these scripts in a makefile here.

- [env.sh](./env.sh)

  - This script includes sharable environmental variables such as `SCRIPT_DIR`

- [utils.sh](./utils.sh)

  - This script has common util functions that can be used by any script.

- [deploy_nfs_provisioner.sh](./deploy_nfs_provisioner.sh)

  - This script installs NFS provisioner to enable PVC testing on OpenShift dedicated.

- [download_images_on_nodes.sh](./download_images_on_nodes.sh)

  - This script uses a daemonset to ensure that the required images are downloaded to all nodes before the FVT starts. This prevents the FVT test from failing due to the long time it takes to get the images.

- [deploy_fvt.sh](./deploy_fvt.sh)

  - This script contains deploy_nfs_provisioner.sh and download_images_on_nodes.sh and is the main file that is called to prepare the FVT test.

- [install_odh.sh](./install_odh.sh)

  - This script installs modelmesh components with odh-manifests. By default, it uses kfctl cli because it does not need opendatahub operator. However, with `OP_KFDEF` environmental variable, you can deploy modelmesh with opendatahub operator.

- [repeat_fvt.sh](./repeat_fvt.sh)
  - Sometimes an fvt test fails for no reason, and to restart it, you have to recreate the test cluster, which can take over an hour. Therefore, retrying a few fvt tests in a test cluster once created is a good way to save time. This script allows you to retry a total of 5 times.
- [cleanup.sh](./cleanup.sh)
  - If you are running an fvt test with your cluster, you will want to cleanly delete the objects created by the test and run a fresh test. This script will help you delete the objects related to the fvt test from your cluster.
- [gen_odh_model_manifests.sh](./gen_odh_model_manifests.sh)
  - This script creates new odh-manifests based on the manifests in the main branch of odh-model-controller and compares them to see if they are the same or different from the existing ones. If they are different, you need to update the manifests in the opendatahub/odh-manifest/model-mesh folder using the diff command. After updating, you need to validate the new manifests with fvt test.
- [gen_odh_modelmesh_manifests.sh](./gen_odh_modelmesh_manifests.sh)
  - This script creates new odh-manifests based on the manifests in the main branch of modelmesh-serving and compares them to see if they are the same or different from the existing ones. If they are different, you need to update the manifests in the opendatahub/odh-manifest/model-mesh folder using the diff command. After updating, you need to validate the new manifests with fvt test.
