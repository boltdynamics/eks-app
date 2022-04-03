SHELL = /bin/bash
SHELLFLAGS = -ex

include ./settings/defaults.conf
ifneq ("$(wildcard ./settings/$(ENVIRONMENT).conf"), "")
-include ./settings/$(ENVIRONMENT).conf
endif

help:  ## Get help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
.PHONY: help

install:  ## Create/re-create pipenv virtual environment
	$(info [+] Running pipenv install...)
	pipenv install --dev
.PHONY: install

generate-requirements:  ## Generate dependencies file as requirements.txt
	$(info [+] Generating requirements.txt...)
	pipenv lock -r > requirements.txt
.PHONY: generate-requirements

build-eks-app:  ## Build docker image for eks-app
	$(info [+] Building docker image...)
	docker build -t $(DOCKER_HUB_USERNAME)/$(APPLICATION_NAME) .
	docker images | grep $(APPLICATION_NAME)
.PHONY: build-eks-app

push-app-to-docker-hub: build-eks-app ## Push docker image to docker hub
	$(info [+] Pushing newly built docker image to Docker hub...)
	docker login
	docker push $(DOCKER_HUB_USERNAME)/$(APPLICATION_NAME)
.PHONY: push-app-to-docker-hub

run-eks-app:  ## Run eks-app locally in docker
	$(info [+] Running eks-app...)
	docker run -p 80:5000 $(DOCKER_HUB_USERNAME)/$(APPLICATION_NAME)
.PHONY: run-eks-app

update-kubeconfig:  ## Update local kubeconfig to interact with the cluster
	$(info [+] Updating local kubeconfig...)
	$(eval EKS_CLUSTER_NAME := $(shell aws ssm get-parameter --name $(EKS_CLUSTER_NAME_SSM_PATH) --query Parameter.Value --output text))
	$(info [+] Cluster name: $(EKS_CLUSTER_NAME))
	aws eks update-kubeconfig --name $(EKS_CLUSTER_NAME)
.PHONY: update-kubeconfig

deploy-irsa-role: ## Deploy IRSA Role for application pod to consume
	aws cloudformation deploy \
		--s3-bucket $(CFN_ARTIFACT_BUCKET_NAME) \
	    --template-file cloudformation/irsa-role.yaml \
		--stack-name $(APPLICATION_NAME)-irsa-role \
		--capabilities CAPABILITY_NAMED_IAM \
		--no-fail-on-empty-changeset \
		--parameter-overrides \
			OidcProvider=$(OIDC_PROVIDER_URL_SSM_PATH) \
			AppNamespace=$(APPLICATION_NAMESPACE) \
			ServiceAccountName=$(APPLICATION_SERVICE_ACCOUNT_NAME) \
			EksAppRoleSsmParameterPath=$(EKS_APP_ROLE_SSM_PARAMETER_PATH) \
		--tags \
			Name='Kubernetes Cluster Resources - IRSA Role'
.PHONY: deploy-irsa-role

deploy-eks-app: ## Deploy eks-app to EKS cluster
	$(info [+] Deploying eks-app to EKS cluster...)
	$(eval IRSA_IAM_ROLE_ARN := $(shell aws ssm get-parameter --name $(EKS_APP_ROLE_SSM_PARAMETER_PATH) --query Parameter.Value --output text))
	export APPLICATION_SERVICE_ACCOUNT_NAME=$(APPLICATION_SERVICE_ACCOUNT_NAME) && export APPLICATION_NAMESPACE=$(APPLICATION_NAMESPACE) \
		&& export IRSA_IAM_ROLE_ARN=$(IRSA_IAM_ROLE_ARN) && export APPLICATION_NAME=$(APPLICATION_NAME) \
		&& export DOCKER_HUB_USERNAME=$(DOCKER_HUB_USERNAME) \
		&& envsubst < kubernetes/app.yaml | kubectl apply -f -
.PHONY: deploy-eks-app

port-forward-eks-app: ## Port forward eks-app to localhost
	$(info [+] Port forwarding eks-app to localhost...)
	sudo kubectl port-forward -n $(APPLICATION_NAMESPACE) deployment/$(APPLICATION_NAME)-deployment 80:5000
.PHONY: port-forward-eks-app
