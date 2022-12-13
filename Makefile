.PHONY : all install_kind_linux install_kind_mac create_kind_cluster generate_xrd 

KIND_VERSION := $(shell kind --version 2>/dev/null)

install_kind_linux : 
ifdef KIND_VERSION
	@echo "Found version $(KIND_VERSION)"
else
	@curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.10.0/kind-linux-amd64
	@chmod +x ./kind
	@mv ./kind /bin/kind
endif

install_kind_mac : 
ifdef KIND_VERSION
	@echo "Found version $(KIND_VERSION)"
else
	@brew install kind
endif

create_kind_cluster :
	@kind create cluster --name crossplane-cluster --wait 5m
	@kind get kubeconfig --name crossplane-cluster
	@kubectl config set-context crossplane-cluster 

install_crossplane : 
	@helm repo add crossplane-stable https://charts.crossplane.io/stable
	@helm repo update
	@helm install crossplane --create-namespace -n crossplane-system crossplane-stable/crossplane

generate_xrd :
	@PLURAL_NAME=$$(tr '[:upper:]' '[:lower:]' <<< $${KIND_NAME}) envsubst < base/xrd/template/xrd.yaml

# create_aws_creds :
# 	AWS_PROFILE=default && echo -e "[default]\naws_access_key_id = $(aws configure get aws_access_key_id --profile $AWS_PROFILE)\naws_secret_access_key = $(aws configure get aws_secret_access_key --profile $AWS_PROFILE)" > creds.conf
# 	@kubectl create secret generic aws-creds -n crossplane-system --from-file=creds=./creds.conf


all : install_kind_linux create_kind_cluster install_crossplane
