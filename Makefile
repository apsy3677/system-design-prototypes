SHELL   := /bin/bash
COMPOSE := docker compose -f deploy/compose.yml

# Compose profiles to start: core | mysql | chaos | obs | all (space-separated).
PROFILES ?= core
# Lab folder under labs/ for bench/load, e.g. LAB=01-airline-checkin. Empty = all labs.
LAB ?=

ifeq ($(PROFILES),all)
PROFILE_FLAGS := --profile '*'
else
PROFILE_FLAGS := $(addprefix --profile ,$(PROFILES))
endif

PKGS := $(if $(LAB),./labs/$(LAB)/...,./...)

.PHONY: help tools up down ps logs test it lint fmt bench load diagrams

help: ## List targets
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  %-8s %s\n", $$1, $$2}'

tools: ## Print versions of the required tools
	@go version; uv --version; docker --version; $(COMPOSE) version; gh --version | head -1; golangci-lint --version; k6 version | head -1

up: ## Start infra (PROFILES=core by default; PROFILES=all for everything)
	$(COMPOSE) $(PROFILE_FLAGS) up -d --wait

down: ## Stop all infra and delete its data
	$(COMPOSE) --profile '*' down -v --remove-orphans

ps: ## Show running infra
	$(COMPOSE) --profile '*' ps

logs: ## Tail infra logs
	$(COMPOSE) --profile '*' logs -f --tail=100

test: ## Unit tests (fast, no Docker)
	go test -short -race -count=1 $(PKGS)

it: ## Integration tests (testcontainers, or `make up` infra)
	go test -tags integration -race -count=1 $(PKGS)

lint: ## golangci-lint
	golangci-lint run ./...

fmt: ## Format Go code
	golangci-lint fmt ./...

bench: ## Go benchmarks (LAB=... to pick one lab)
	go test -run '^$$' -bench . -benchmem -count=1 $(PKGS)

load: ## k6 load test for one lab: make load LAB=01-airline-checkin
	@test -n "$(LAB)" || { echo "usage: make load LAB=<lab-folder>"; exit 1; }
	k6 run labs/$(LAB)/load/load.js

diagrams: ## Render every ```mermaid block in *.md to diagrams/*.svg
	./scripts/render-diagrams.sh
