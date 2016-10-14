NS = vp
NAME = bigcouch
APP_VERSION = 1.1.1
IMAGE_VERSION = 2.0
VERSION = $(APP_VERSION)-$(IMAGE_VERSION)
LOCAL_TAG = $(NS)/$(NAME):$(VERSION)

REGISTRY = callforamerica
ORG = vp
REMOTE_TAG = $(REGISTRY)/$(NAME):$(VERSION)

GITHUB_REPO = docker-bigcouch
DOCKER_REPO = bigcouch
BUILD_BRANCH = master


.PHONY: all build test release shell run start stop rm rmi default

all: build

checkout:
	@git checkout $(BUILD_BRANCH)

build:
	@docker build -t $(LOCAL_TAG) --force-rm .
	@$(MAKE) tag
	@$(MAKE) dclean

clean-pvc:
	@-kubectl delete pv -l app=bigcouch
	@-kubectl delete pvc -l app=bigcouch

patch-two:
	@kubectl patch petset bigcouch -p '{"spec": {"replicas": 2}}' 
	@kubectl get po --watch

patch-three:
	@kubectl patch petset bigcouch -p '{"spec": {"replicas": 3}}' 

test-down:
	@-kubectl delete petset bigcouch
	@-kubectl delete po bigcouch-0
	@-kubectl delete po bigcouch-1
	@-kubectl delete po bigcouch-2
	@$(MAKE) clean-pvc

test-up:
	@$(MAKE) load-pvs
	@$(MAKE) load-pvcs
	@sleep 10
	@kubectl create -f kubernetes/bigcouch-petset.yaml
	@kubectl get po --watch

retest:
	@$(MAKE) test-down
	@sleep 10
	@$(MAKE) test-up

tag:
	@docker tag $(LOCAL_TAG) $(REMOTE_TAG)

rebuild:
	@docker build -t $(LOCAL_TAG) --force-rm --no-cache .
	@$(MAKE) tag
	@$(MAKE) dclean

commit:
	@git add -A .
	@git commit

push:
	@git push origin master

shell:
	@docker exec -ti $(NAME) /bin/bash

run:
	@docker run -it -h $(NAME) --rm --name $(NAME) --entrypoint bash $(LOCAL_TAG)

launch:
	@docker run -d -h $(NAME) --name $(NAME) -p "5984:5984" -p "5986:5986" $(LOCAL_TAG)

launch-net:
	@docker run -d -h $(NAME).local --name $(NAME) --network=local --net-alias $(NAME).local $(LOCAL_TAG)

create-network:
	@docker network create -d bridge local

logs:
	@docker logs $(NAME)

logsf:
	@docker logs -f $(NAME)

start:
	@docker start $(NAME)

kill:
	@docker kill $(NAME)

stop:
	@docker stop $(NAME)

rm:
	@docker rm $(NAME)

rmi:
	@docker rmi $(LOCAL_TAG)
	@docker rmi $(REMOTE_TAG)

rmf:
	@docker rm -f $(NAME)

dclean:
	@-docker ps -aq | gxargs -I{} docker rm {} 2> /dev/null || true
	@-docker images -f dangling=true -q | xargs docker rmi
	@-docker volume ls -f dangling=true -q | xargs docker volume rm

kube-deploy-pvs:
	@kubectl create -f kubernetes/bigcouch-pvs.yaml

kube-deploy-pvcs:
	@kubectl create -f kubernetes/bigcouch-pvcs.yaml

kube-deploy:
	@$(MAKE) kube-deploy-petset
	
kube-deploy-petset:
	@kubectl create -f kubernetes/$(NAME)-petset.yaml

kube-edit-petset:
	@kubectl edit petset/$(NAME)

kube-delete-petset:
	@kubectl delete petset/$(NAME)

kube-deploy-service:
	@kubectl create -f kubernetes/$(NAME)-service.yaml
	@kubectl create -f kubernetes/$(NAME)-service-balanced.yaml

kube-delete-service:
	@kubectl delete svc $(NAME)
	@kubectl delete svc $(NAME)bal

kube-apply-service:
	@kubectl apply -f kubernetes/$(NAME)-service.yaml
	@kubectl apply -f kubernetes/$(NAME)-service-balanced.yaml

kube-load-pvs:
	@kubectl create -f kubernetes/bigcouch-pvs.yaml

kube-load-pvcs:
	@kubectl create -f kubernetes/bigcouch-pvcs.yaml

kube-delete-pvs:
	@kubectl delete -f kubernetes/bigcouch-pvs.yaml

kube-delete-pvcs:
	@kubectl delete -f kubernetes/bigcouch-pvcs.yaml

kube-logsf:
	@kubectl logs -f $(shell kubectl get po | grep $(NAME) | cut -d' ' -f1)

kube-logsft:
	@kubectl logs -f --tail=25 $(shell kubectl get po | grep $(NAME) | cut -d' ' -f1)

kube-shell:
	@kubectl exec -ti $(shell kubectl get po | grep $(NAME) | cut -d' ' -f1) -- bash


default: build