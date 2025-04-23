#!/bin/Makefile

SHELL := /bin/bash
ifneq ($(filter-out $@,$(MAKECMDGOALS)), )
   export EDGELAKE_TYPE = $(filter-out $@,$(MAKECMDGOALS))
else
	export EDGELAKE_TYPE := generic
endif

export ARCH ?= $(shell hzn architecture)
export DOCKER_IMAGE_VERSION := 1.3.2501
# Check if the architecture matches aarch64 or arm64
ifeq ($(ARCH),aarch64)
    DOCKER_IMAGE_VERSION := 1.3.2501-arm64
else ifeq ($(ARCH),arm64)
    DOCKER_IMAGE_VERSION := 1.3.2501-arm64
else
    DOCKER_IMAGE_VERSION := 1.3.2501
endif

export CONTAINER_CMD := $(shell if command -v podman >/dev/null 2>&1; then echo "podman"; \
	else echo "docker"; fi)

export DOCKER_COMPOSE_CMD := $(shell if command -v podman-compose >/dev/null 2>&1; then echo "podman-compose"; \
	elif command -v docker-compose >/dev/null 2>&1; then echo "docker-compose"; else echo "docker compose"; fi)

-include docker-makefiles/edgelake_${EDGELAKE_TYPE}.env
export
# Open Horizon Configs
export HZN_ORG_ID ?= myorg
export HZN_LISTEN_IP ?= 127.0.0.1
export SERVICE_NAME ?= service-edgelake-$(EDGELAKE_TYPE)
export SERVICE_VERSION ?= 1.3.1
#export SERVICE_VERSION ?= 1.3.0

export NODE_NAME := $(shell cat docker-makefiles/edgelake_${EDGELAKE_TYPE}.env | grep NODE_NAME | awk -F "=" '{print $$2}'| sed 's/ /-/g' | tr '[:upper:]' '[:lower:]')
export IMAGE := $(shell cat docker-makefiles/.env | grep IMAGE | awk -F "=" '{print $$2}')
export IMAGE_NAME := $(shell echo $(IMAGE) | awk -F "/" '{print $$2}')
export IMAGE_ORG := $(shell echo $(IMAGE) | awk -F "/" '{print $$1}')

# Only execute shell commands if NOT called with test-node or test-network
export ANYLOG_SERVER_PORT := $(shell cat docker-makefiles/edgelake_${EDGELAKE_TYPE}.env | grep ANYLOG_SERVER_PORT | awk -F "=" '{print $$2}')
export ANYLOG_REST_PORT := $(shell cat docker-makefiles/edgelake_${EDGELAKE_TYPE}.env | grep ANYLOG_REST_PORT | awk -F "=" '{print $$2}')
export ANYLOG_BROKER_PORT := $(shell cat docker-makefiles/edgelake_${EDGELAKE_TYPE}.env | grep ANYLOG_BROKER_PORT | awk -F "=" '{print $$2}' | grep -v '^$$')
export REMOTE_CLI := $(shell cat docker-makefiles/edgelake_${EDGELAKE_TYPE}.env | grep REMOTE_CLI | awk -F "=" '{print $$2}')
export ENABLE_NEBULA := $(shell cat docker-makefiles/edgelake_${EDGELAKE_TYPE}.env | grep ENABLE_NEBULA | awk -F "=" '{print $$2}')

export ANYLOG_VOLUME := $(NODE_NAME)-anylog
export BLOCKCHAIN_VOLUME := $(NODE_NAME)-blockchain
export DATA_VOLUME := $(NODE_NAME)-data
export LOCAL_SCRIPTS_VOLUME := $(NODE_NAME)-local-scripts

$(shell python3 create_policy.py 1.3.1 docker-makefiles/edgelake_${EDGELAKE_TYPE}.env)
# Detect OS type
export OS := $(shell uname -s)
# Choose Docker Compose template based on OS
ifeq ($(OS),Linux)
	export DOCKER_COMPOSE_TEMPLATE := docker-makefiles/docker-compose-template-base.yaml
else
	export DOCKER_COMPOSE_TEMPLATE := docker-makefiles/docker-compose-template-ports-base.yaml
endif

CONTAINER_ID = $(shell $(CONTAINER_CMD) ps -a | grep $(IMAGE) | grep $(NODE_TYPE) | awk '{print $$1}')

# prepare
all: help
	@echo $(ARCH)
help: help-docker help-open-horizon
login:
	$(CONTAINER_CMD) login docker.io -u anyloguser --password $(EDGELAKE_TYPE)
build:
	$(CONTAINER_CMD) pull docker.io/anylogco/$(IMAGE):$(DOCKER_IMAGE_VERSION)
dry-run: generate-docker-compose
	@echo "Dry Run $(EDGELAKE_TYPE)"
check:
	@echo "====================="
	@echo "ENVIRONMENT VARIABLES"
	@echo "====================="
	@echo "EDGELAKE_TYPE          default: generic                               actual: $(EDGELAKE_TYPE)"
	@echo "DOCKER_IMAGE_BASE      default: anylogco/edgelake                     actual: $(IMAGE)"
	@echo "DOCKER_IMAGE_NAME      default: edgelake                              actual: $(IMAGE_NAME)"
	@echo "DOCKER_IMAGE_VERSION   default: latest                                actual: $(DOCKER_IMAGE_VERSION)"
	@echo "DOCKER_HUB_ID          default: anylogco                              actual: $(IMAGE_ORG)"
	@echo "HZN_ORG_ID             default: myorg                                 actual: ${HZN_ORG_ID}"
	@echo "HZN_LISTEN_IP          default: 127.0.0.1                             actual: ${HZN_LISTEN_IP}"
	@echo "SERVICE_NAME                                                          actual: ${SERVICE_NAME}"
	@echo "SERVICE_VERSION                                                       actual: ${SERVICE_VERSION}"
	@echo "ARCH                   default: amd64                                 actual: ${ARCH}"
	@echo "==================="
	@echo "EDGELAKE DEFINITION"
	@echo "==================="
	@echo "NODE_TYPE              default: generic                               actual: ${NODE_TYPE}"
	@echo "NODE_NAME              default: edgelake-node                         actual: $(NODE_NAME)"
	@echo "COMPANY_NAME           default: New Company                           actual: $(COMPANY_NAME)"
	@echo "ANYLOG_SERVER_PORT     default: 32548                                 actual: $(ANYLOG_SERVER_PORT)"
	@echo "ANYLOG_REST_PORT       default: 32549                                 actual: $(ANYLOG_REST_PORT)"
	@echo "LEDGER_CONN            default: 127.0.0.1:32049                       actual: ${LEDGER_CONN}"
	@echo ""

# docker deployment
generate-docker-compose:
	@bash docker-makefiles/update_docker_compose.sh
	@if [ "$(REMOTE_CLI)" == "true" ] && [ "$(ENABLE_NEBULA)" == "true" ] && [ ! -z "$(ANYLOG_BROKER_PORT)" ]; then \
  		NODE_NAME="$(NODE_NAME)" ANYLOG_SERVER_PORT=${ANYLOG_SERVER_PORT} ANYLOG_REST_PORT=${ANYLOG_REST_PORT} ANYLOG_BROKER_PORT=${ANYLOG_BROKER_PORT} envsubst < docker-makefiles/docker-compose-template.yaml > docker-makefiles/docker-compose.yaml; \
  	elif [ "$(REMOTE_CLI)" == "false" ] && [ "$(ENABLE_NEBULA)" == "true" ] && [ ! -z "$(ANYLOG_BROKER_PORT)" ]; then \
  		NODE_NAME="$(NODE_NAME)" ANYLOG_SERVER_PORT=${ANYLOG_SERVER_PORT} ANYLOG_REST_PORT=${ANYLOG_REST_PORT} ANYLOG_BROKER_PORT=${ANYLOG_BROKER_PORT} envsubst < docker-makefiles/docker-compose-template.yaml > docker-makefiles/docker-compose.yaml; \
	elif [ "$(REMOTE_CLI)" == "true" ] && [ "$(ENABLE_NEBULA)" == "false" ] && [ ! -z "$(ANYLOG_BROKER_PORT)" ]; then \
  		NODE_NAME="$(NODE_NAME)" ANYLOG_SERVER_PORT=${ANYLOG_SERVER_PORT} ANYLOG_REST_PORT=${ANYLOG_REST_PORT} ANYLOG_BROKER_PORT=${ANYLOG_BROKER_PORT} envsubst < docker-makefiles/docker-compose-template.yaml > docker-makefiles/docker-compose.yaml; \
	elif [ "$(REMOTE_CLI)" == "true" ] && [ "$(ENABLE_NEBULA)" == "true" ] && [ -z "$(ANYLOG_BROKER_PORT)" ]; then \
  		NODE_NAME="$(NODE_NAME)" ANYLOG_SERVER_PORT=${ANYLOG_SERVER_PORT} ANYLOG_REST_PORT=${ANYLOG_REST_PORT} envsubst < docker-makefiles/docker-compose-template.yaml > docker-makefiles/docker-compose.yaml; \
	elif [ "$(REMOTE_CLI)" == "true" ] && [ "$(ENABLE_NEBULA)" == "false" ] && [ -z "$(ANYLOG_BROKER_PORT)" ]; then \
  		NODE_NAME="$(NODE_NAME)" ANYLOG_SERVER_PORT=${ANYLOG_SERVER_PORT} ANYLOG_REST_PORT=${ANYLOG_REST_PORT} envsubst < docker-makefiles/docker-compose-template.yaml > docker-makefiles/docker-compose.yaml; \
	elif [ "$(REMOTE_CLI)" == "false" ] && [ "$(ENABLE_NEBULA)" == "true" ] && [ -z "$(ANYLOG_BROKER_PORT)" ]; then \
  		NODE_NAME="$(NODE_NAME)" ANYLOG_SERVER_PORT=${ANYLOG_SERVER_PORT} ANYLOG_REST_PORT=${ANYLOG_REST_PORT} envsubst < docker-makefiles/docker-compose-template.yaml > docker-makefiles/docker-compose.yaml; \
	elif [ "$(REMOTE_CLI)" == "false" ] && [ "$(ENABLE_NEBULA)" == "false" ] && [ ! -z "$(ANYLOG_BROKER_PORT)" ]; then \
  		NODE_NAME="$(NODE_NAME)" ANYLOG_SERVER_PORT=${ANYLOG_SERVER_PORT} ANYLOG_REST_PORT=${ANYLOG_REST_PORT} ANYLOG_BROKER_PORT=${ANYLOG_BROKER_PORT} envsubst < docker-makefiles/docker-compose-template.yaml > docker-makefiles/docker-compose.yaml; \
  	else \
  	  ANYLOG_SERVER_PORT=${ANYLOG_SERVER_PORT} ANYLOG_REST_PORT=${ANYLOG_REST_PORT} envsubst < docker-makefiles/docker-compose-template.yaml > docker-makefiles/docker-compose.yaml; \
  	fi
up: generate-docker-compose
	@echo "Deploy EdgeLake $(EDGELAKE_TYPE)"
	@${DOCKER_COMPOSE_CMD} -f docker-makefiles/docker-compose.yaml up -d
	@rm -rf docker-makefiles/docker-compose.yaml docker-makefiles/docker-compose-template.yaml
down: generate-docker-compose
	@echo "Stop EdgeLake $(EDGELAKE_TYPE)"
	@${DOCKER_COMPOSE_CMD} -f docker-makefiles/docker-compose.yaml down
	@rm -rf docker-makefiles/docker-compose.yaml docker-makefiles/docker-compose-template.yaml
clean-vols: generate-docker-compose
	@${DOCKER_COMPOSE_CMD} -f docker-makefiles/docker-compose.yaml down --volumes
	@rm -rf docker-makefiles/docker-compose.yaml docker-makefiles/docker-compose-template.yaml
clean: generate-docker-compose
	EDGELAKE_TYPE=$(EDGELAKE_TYPE) envsubst < $(DOCKER_COMPOSE_TEMPLATE) > docker-makefiles/docker-compose.yaml
	@${DOCKER_COMPOSE_CMD} -f docker-makefiles/docker-compose.yaml down --volumes --rmi all
	@rm -rf docker-makefiles/docker-compose.yaml docker-makefiles/docker-compose-template.yaml
attach:
	@$(CONTAINER_CMD) attach --detach-keys=ctrl-d $(CONTAINER_ID)
exec:
	@$(CONTAINER_CMD) exec -it $(CONTAINER_ID) /bin/bash
logs:
	@$(CONTAINER_CMD) logs $(CONTAINER_ID)

# Open Horizon
publish: publish-service publish-service-policy publish-deployment-policy
publish-version: publish-service publish-service-policy
deploy: publish-deployment-policy
hzn-clean: hzn-clean remove-deployment-policy remove-service-policy remove-service

# Pull, not push, Docker image since provided by third party
publish-service:
	@echo "=================="
	@echo "PUBLISHING SERVICE"
	@echo "=================="
	@echo ${HZN_EXCHANGE_USER_AUTH}
	@echo hzn exchange service publish --org=${HZN_ORG_ID} -u ${HZN_EXCHANGE_USER_AUTH} -O -P --json-file=service.definition.json
	@hzn exchange service publish --org=${HZN_ORG_ID} --user-pw=${HZN_EXCHANGE_USER_AUTH} -O -P --json-file=service.definition.json
	@echo ""
remove-service:
	@echo "=================="
	@echo "REMOVING SERVICE"
	@echo "=================="
	@hzn exchange service remove -f $(HZN_ORG_ID)/$(SERVICE_NAME)_$(SERVICE_VERSION)_$(ARCH)
	@echo ""

publish-service-policy:
	@echo "========================="
	@echo "PUBLISHING SERVICE POLICY"
	@echo "========================="
	@hzn exchange service addpolicy --org=${HZN_ORG_ID} --user-pw=${HZN_EXCHANGE_USER_AUTH} -f service.policy.json $(HZN_ORG_ID)/$(SERVICE_NAME)_$(SERVICE_VERSION)_$(ARCH)
	@echo ""
remove-service-policy:
	@echo "======================="
	@echo "REMOVING SERVICE POLICY"
	@echo "======================="
	@hzn exchange service removepolicy -f $(HZN_ORG_ID)/$(SERVICE_NAME)_$(SERVICE_VERSION)_$(ARCH)
	@echo ""

publish-deployment-policy:
	@echo "============================"
	@echo "PUBLISHING DEPLOYMENT POLICY"
	@echo "============================"
	@hzn exchange deployment addpolicy --org=$(HZN_ORG_ID) --user-pw=$(HZN_EXCHANGE_USER_AUTH) -f service.deployment.json $(HZN_ORG_ID)/policy-$(SERVICE_NAME)_$(SERVICE_VERSION)
	@echo ""
remove-deployment-policy:
	@echo "=========================="
	@echo "REMOVING DEPLOYMENT POLICY"
	@echo "=========================="
	@hzn exchange deployment removepolicy -f $(HZN_ORG_ID)/policy-$(SERVICE_NAME)_$(SERVICE_VERSION)
	@echo ""

agent-run:
	@echo "================"
	@echo "REGISTERING NODE"
	@echo "================"
	@hzn register --name=hzn-client --policy=node.policy.json
	@watch hzn agreement list

hzn-clean:
	@echo "==================="
	@echo "UN-REGISTERING NODE"
	@echo "==================="
	@hzn unregister -f
	@echo ""

hzn-logs: # logs for Docker container when running in OpenHorizon
	@$(CONTAINER_CMD) logs $(CONTAINER_ID)

# Testing
test-node: test-conn
	@CONN=$$(cat conn.tmp); \
	echo "Node State against $$CONN"; \
	curl -X GET http://$$CONN -H "command: get status"    -H "User-Agent: AnyLog/1.23" -w "\n"; \
	curl -X GET http://$$CONN -H "command: test node"     -H "User-Agent: AnyLog/1.23" -w "\n"; \
	curl -X GET http://$$CONN -H "command: get processes" -H "User-Agent: AnyLog/1.23" -w "\n"; \
	rm -rf conn.tmp
test-network: test-conn
	@CONN=$$(cat conn.tmp); \
	echo "Test Network Against: $$CONN"; \
	curl -X GET http://$$CONN -H "command: test network" -H "User-Agent: AnyLog/1.23" -w "\n"; \
	rm -rf conn.tmp

# Help
help-docker:
	@echo "====================="
	@echo "Docker Deployment Options"
	@echo "====================="
	@echo "build            pull latest image for $(DOCKER_IMAGE_BASE):$(DOCKER_IMAGE_VERSION)"
	@echo "up               bring up docker container based on EDGELAKE_TYPE"
	@echo "attach           attach to docker container based on EDGELAKE_TYPE"
	@echo "logs             view docker container logs based on EDGELAKE_TYPE"
	@echo "down             stop docker container based on EDGELAKE_TYPE"
	@echo "clean            (stop and) remove volumes and images for a docker container basd on EDGELAKE_TYPE"
	@echo "tset-node        using cURL make sure EdgeLake is accessible and is configured properly"
	@echo "test-network     using cURL make sure EdgeLake node is able to communicate with nodes in the network"
help-open-horizon:
	@echo "=============================="
	@echo "OpenHorizon Deployment Options"
	@echo "=============================="
	@echo "publish                    publish service and deployment policy to OpenHorizon"
	@echo "publish-version            publish new version of service to OpenHorizon"
	@echo "deploy                     publish deployment policy of new version of service to OpenHorizon"
	@echo "publish-service            publish service to OpenHorizon"
	@echo "remove-service             remove service from OpenHorizon"
	@echo "publish-service-policy     publish service policy to OpenHorizon"
	@echo "remove-service-policy      remove service policy from OpenHorizon"
	@echo "publish-deployment-policy  publish deployment policy to OpenHorizon"
	@echo "remove-deployment-policy   remove deployment policy from OpenHorizon"
	@echo "deploy-check               check OpenHorizon deployment"
	@echo "agent-run                  start OpenHorizon service"
	@echo "hzn-clean                  stop OpenHorizon service"
