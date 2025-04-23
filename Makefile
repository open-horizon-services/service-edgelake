#!/bin/Makefile

# Default values
SHELL := /bin/bash

export EDGELAKE_TYPE ?= generic
export TEST_CONN ?=

# Detect OS type
export OS := $(shell uname -s)

# Conditional port override based on EDGELAKE_TYPE

export DOCKER_IMAGE_VERSION := latest
ARCH := $(shell uname -m)
ifeq ($(ARCH),aarch64 arm64)
	DOCKER_IMAGE_VERSION := latest-arm64
endif
ifneq ($(filter test-node test-network,$(MAKECMDGOALS)),test-node test-network)
	export NODE_NAME := $(shell cat docker-makefiles/edgelake_${EDGELAKE_TYPE}.env | grep NODE_NAME | awk -F "=" '{print $$2}'| sed 's/ /-/g' | tr '[:upper:]' '[:lower:]')
	export ANYLOG_SERVER_PORT := $(shell cat docker-makefiles/edgelake_${EDGELAKE_TYPE}.env | grep ANYLOG_SERVER_PORT | awk -F "=" '{print $$2}')
	export ANYLOG_REST_PORT := $(shell cat docker-makefiles/edgelake_${EDGELAKE_TYPE}.env | grep ANYLOG_REST_PORT | awk -F "=" '{print $$2}')
	export ANYLOG_BROKER_PORT := $(shell cat docker-makefiles/edgelake_${EDGELAKE_TYPE}.env | grep ANYLOG_BROKER_PORT | awk -F "=" '{print $$2}' | grep -v '^$$')
	export REMOTE_CLI := $(shell cat docker-makefiles/edgelake_${EDGELAKE_TYPE}.env | grep REMOTE_CLI | awk -F "=" '{print $$2}')
	export ENABLE_NEBULA := $(shell cat docker-makefiles/edgelake_${EDGELAKE_TYPE}.env | grep ENABLE_NEBULA | awk -F "=" '{print $$2}')
	export IMAGE := $(shell cat docker-makefiles/.env | grep IMAGE | awk -F "=" '{print $$2}')
endif

ifeq ($(OS),Linux)
	export DOCKER_COMPOSE_TEMPLATE := docker-makefiles/docker-compose-template-base.yaml
else
	export DOCKER_COMPOSE_TEMPLATE := docker-makefiles/docker-compose-template-ports-base.yaml
endif

export CONTAINER_CMD := $(shell if command -v podman >/dev/null 2>&1; then echo "podman"; else echo "docker"; fi)

export DOCKER_COMPOSE_CMD := $(shell if command -v podman-compose >/dev/null 2>&1; then echo "podman-compose"; \
	elif command -v docker-compose >/dev/null 2>&1; then echo "docker-compose"; else echo "docker compose"; fi)

all: help
generate-docker-compose:
	@bash docker-makefiles/update_docker_compose.sh
	@NODE_NAME="$(NODE_NAME)" ANYLOG_SERVER_PORT=${ANYLOG_SERVER_PORT} ANYLOG_REST_PORT=${ANYLOG_REST_PORT} ANYLOG_BROKER_PORT=${ANYLOG_BROKER_PORT} \
	REMOTE_CLI=$(REMOTE_CLI) ENABLE_NEBULA=$(ENABLE_NEBULA) \
	envsubst < docker-makefiles/docker-compose-template.yaml > docker-makefiles/docker-compose.yaml

build: ## pull image from the docker hub repository
	$(CONTAINER_CMD) pull docker.io/anylogco/edgelake:$(DOCKER_IMAGE_VERSION)

dry-run: generate-docker-compose ## create docker-compose.yaml file based on the .env configuration file(s)
	@echo "Dry Run $(EDGELAKE_TYPE)"

up: ## start EdgeLake instance
	@echo "Deploy EdgeLake $(EDGELAKE_TYPE)"
	@$(MAKE) generate-docker-compose
	@$(DOCKER_COMPOSE_CMD) -f docker-makefiles/docker-compose.yaml up -d
	@rm -f docker-makefiles/docker-compose.yaml docker-makefiles/docker-compose-template.yaml
down: ## Stop EdgeLAke instance
	@echo "Stop EdgeLake $(EDGELAKE_TYPE)"
	@$(MAKE) generate-docker-compose
	@$(DOCKER_COMPOSE_CMD) -f docker-makefiles/docker-compose.yaml down
	@rm -f docker-makefiles/docker-compose.yaml docker-makefiles/docker-compose-template.yaml
clean-vols: ## Stop & remove volumes for EdgeLAke instance
	@echo "Stop + remove volumes for EdgeLake $(EDGELAKE_TYPE)"
	@$(MAKE) generate-docker-compose
	@$(DOCKER_COMPOSE_CMD) -f docker-makefiles/docker-compose.yaml down -v
	@rm -f docker-makefiles/docker-compose.yaml docker-makefiles/docker-compose-template.yaml
clean: ## Stop AnyLog instance and remove associated volumes & image
	@echo "Stop EdgeLake $(EDGELAKE_TYPE) & Remove Volumes and Images"
	@$(MAKE) generate-docker-compose
	@$(DOCKER_COMPOSE_CMD) -f docker-makefiles/docker-compose.yaml down --volumes --rmi all
	@rm -f docker-makefiles/docker-compose.yaml docker-makefiles/docker-compose-template.yaml

attach: ## Attach to docker / podman container (use ctrl-d to detach)
	@$(CONTAINER_CMD) attach --detach-keys=ctrl-d $(NODE_NAME)

exec: ## Attach to the shell executable for the container
	@$(CONTAINER_CMD) exec -it $(NODE_NAME) /bin/bash

logs: ## View container logs
	@$(CONTAINER_CMD) logs $(NODE_NAME)

test-node: ## Test a node via REST interface
ifeq ($(TEST_CONN), )
	@echo "Missing Connection information (Param Name: TEST_CONN)"
	exit 1
endif
	@echo "Test Node against $(TEST_CONN)"
	@curl -X GET http://$(TEST_CONN) -H "command: test node" -H "User-Agent: AnyLog/1.23" -w "\n"

test-network: ## Test the network via REST interface
ifeq ($(TEST_CONN), )
	@echo "Missing Connection information (Param Name: TEST_CONN)"
	exit 1
endif
	@echo "Test Network against $(TEST_CONN)"
	@curl -X GET http://$(TEST_CONN) -H "command: test network" -H "User-Agent: AnyLog/1.23" -w "\n"
check-vars: ## Show all environment variable values
	@echo "EDGELAKE_TYPE         Default: generic            Value: $(EDGELAKE_TYPE)"
	@echo "NODE_NAME             Default: edgelake-node      Value: $(NODE_NAME)"
	@echo "DOCKER_IMAGE_VERSION  Default: latest             Value: $(DOCKER_IMAGE_VERSION)"
	@echo "ANYLOG_SERVER_PORT    Default: 32548              Value: $(ANYLOG_SERVER_PORT)"
	@echo "ANYLOG_REST_PORT      Default: 32549              Value: $(ANYLOG_REST_PORT)"
	@echo "ANYLOG_BROKER_PORT    Default:                    Value: $(ANYLOG_BROKER_PORT)"
help:
	@echo "Usage: make [target] [VARIABLE=value]"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk -F':|##' '{ printf "  \033[36m%-20s\033[0m %s\n", $$1, $$3 }'
	@echo ""
	@echo "Common variables you can override:"
	@echo "  EDGELAKE_TYPE         Type of node to deploy (e.g., master, operator)"
	@echo "  DOCKER_IMAGE_VERSION  Docker image tag to use"
	@echo "  NODE_NAME           Custom name for the container"
	@echo "  ANYLOG_SERVER_PORT  Port for server communication"
	@echo "  ANYLOG_REST_PORT    Port for REST API"
	@echo "  ANYLOG_BROKER_PORT  Optional broker port"
	@echo "  TEST_CONN           REST connection information for testing network connectivity"