SHELL = /bin/bash
SHELLFLAGS = -ex

# Change as per your Docker Hub username
DOCKER_HUB_USERNAME = pras9479
APP_NAME = eks-app
AWS_ACCOUNT_ID = $(shell aws sts get-caller-identity --query 'Account' --output text)
AWS_REGION = $(shell aws sts get-caller-identity --query 'Arn' --output text | cut -d: -f5)

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
	docker build -t $(DOCKER_HUB_USERNAME)/$(APP_NAME) .
	docker images | grep $(APP_NAME)
.PHONY: build-eks-app

push-app-to-docker: build-eks-app ## Push docker image to docker hub
	$(info [+] Pushing newly built docker image to Docker hub...)
	docker login
	docker push $(DOCKER_HUB_USERNAME)/$(APP_NAME)
.PHONY: push-app-to-docker

run-eks-app:  ## Run eks-app locally in docker
	$(info [+] Running eks-app...)
	docker run -p 80:5000 $(APP_NAME)
.PHONY: run-eks-app
