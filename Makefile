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
.PHONY: help keys lab-up lab-down baseline exploit-demo vm-up vm-down vm-baseline vm-check vm-harden harden audit test test-lab test-fw report lint diagram pcap-demo fail2ban-demo

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
	@bash ./scripts/baseline.sh

exploit-demo: ## Demostraciones acotadas: Hydra SSH y FTP anónimo
	@bash ./scripts/exploit-demo.sh

vm-up: ## Crea/levanta Debian 13 para hardening (Vagrant + libvirt)
	cd lab/vm && vagrant up --provider=libvirt

vm-down: ## Apaga la VM de hardening
	cd lab/vm && vagrant halt

vm-baseline: ## Captura baseline de la VM antes del hardening
	@bash ./scripts/vm-baseline.sh

vm-check: ## Audita controles de Fase C sin modificar la VM
	@bash ./scripts/vm-hardening.sh --check

vm-harden: ## Aplica controles de Fase C dentro de la VM
	@bash ./scripts/vm-hardening.sh --apply

harden: ## Aplica hardening de red (Fase D): nftables en fw + fail2ban en target
	@bash ./scripts/03-firewall-nftables.sh --apply
	@bash ./scripts/06-fail2ban.sh --apply

audit: ## Auditoría posterior al hardening -> evidencias/despues/<run-id>/
	@bash ./scripts/audit-post.sh

report: ## Genera la tabla comparativa antes/después -> evidencias/reporte.md
	@bash ./scripts/report.sh

test: ## Corre los tests unitarios (bats)
	$(BATS) tests

test-lab: ## Verifica la topología del laboratorio levantado (estado antes de filtrado)
	@./tests/test-topology.sh

test-fw: ## Verifica el filtrado de red endurecido (Fase D)
	@./tests/test-firewall.sh

pcap-demo: ## Captura pcap demostrando reject vs drop -> evidencias/despues/reject-vs-drop.pcap
	@./scripts/pcap-demo.sh

fail2ban-demo: ## Demostración de fail2ban: fuerza bruta -> IP baneada en nftables
	@./scripts/fail2ban-demo.sh

lint: ## Analiza todos los scripts con shellcheck
	$(SHELLCHECK) -x $(SH_FILES)

diagram: ## Renderiza los diagramas PlantUML a SVG y PNG
	$(PLANTUML) -tsvg topologia-laboratorio.puml
	$(PLANTUML) -tpng topologia-laboratorio.puml
