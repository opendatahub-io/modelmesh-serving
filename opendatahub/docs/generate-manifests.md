# How to use gen scripts

There are 3 gen scripts to support generating new manifests.

- [gen_odh_model_manifests.sh](../scripts/gen_odh_model_manifests.sh)
- [gen_odh_modelmesh_manifests.sh](../scripts/gen_odh_modelmesh_manifests.sh)
- [gen_copy_new_manifests.sh](../scripts/gen_copy_new_manifests.h)

To simplify, here's how the script works.
First, the above scripts generates new manifests and compares it with existing manifest without touching the existing manifests. If there are any differences, [gen_copy_new_manifests.sh](../scripts/gen_copy_new_manifests.h) copies the new manifests under the odh-manifests folder,then runs the fvt test, and if there are any problems, you have to manually modify the new manifests to make them work. If you modify the new manifests, you must also update odh-manifests/model-mesh_template or model-mesh_template_stable.

## Common

The temporary folder name is stored in this file (opendatahub/scripts/.temp_new_modelmesh_manifests). If this file exist, the folder name will be reused or a new file will be recreated. `gen_odh_model_manifests.sh` and `gen_odh_modelmesh_manifests.sh` have an option(-n, --create-new-dir) to delete the file to recreate.

```
cat opendatahub/scripts/.temp_new_modelmesh_manifests
modelmesh-20230608061686254480
```

## [gen_odh_model_manifests.sh](../scripts/gen_odh_model_manifests.sh)

This script clones a specific branch of the odh-model-controller repository and copies the manifests file from the config folder to the bottom of the /tmp/modelmesh-XXXX folder. Then use `opendatahub/scripts/gen_manifests/odh_model_manifests.sh` or `odh_model_manifests_stable.sh` to customize the copied manifests to run for opendatahub.

**Script Usage**

```
$ opendatahub/scripts/gen_odh_model_manifests.sh --help
usage: opendatahub/scripts/gen_odh_model_manifests.sh [flags]

Flags:
  -p, --stable-manifests       (optional) Use stable manifests. By default, it will use the latest manifests (default false).
  -b, --clone-branch           (optional) Use other branch to clone. By default, it will use the main branch (default main).
  -n, --create-new-dir         (optional) Use a new directory. By default, it uses the existing directory if it exists (default false).

Generate odh-manifest for odh-modelmesh-controller
```

**Use Cases - main branch**

Create a new temp folder name and generate a new odh-model-controller with main branch. Customize the manifests with `opendatahub/odh-manifests/model-mesh_template`

```
opendatahub/scripts/gen_odh_model_manifests.sh -n
```

**Use Cases - stable branch**

Create a new temp folder name and generate a new odh-model-controller with custom branch. Customize the manifests with `opendatahub/odh-manifests/model-mesh_template_stable`

```
opendatahub/scripts/gen_odh_model_manifests.sh -p -b release-v0.11.0-alpha -n
```

**Use Cases - custom branch**

Create a new temp folder name and generate a new odh-model-controller with custom branch. Customize the manifests with `opendatahub/odh-manifests/model-mesh_template`

```
opendatahub/scripts/gen_odh_model_manifests.sh -b release-v0.11.0-alpha -n
```

## [gen_odh_modelmesh_manifests.sh](../scripts/gen_odh_modelmesh_manifests.sh)

This script clones a specific branch of the odh-modelmesh-controller repository and copies the manifests file from the config folder to the bottom of the /tmp/modelmesh-XXXX folder. Then use `opendatahub/scripts/gen_manifests/odh_modelmesh_manifests.sh` or `odh_modelmesh_manifests_stable.sh` to customize the copied manifests to run inside opendatahub.

**Script Usage**

```
$ opendatahub/scripts/gen_odh_modelmesh_manifests.sh --help
usage: opendatahub/scripts/gen_odh_modelmesh_manifests.sh [flags]

Flags:
  -p, --stable-manifests         (optional) Use stable manifests. By default, it will use the latest manifests (default false).
  -b, --clone-branch             (optional) Use other branch to clone. By default, it will use the main branch (default main).
  -n, --create-new-dir           (optional) Use a new directory. By default, it uses the existing directory if it exists (default false).
  -c, --copy-current-config-dir  (optional) Use a current config directory to compare. By default, it uses the existing config directory instead of cloning git repository (default false).

Generate odh-manifest for odh-modelmesh-controller
```

**Use Cases - main branch**

Create a new temp folder name and generate a new odh-modelmesh-controller with main branch. Customize the manifests with `opendatahub/odh-manifests/model-mesh_template`

```
opendatahub/scripts/gen_odh_modelmesh_manifests.sh -n
```

**Use Cases - stable branch**

Create a new temp folder name and generate a new odh-modelmesh-controller with custom branch. Customize the manifests with `opendatahub/odh-manifests/model-mesh_template_stable`

```
opendatahub/scripts/gen_odh_modelmesh_manifests.sh -p -b release-v0.11.0-alpha -n
```

**Use Cases - custom branch**

Create a new temp folder name and generate a new odh-modelmesh-controller with custom branch. Customize the manifests with `opendatahub/odh-manifests/model-mesh_template`

```
opendatahub/scripts/gen_odh_modelmesh_manifests.sh -b release-v0.11.0-alpha -n
```

## [gen_copy_new_manifests.sh](../scripts/gen_copy_new_manifests.h)

This script does the following:

- Move `opendatahub/odh-manifests/model-mesh` to `opendatahub/odh-manifests/model-mesh-ori`
- Copy `/tmp/modelmesh-XXXX` to `opendatahub/odh-manifests/model-mesh` or `opendatahub/odh-manifests/model-mesh_stable`

**Script Usage**

```
$ opendatahub/scripts/gen_copy_new_manifests.sh --help
usage: opendatahub/scripts/gen_copy_new_manifests.sh [flags]

Flags:
  -p, --stable-manifests         (optional) Use stable manifests. By default, it will use the latest manifests (default false).

Copy the generated new odh-manifest to opendatahub/odh-manifests/model-mesh,model-mesh_stable
```

**Use Cases - main branch**

Move `opendatahub/odh-manifests/model-mesh` to `opendatahub/odh-manifests/model-mesh_ori` and move `/tmp/modelmesh-XXX` to `opendatahub/odh-manifests/model-mesh`.

```
opendatahub/scripts/gen_copy_new_manifests.sh
```

**Use Cases - stable branch**

Move `opendatahub/odh-manifests/model-mesh_stable` to `opendatahub/odh-manifests/model-mesh_stable_ori` and move `/tmp/modelmesh-XXX` to `opendatahub/odh-manifests/model-mesh_stable`.

```
opendatahub/scripts/gen_copy_new_manifests.sh -p
```
