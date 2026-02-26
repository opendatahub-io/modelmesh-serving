# Copyright 2021 IBM Corporation
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# collect args from `make run` so that they don't run twice
ifeq (run,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  ifneq ("$(wildcard /.dockerenv)","")
    $(error Inside docker container, run 'make $(RUN_ARGS)')
  endif
endif

# Container Engine to be used for building images
ENGINE ?= "docker"

# Image URL to use all building/pushing image targets
IMG ?= kserve/modelmesh-controller:latest

# Namespace to deploy model-serve into
NAMESPACE ?= "model-serving"

CONTROLLER_GEN_VERSION ?= "v0.17.0"

# Kubernetes version needs to be 1.23 or newer for autoscaling/v2 (HPA)
# https://github.com/kubernetes-sigs/controller-runtime/tree/main/tools/setup-envtest
# install with `go install sigs.k8s.io/controller-runtime/tools/setup-envtest@latest`
# find available versions by running `setup-envtest list`
KUBERNETES_VERSION ?= 1.28

CRD_OPTIONS ?= "crd:maxDescLen=0"

# Model Mesh gRPC API Proto Generation
PROTO_FILES = $(shell find proto/ -iname "*.proto")
GENERATED_GO_FILES = $(shell find generated/ -iname "*.pb.go")

# Get the currently used golang install path (in GOPATH/bin, unless GOBIN is set)
ifeq (,$(shell go env GOBIN))
GOBIN=$(shell go env GOPATH)/bin
else
GOBIN=$(shell go env GOBIN)
endif

.PHONY: all
## Alias for `manager`
all: manager

.PHONY: test
## Run unit tests (Requires kubebuilder, etcd, kube-apiserver, envtest)
test:
	KUBEBUILDER_ASSETS="$$(setup-envtest use $(KUBERNETES_VERSION) -p path)" \
	KUBEBUILDER_CONTROLPLANE_STOP_TIMEOUT=120s \
	go test -coverprofile cover.out `go list ./... | grep -v fvt`

.PHONY: fvt
## Run FVT tests (Requires ModelMesh Serving deployment and GinkGo CLI)
fvt:
	ginkgo -v -procs=2 --fail-fast fvt/predictor fvt/scaleToZero fvt/storage fvt/hpa --timeout=50m

fvt-stable:
	ginkgo -v -procs=2 --fail-fast fvt/predictor fvt/scaleToZero fvt/storage fvt/hpa --timeout=50m

.PHONY: codegen-fvt
## Regenerate grpc code stubs for FVT
codegen-fvt:
	rm -rf fvt/generated
	protoc -I=fvt/proto --go_out=plugins=grpc:. --go_opt=module=github.com/kserve/modelmesh-serving $(shell find fvt/proto -iname "*.proto")

.PHONY: fvt-with-deploy
## Alias for `oc-login, deploy-release-fvt, fvt`
fvt-with-deploy: oc-login deploy-release-fvt fvt

.PHONY: oc-login
## Login to OCP cluster
oc-login:
	oc login --token=${OCP_TOKEN} --server=https://${OCP_ADDRESS} --insecure-skip-tls-verify=true

.PHONY: manager
## Build `manager` binary
manager: generate fmt
	go build -o bin/manager main.go

.PHONY: start
## Run against a Kubernetes cluster
start: generate fmt manifests
	go run ./main.go

.PHONY: install
## Install CRDs into a Kubernetes cluster
install: manifests
	kustomize build config/crd | kubectl apply -f -

.PHONY: uninstall
## Uninstall CRDs from a Kubernetes cluster
uninstall: manifests
	kustomize build config/crd | kubectl delete -f -

.PHONY: deploy
## Deploy manifests to Kubernetes cluster
deploy: manifests
	cd config/manager && kustomize edit set image controller=${IMG}
	kustomize build config/default | kubectl apply -f -

.PHONY: deploy-release
## Deploy release (artifactory creds set via env var)
deploy-release:
	./scripts/install.sh --namespace ${NAMESPACE} --install-config-path config

.PHONY: deploy-release-dev
## Deploy release in dev mode (artifactory creds set via env var)
deploy-release-dev:
	./scripts/install.sh --namespace ${NAMESPACE} --install-config-path config --dev-mode-logging

.PHONY: deploy-release-fvt
## Deploy release in dev mode for FVT tests
deploy-release-fvt:
ifdef MODELMESH_SERVING_IMAGE
	$(eval extra_options += --modelmesh-serving-image ${MODELMESH_SERVING_IMAGE})
endif
ifdef NAMESPACE_SCOPE_MODE
	$(eval extra_options += --namespace-scope-mode)
endif
	./scripts/install.sh --namespace ${NAMESPACE} --install-config-path config --dev-mode-logging --fvt ${extra_options}

.PHONY: undeploy-release
## Undeploy the ModelMesh Serving installation
undeploy-release:
	./scripts/delete.sh --namespace ${NAMESPACE} --local-config-path config

.PHONY: manifests
## Generate manifests e.g. CRD, RBAC etc.
manifests: controller-gen
		# NOTE: We're currently copying the CRD manifests from KServe rather than using this target to regenerate those
		# that are common (all apart from predictors) because the formatting ends up different depending on the version
		# of controller-gen and yq used. The KServe make manifests also includes a bunch of yaml post-processing which
		# would need to be replicated here.
		# HACK: ignore errors from generating the TrainedModel CRD from KServe, which is removed below
	$(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=controller-role crd paths="github.com/kserve/kserve/pkg/apis/serving/v1alpha1" output:crd:dir=config/crd/bases
	$(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=controller-role crd paths="github.com/kserve/kserve/pkg/apis/serving/v1beta1" output:crd:dir=config/crd/bases
	$(CONTROLLER_GEN) $(CRD_OPTIONS) rbac:roleName=controller-role crd paths="./..." output:crd:dir=config/crd/bases
	rm -f ./config/crd/bases/serving.kserve.io_trainedmodels.yaml
	pre-commit run --all-files prettier > /dev/null || true

.PHONY: fmt
## Auto-format source code and report code-style violations (lint)
fmt:
	./scripts/fmt.sh || (echo "Linter failed: $$?"; git status; exit 1)

.PHONY: generate
## Generate code
generate: controller-gen
	$(CONTROLLER_GEN) object:headerFile="scripts/controller-gen-header.go.tmpl" paths="./..."
	pre-commit run --all-files prettier > /dev/null || true

.PHONY: build
## Build runtime container image
build: build.develop
	./scripts/build_docker.sh --target runtime --engine $(ENGINE)

.PHONY: build.develop
## Build developer container image
build.develop:
	./scripts/build_devimage.sh $(ENGINE)

.PHONY: develop
## Run interactive shell inside developer container
develop: build.develop
	./scripts/develop.sh

.PHONY: run
## Run make target inside developer container (e.g. `make run fmt`)
run:
	./scripts/develop.sh make $(RUN_ARGS)

.PHONY: push
## Push the controller runtime image
push:
	docker push ${IMG}

# Build the docker image
.PHONY: docker-build
docker-build: build

# Push the docker image
.PHONY: docker-push
docker-push:
	podman push ${IMG}

.PHONY: controller-gen
## Find or download controller-gen
controller-gen:
ifeq (, $(shell which controller-gen))
	@{ \
	set -e ;\
	go install sigs.k8s.io/controller-tools/cmd/controller-gen@${CONTROLLER_GEN_VERSION} ;\
	}
CONTROLLER_GEN=$(GOBIN)/controller-gen
else
CONTROLLER_GEN=$(shell which controller-gen)
endif

.PHONY: codegen
## Generate gRPC code stubs (protoc)
codegen:
	protoc -I proto/ --go_out=plugins=grpc:generated/ $(PROTO_FILES)

.PHONY: check-doc-links
## Check markdown files for invalid links
check-doc-links:
	@python3 scripts/verify_doc_links.py && echo "$@: OK"

.DEFAULT_GOAL := help
.PHONY: help
## Print Makefile documentation
help:
	@perl -0 -nle 'printf("\033[36m  %-20s\033[0m %s\n", "$$2", "$$1") while m/^##\s*([^\r\n]+)\n^([\w.-]+):[^=]/gm' $(MAKEFILE_LIST) | sort

# Override targets if they are included in RUN_ARGs so it doesn't run them twice
$(eval $(RUN_ARGS):;@:)

before-pr: fmt test 
	./opendatahub/scripts/gen_odh_model_manifests.sh
	./opendatahub/scripts/gen_odh_modelmesh_manifests.sh

repeat-fvt:
	./opendatahub/scripts/repeat_fvt.sh ${NAMESPACE} ${CONTROLLERNAMESPACE} ${NAMESPACESCOPEMODE} ${STABLE_MANIFESTS}

# Openshift CI
## Upstream
## Pre-download required images.
download-images:
	oc project ${NAMESPACE} || oc new-project ${NAMESPACE} 
	./scripts/download-images-on-nodes.sh

# This must use modelmesh-serving namespace because fvt has hardcoded namspace. globals.go
# usage: NAMESPACE=modelmesh-serving make e2e-test
e2e-test: download-images deploy-release-fvt repeat-fvt

# usage: NAMESPACE=modelmesh-serving make e2e-delete
e2e-delete: delete
	oc delete ns ${NAMESPACE}

## ODH
## This deploy modelmesh using manifests in opendatahub/odh-manifests folder
deploy-fvt-for-odh:
ifdef CUSTOM_IMG
	$(eval extra_options += --image ${CUSTOM_IMG}) 
endif
ifdef FORCE
	$(eval extra_options += --force) 
endif
ifdef TAG
	$(eval extra_options += --tag ${TAG}) 
endif
ifdef CONTROLLERNAMESPACE
	$(eval extra_options += --ctrl-namespace ${CONTROLLERNAMESPACE}) 
endif
ifdef STABLE_MANIFESTS
	$(eval extra_options += --stable-manifests) 
endif
	./opendatahub/scripts/deploy_fvt.sh --namespace ${NAMESPACE} ${extra_options}

deploy-mm-for-odh:
ifdef CUSTOM_IMG
	$(eval deploy_mm_extra_options += --image ${CUSTOM_IMG}) 
endif
ifdef REPO_URI
	$(eval deploy_mm_extra_options += --repo-uri ${REPO_URI}) 
endif
ifdef TAG
	$(eval deploy_mm_extra_options += --tag ${TAG}) 
endif
ifdef MM_USER
	$(eval deploy_mm_extra_options += --user ${MM_USER}) 
endif
ifdef BRANCH
	$(eval deploy_mm_extra_options += --branch ${BRANCH}) 
endif
ifdef STABLE_MANIFESTS
	$(eval deploy_mm_extra_options += --stable-manifests) 
endif
ifdef OP_KFDEF
	$(eval deploy_mm_extra_options += --operator) 
endif
ifdef CONTROLLERNAMESPACE
	$(eval deploy_mm_extra_options += --ctrl-namespace ${CONTROLLERNAMESPACE}) 
endif
	./opendatahub/scripts/install_odh.sh ${deploy_mm_extra_options}

# usage: TAG=fast/stable make e2e-test-for-odh
e2e-test-for-odh: deploy-mm-for-odh deploy-fvt-for-odh repeat-fvt

cleanup-for-odh:
	./opendatahub/scripts/cleanup.sh

# Remove $(MAKECMDGOALS) if you don't intend =======
.PHONY: all generate manifests check-doc-links fmt fvt controller-gen oc-login deploy-release build.develop $(MAKECMDGOALS)
