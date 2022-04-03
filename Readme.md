## Dockerised kubernetes app designed to work in an AWS EKS environment

### Overview

Wanting to do something like [Sample Golang AWS EKS App](https://github.com/aws-samples/amazon-eks-sample-http-service), I have created a dockerised kubernetes app that can be deployed to AWS EKS. The difference is that this app is written in python vs golang.

This simple app renders a homepage with useful information about,
* The location of the pod inside the cluster - instance id, availability zone
* Client information - ip address
* Pod information - namespace, name
* Application name

### Prerequisites

An EKS cluster and a nodegroup to deploy the app to.

If you donot have a cluster setup yet, you could follow my blogpost on how to create one [here](https://learnwithpras.xyz/infrastructure-as-code-iac-to-deploy-managed-eks-cluster-and-node-group-on-aws). The source code for deploying the cluster and node group is available [here](https://github.com/boltdynamics/eks-infra).

Change the values of `OIDC_PROVIDER_URL_SSM_PATH` and `EKS_CLUSTER_NAME_SSM_PATH` in `settings/defaults.conf` to match your environment if you have not followed my blog and infra deployment code to deploy your infrastrtucture.

### Configuration file

Naming for resources is based off the configuration file `defaults.conf` stored under `settings` directory.

`Makefile` uses the values defined in the configuration file to create the docker image, IAM Role for service accounts, kubernetes namespace and deployment

Change the values in the configuration file as needed before running `make` commands.

### Initialize your virtual environment

Python version is use is 3.9 and is set in the Pipfile.

Run `make install` to install the dependencies. These dependencies are,
* [boto3](https://boto3.amazonaws.com/v1/documentation/api/latest/index.html)
* [flask](https://flask.palletsprojects.com/en/2.1.x/)
* [flask-bootstrap](https://pythonhosted.org/Flask-Bootstrap/)

### Generate requirements.txt
Run `make generate-requirements` to generate a requirements.txt file.

### Build Docker Image
Run `make build-eks-app` to build the docker image.

Docker image is built upon a base **python:alpine3.15** image to keep the image small.

Docker user is set to **1001** and it exposes port **5000**.

Container security context: **runAsNonRoot** set to **true** to avoid giving containers access to host resources backed by **allowPrivilegeEscalation** set to **false** in the deployment spec hosted under `kubernetes/app.yaml`.

### Dockerhub to store the image

The easiest way to deploy and test the image is to push it to Dockerhub with your credentials or token.

Update your docker username under `settings/defaults.conf` configuration file.

Run `make push-app-to-docker-hub` to push the image to Dockerhub.

### Deploy IRSA Role

**IAM Role for Service Accounts (IRSA)** allows us to to scope the permissions of the service account to the IAM Role we create for any interactions with AWS.

Any container running in a pod assigned to the service account will have access to AWS Resources with limited permissions defined in the IAM Role. This allows us to follow the principle of **least privilege**.

For this example, we will create a IAM Role with the following permissions:
* ec2:DescribeNetworkInterfaces

We add the IAM role as an annotation to the kubernetes service account and we store the role's ARN in a SSM parameter so we can use it for discovery when needed.

Run `make deploy-irsa-role` to deploy the IAM Role to AWS EKS.

### Running the app

Running the docker app locally might not be the best option as the application code is designed to work within a Kubernetes environment.

Run `make deploy-eks-app` to deploy,
* A namespace for the application
* A service account for the application
    * The service account has the IAM role annotation set to the IRSA Role we create
* A deployment of the application

However, it is possible to run the app locally with `make run-eks-app` command.

### Port forwarding to test the application locally

To test if the application is working as expected in EKS environment, we can use the `kubectl port-forward` command to forward the port from the pod to our localhost and try out the application locally.

Run `make port-forward-eks-app` to portforward eks app running on port **5000** to localhost port **80**.

![eks-app-port-forward](assets/eks-app.png)
