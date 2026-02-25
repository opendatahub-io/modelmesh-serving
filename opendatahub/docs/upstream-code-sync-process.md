# Synchronization with upstream repositories

This document outlines the process to synchronize ODH fork with upstream repositories.

A ModelMesh synchronization involves four repositories: _modelmesh_ , _modelmesh-runtime-adapter_, _rest-proxy_ and _modelmesh-serving_.

ModelMesh depends on some KServe resources. You may want to synchronize [KServe fork](https://github.com/opendatahub-io/kserve) first and, secondly, ModelMesh.

## Code synchronization

The steps for doing code synchronization are the same for all repositories. You can use the following script on an empty folder as a helper (it assumes you have your own forks using same names as in ODH):

```sh
export GH_USER_NAME=$USER       # Replace with your GitHub handle
export SYNC_HOME=$(mktemp -d)   # Either keep as is, or set to an empty directory of your liking
export REPOS_TO_SYNC=(modelmesh modelmesh-runtime-adapter rest-proxy modelmesh-serving)
export RELEASE_BRANCH_NAME=release-0.11
export SYNC_BRANCH_NAME=${RELEASE_BRANCH_NAME}_$(date '+%Y%m%d')_sync

cd $SYNC_HOME

for TARGET_REPO_NAME in ${REPOS_TO_SYNC[@]}
do
  git clone git@github.com:${GH_USER_NAME}/${TARGET_REPO_NAME}.git
  pushd ${TARGET_REPO_NAME}/

  git remote add odh git@github.com:opendatahub-io/${TARGET_REPO_NAME}.git
  git remote add kserve https://github.com/kserve/${TARGET_REPO_NAME}

  git fetch odh
  git fetch kserve

  git fetch odh ${RELEASE_BRANCH_NAME}
  git fetch kserve ${RELEASE_BRANCH_NAME}

  # Sync release branch
  git branch ${SYNC_BRANCH_NAME} odh/${RELEASE_BRANCH_NAME}
  git checkout ${SYNC_BRANCH_NAME}
  git merge kserve/${RELEASE_BRANCH_NAME}

  popd
done

echo ""
echo "Sync directory: $SYNC_HOME"

for TARGET_REPO_NAME in ${REPOS_TO_SYNC[@]}
do
  is_clean=$(cd $TARGET_REPO_NAME; git status --porcelain)
  if [ -z "$is_clean" ]; then
    echo "$TARGET_REPO_NAME: Clean"
  else
    echo "$TARGET_REPO_NAME: Conflict"
  fi
done
```

When the script finishes, you will see a sumary about merge status. You will need to manually fix any conflicts and finish the merge commiting the changes `git commit -s -m "Sync upstream ${RELEASE_BRANCH_NAME}"`

Once all repositories are synced, you can push changes to your own fork and create PRs for all repositories.

## Update odh-manifests within modelmesh-serving

> [!NOTE]
> This subsection is no longer relevant, because `odh-manifests` repository has been deprecated and no longer maintained.
> Please, skip this whole section.

ModelMesh serving maintains a copy of Kustomize manifests modified to work with v3-syntax (which is what ODH-Operator v1 supports). The v3 manifests need to be updated.

The following is a helper script. This script is NOT automatic, because there are some tasks that are manual, as mentioned in comments.

```bash
# Update params.env to set new image tag(ex, v0.11.0-alpha)
cd $SYNC_HOME/modelmesh-serving/opendatahub/odh-manifests
vi model-mesh_templates/base/params.env

# Generate new manfiests
cd $SYNC_HOME/modelmesh-serving/
opendatahub/scripts/gen_odh_modelmesh_manifests.sh -n -c
opendatahub/scripts/gen_odh_model_manifests.sh
opendatahub/scripts/gen_copy_new_manifests.sh

# MANUAL TASK: Update model-mesh/model-mesh_templates to fix FVT test.

### FVT Test(with the new odh manifests)
TAG=fast CONTROLLERNAMESPACE=opendatahub NAMESPACE=modelmesh-serving FORCE=true make deploy-mm-for-odh
TAG=fast CONTROLLERNAMESPACE=opendatahub NAMESPACE=modelmesh-serving FORCE=true make deploy-fvt-for-odh
TAG=fast CONTROLLERNAMESPACE=opendatahub NAMESPACE=modelmesh-serving NAMESPACESCOPEMODE=true make repeat-fvt

### Cleanup (optional)
CONTROLLERNAMESPACE=opendatahub NAMESPACE=modelmesh-serving  C_MM_CTRL_KFCTL=true C_MM_TEST=true make cleanup-for-odh

### Once FVT pass, do the following
rm -rf opendatahub/odh-manifests/model-mesh_ori
git add opendatahub/odh-manifests/model-mesh_templates
git add opendatahub/odh-manifests/model-mesh

git commit -s -m "Update ODH-MANIFEST(fast)"
git push

# MANUAL TASK: Send a PR to opendatahub. Wait/Fix until openshift-ci pass all tests and merge your PR.
```

## Update AutoMerger mapping for the release branch

You only need to do this if you created a new release branch and it is ready to be promoted into RHODS.

Modelmesh enabled the auto merger. If the new release branch is ready for RHODS promotion, you should update [source_mapping.yaml file](https://github.com/red-hat-data-services/rhods-devops-infra/blob/main/src/config/source_map.yaml) to pont to the branch.

Example:

```yaml
- name: rest-proxy
  automerge: "yes"
  src:
    url: https://github.com/opendatahub-io/rest-proxy.git
    branch: release-v0.10.0 # <----- HERE
  dest:
    url: https://github.com/red-hat-data-services/rest-proxy.git
    branch: main
```

NOTE: There is one entry for each repository. You should update all entries (the example is showing only the entry for `rest-proxy`).
