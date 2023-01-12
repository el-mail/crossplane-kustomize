#!/usr/bin/env bash
set -e

# setting up colors
BLU='\033[0;34m'
YLW='\033[0;33m'
GRN='\033[0;32m'
RED='\033[0;31m'
NOC='\033[0m' # No Color
echo_info() {
    printf "\n${BLU}%s${NOC}" "$1"
}
echo_step() {
    printf "\n${BLU}>>>>>>> %s${NOC}\n" "$1"
}
echo_sub_step() {
    printf "\n${BLU}>>> %s${NOC}\n" "$1"
}

echo_step_completed() {
    printf "${GRN} [✔]${NOC}"
}

echo_success() {
    printf "\n${GRN}%s${NOC}\n" "$1"
}
echo_warn() {
    printf "\n${YLW}%s${NOC}" "$1"
}
echo_error() {
    printf "\n${RED}%s${NOC}" "$1"
    exit 1
}

# ------------------------------
projectdir="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"

# get the build environment variables from the special build.vars target in the main makefile
eval $(make --no-print-directory -C ${projectdir} build.vars)

K8S_CLUSTER="${K8S_CLUSTER:-${BUILD_REGISTRY}-inttests}"

CROSSPLANE_NAMESPACE="crossplane-system"

# cleanup on exit
if [ "$skipcleanup" != true ]; then
    function cleanup() {
        echo_step "Cleaning up..."
        export KUBECONFIG=
        "${KIND}" delete cluster --name="${K8S_CLUSTER}"
    }

    trap cleanup EXIT
fi

readonly DEFAULT_KIND_CONFIG="kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
"
echo_step "creating k8s cluster using kind with the following config:"
kind_config="${KIND_CONFIG:-$DEFAULT_KIND_CONFIG}"
echo "${kind_config}"
echo "${kind_config}" | "${KIND}" create cluster --name="${K8S_CLUSTER}" --config=- || $skipcleanup

echo_step "installing crossplane from stable channel"
"${HELM3}" repo add crossplane-stable https://charts.crossplane.io/stable/
chart_version="$("${HELM3}" search repo crossplane-stable/crossplane | awk 'FNR == 2 {print $2}')"
echo_info "using crossplane version ${chart_version}"
echo
"${HELM3}" install --create-namespace -n "${CROSSPLANE_NAMESPACE}" "${PROJECT_NAME}" crossplane-stable/crossplane --version ${chart_version} --set replicas=2,args={'-d'},rbacManager.replicas=2,rbacManager.args={'-d'},image.pullPolicy=Never,imagePullSecrets=''

echo_step "waiting for deployment ${PROJECT_NAME} rollout to finish"
"${KUBECTL}" -n "${CROSSPLANE_NAMESPACE}" rollout status "deploy/${PROJECT_NAME}" --timeout=2m

echo_step "wait until the pods are up and running"
"${KUBECTL}" -n "${CROSSPLANE_NAMESPACE}" wait --for=condition=Ready pods --all --timeout=1m

# ----------- integration tests
echo_step "--- INTEGRATION TESTS ---"
# install package
echo_step "installing ${PROJECT_NAME} into \"${CROSSPLANE_NAMESPACE}\" namespace"

echo_success "Integration tests succeeded!"
