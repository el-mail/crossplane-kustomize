#!/usr/bin/env bash
set -e

# setting up colors
BLU='\033[0;34m'
YLW='\033[0;33m'
GRN='\033[0;32m'
RED='\033[0;31m'
NOC='\033[0m' # No Color
echo_info(){
    printf "\n${BLU}%s${NOC}" "$1"
}
echo_step(){
    printf "\n${BLU}>>>>>>> %s${NOC}\n" "$1"
}
echo_sub_step(){
    printf "\n${BLU}>>> %s${NOC}\n" "$1"
}

echo_step_completed(){
    printf "${GRN} [✔]${NOC}"
}

echo_success(){
    printf "\n${GRN}%s${NOC}\n" "$1"
}
echo_warn(){
    printf "\n${YLW}%s${NOC}" "$1"
}
echo_error(){
    printf "\n${RED}%s${NOC}" "$1"
    exit 1
}

# ------------------------------
projectdir="$( cd "$( dirname "${BASH_SOURCE[0]}")"/.. && pwd )"

# get the build environment variables from the special build.vars target in the main makefile
eval $(make --no-print-directory -C ${projectdir} build.vars)

# ------------------------------

cloud_name=$(sed -e 's/upbound-//g' -e 's/provider-//g' <<<$1)
provider_name=$1
provider_lower_name=$(tr '[:upper:]' '[:lower:]' <<<$provider_name)
provider_upper_name=$(tr '[:lower:]' '[:upper:]' <<<$provider_name)

resource_name=$2
resource_lower_name=$(tr '[:upper:]' '[:lower:]' <<<$resource_name)

KIND_NAME="${cloud_upper_name}$(tr '[:lower:]' '[:upper:]' <<< ${resource_name:0:1})${resource_name:1}"
PLURAL_NAME=$(tr '[:upper:]' '[:lower:]' <<<$KIND_NAME)

composition_dir=$projectdir/base/$provider_lower_name/$resource_lower_name


# cleanup on exit
if [ "$skipcleanup" != true ]; then
    function cleanup() {
        echo_step "Cleaning up..."
        echo
    }

    trap cleanup EXIT
fi

echo_step "create xrd"
echo_sub_step "check if is resource exist"
if [ -d $composition_dir ]; then
    pwd
    ls -l $composition_dir
    echo_success "Resource already exist"
    exit
fi

echo_sub_step "create directory"
mkdir -p "${composition_dir}"

echo_sub_step "generate kustomize file"
KUSTOMIZE_YAML="$( cat <<EOF
resources:
  - ../../xrd/$cloud_name/$resource_lower_name
  - composition.yaml

components:
  - ../../../components/composition
EOF
)"
echo "${KUSTOMIZE_YAML}" > ${composition_dir}/kustomization.yaml

echo_sub_step "generate xrd file"
XRD_YAML="$( cat <<EOF
apiVersion: apiextensions.crossplane.io/v1
kind: Composition
metadata:
  name: xcrossplane${PLURAL_NAME}s
spec:
  resources:
EOF
)"
echo "${XRD_YAML}" > ${composition_dir}/composition.yaml

echo_success "Successfully generated xrd!"