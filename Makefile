

include .env
export


NAMESPACE := default
DEPLOYMENT_NAME := fastapi
#POD_NAME := $(shell kubectl get pods -n $(NAMESPACE) -l app=fastapi -o jsonpath='{.items[0].metadata.name}')

.PHONY: plan
plan:
	cd terraform && terraform plan

.PHONY: apply
apply:
	cd terraform && terraform apply -auto-approve

.PHONY: kubeconfig
kubeconfig:
	aws eks update-kubeconfig --name eks-cluster_fastapi --region us-east-1

.PHONY: namespace
namespace:
	kubectl apply -f k8s/Namespace.yaml

.PHONY: namespace_secret
namespace_secret:
	kubectl create secret docker-registry ghcr-secret \
	--docker-server=ghcr.io \
	--docker-username=$(DOCKER_USERNAME) \
	--docker-password=$(GHCR_SECRET_LB) \
	--namespace=lb


	kubectl create secret generic github-repo \
	-n argocd \
	--from-literal=type=git \
	--from-literal=url=https://github.com/$(DOCKER_USERNAME)/infra_argo_code \
	--from-literal=username=$(DOCKER_USERNAME) \
	--from-literal=password=$(GITHUB_REPO)
	kubectl label secret github-repo -n argocd argocd.argoproj.io/secret-type=repository


	kubectl create secret generic github-repo-cd \
	-n argocd \
	--from-literal=type=git \
	--from-literal=url=https://github.com/$(DOCKER_USERNAME)/CD_k8s \
	--from-literal=username=$(DOCKER_USERNAME) \
	--from-literal=password=$(GITHUB_REPO)

	kubectl label secret github-repo-cd -n argocd argocd.argoproj.io/secret-type=repository

	kubectl create secret generic argocd-image-updater-git \
	--namespace=argocd \
	--type=kubernetes.io/basic-auth \
	--from-literal=username=$(DOCKER_USERNAME) \
	--from-literal=password=$(GHCR_SECRET_LB)

	kubectl create secret docker-registry ghcr-secret \
	--namespace=argocd \
	--docker-server=ghcr.io \
	--docker-username=$(DOCKER_USERNAME) \
	--docker-password=$(GHCR_SECRET_ARGOCD)

	@sleep 5


.PHONY: argocd_install
argocd_install:
	- kubectl apply -n argocd \
		-l app.kubernetes.io/part-of=argocd \
		-f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
		--timeout=300s

.PHONY: argocd_install_image_updater
argocd_install_image_updater:
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/config/install.yaml


.PHONY: k8s_apply
k8s_apply:
	- kubectl apply -f k8s/

.PHONY: rollout_image_updater
rollout_image_updater:
	kubectl rollout restart deployment/argocd-image-updater-controller -n argocd

.PHONY: deploy
deploy:
	kubectl apply -f k8s/deployment.yaml
	kubectl apply -f k8s/service.yaml

.PHONY: delete
delete:
	cd terraform && terraform destroy -auto-approve

.PHONY: port-forward
port-forward:
	kubectl port-forward deployment/$(DEPLOYMENT_NAME) 8000:8000 -n $(NAMESPACE)

.PHONY: all_deploy
all_deploy: apply kubeconfig namespace namespace_secret argocd_install argocd_install_image_updater k8s_apply rollout_image_updater

.PHONY: linter
linter:
	yamllint -c .yamllint.yml .
	tflint --init
	tflint --recursive

