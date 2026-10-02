# Laboratorio de Hardening Linux & Seguridad de Redes
# Las herramientas de calidad (shellcheck, bats) corren en contenedores:
# no hace falta instalarlas localmente y CI usa exactamente lo mismo.

SHELL        := /bin/bash
COMPOSE_FILE := lab/compose/docker-compose.yml
COMPOSE      := docker compose -f $(COMPOSE_FILE)
SH_FILES     := $(shell find scripts lab tests -type f -name '*.sh')
SHELLCHECK   := docker run --rm -v "$(CURDIR):/mnt" -w /mnt koalaman/shellcheck:stable
BATS         := docker run --rm -v "$(CURDIR):/code" -w /code bats/bats:latest
PLANTUML     := docker run --rm -u "$(shell id -u):$(shell id -g)" -v "$(CURDIR)/diagramas:/data" -w /data plantuml/plantuml:latest

.DEFAULT_GOAL := help
.PHONY: help keys lab-up lab-down baseline harden audit test test-lab report lint diagram

help: ## Lista los targets disponibles
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

keys: ## Genera las claves SSH del laboratorio (idempotente)
	@./lab/gen-keys.sh

lab-up: keys ## Levanta el laboratorio de red (Docker Compose)
	@test -f $(COMPOSE_FILE) || { echo "Pendiente: Fase A (topología)"; exit 1; }
	$(COMPOSE) up -d --build

lab-down: ## Baja el laboratorio y elimina sus redes
	@test -f $(COMPOSE_FILE) || { echo "Pendiente: Fase A (topología)"; exit 1; }
	$(COMPOSE) down --remove-orphans

baseline: ## Auditoría previa al hardening -> evidencias/antes/
	@echo "Pendiente: Fase B (target vulnerable y baseline)"; exit 1

harden: ## Aplica los scripts de bastionado
	@echo "Pendiente: Fases C y D (hardening de SO y red)"; exit 1

audit: ## Auditoría posterior al hardening -> evidencias/despues/
	@echo "Pendiente: Fase E (verificación)"; exit 1

report: ## Genera la tabla comparativa antes/después
	@echo "Pendiente: Fase E (verificación)"; exit 1

test: ## Corre los tests unitarios (bats)
	$(BATS) tests

test-lab: ## Verifica la topología del laboratorio levantado
	@./tests/test-topology.sh

lint: ## Analiza todos los scripts con shellcheck
	$(SHELLCHECK) -x $(SH_FILES)

diagram: ## Renderiza los diagramas PlantUML a SVG y PNG
	$(PLANTUML) -tsvg topologia-laboratorio.puml
	$(PLANTUML) -tpng topologia-laboratorio.puml
