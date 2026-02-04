.PHONY: deploy delete port-forward apply kubeconfig namespace namespace_secret argocd_install argocd_install_image_updater k8s_apply rollout_image_updater

include .env
export


NAMESPACE := default
DEPLOYMENT_NAME := fastapi
#POD_NAME := $(shell kubectl get pods -n $(NAMESPACE) -l app=fastapi -o jsonpath='{.items[0].metadata.name}')

plan:
	cd terraform && terraform plan

apply:
	cd terraform && terraform apply -auto-approve

kubeconfig:
	aws eks update-kubeconfig --name eks-cluster_fastapi --region us-east-1

namespace:
	kubectl apply -f k8s/Namespace.yaml


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



argocd_install:
	- kubectl apply -n argocd \
		-l app.kubernetes.io/part-of=argocd \
		-f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml \
		--timeout=300s

argocd_install_image_updater:
	kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/config/install.yaml

k8s_apply:
	- kubectl apply -f k8s/


rollout_image_updater:
	kubectl rollout restart deployment/argocd-image-updater-controller -n argocd

deploy:
	kubectl apply -f k8s/deployment.yaml
	kubectl apply -f k8s/service.yaml

delete:
	cd terraform && terraform destroy -auto-approve

port-forward:
	kubectl port-forward deployment/$(DEPLOYMENT_NAME) 8000:8000 -n $(NAMESPACE)

all_deploy: apply kubeconfig namespace namespace_secret argocd_install argocd_install_image_updater k8s_apply rollout_image_updater