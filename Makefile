.PHONY: deploy delete port-forward

NAMESPACE := default
DEPLOYMENT_NAME := fastapi
POD_NAME := $(shell kubectl get pods -n $(NAMESPACE) -l app=fastapi -o jsonpath='{.items[0].metadata.name}')

deploy:
	kubectl apply -f k8s/deployment.yaml
	kubectl apply -f k8s/service.yaml

delete:
	kubectl delete -f k8s/deployment.yaml
	kubectl delete -f k8s/service.yaml

port-forward:
	kubectl port-forward deployment/$(DEPLOYMENT_NAME) 8000:8000 -n $(NAMESPACE)