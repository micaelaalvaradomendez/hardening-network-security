#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root() { :; }
parse_args "$@"

FW_SERVICE="fw"
COMPOSE_FILE="${ROOT_DIR}/lab/compose/docker-compose.yml"
COMPOSE=(docker compose -f "$COMPOSE_FILE")
SURICATA_CONF="${ROOT_DIR}/firewall/suricata/suricata.yaml"
RULES_FILE="${ROOT_DIR}/firewall/suricata/rules/lab-detection.rules"

if [[ ! -f "$SURICATA_CONF" ]]; then
    die "No se encuentra ${SURICATA_CONF}"
fi
if [[ ! -f "$RULES_FILE" ]]; then
    die "No se encuentra ${RULES_FILE}"
fi

# --check: verificar archivos de configuración y reglas de Suricata.
if ! is_apply; then
    log_info "Modo check: verificando configuración y reglas de Suricata"
    [[ -s "$SURICATA_CONF" ]] && log_ok "suricata.yaml presente"
    [[ -s "$RULES_FILE" ]] && log_ok "lab-detection.rules presente"

    FW_ID="$("${COMPOSE[@]}" ps -q "$FW_SERVICE" 2>/dev/null || true)"
    if [[ -n "$FW_ID" ]]; then
        log_info "Verificando sintaxis de Suricata dentro de ${FW_SERVICE}"
        if "${COMPOSE[@]}" exec -T "$FW_SERVICE" suricata -T -c /etc/suricata/suricata.yaml >/dev/null 2>&1; then
            log_ok "Sintaxis de configuración y reglas de Suricata válida"
        else
            log_warn "Error en la sintaxis de Suricata"
        fi
    fi
    summary
    exit 0
fi

# --apply: iniciar el motor IDS Suricata en el contenedor fw.
FW_ID="$("${COMPOSE[@]}" ps -q "$FW_SERVICE")"
if [[ -z "$FW_ID" ]]; then
    die "El servicio ${FW_SERVICE} no está levantado. Ejecutá make lab-up primero."
fi

log_info "Validando configuración de Suricata en ${FW_SERVICE}"
"${COMPOSE[@]}" exec -T "$FW_SERVICE" suricata -T -c /etc/suricata/suricata.yaml

log_info "Iniciando Suricata en modo IDS sobre wan en ${FW_SERVICE}"
# Si ya está corriendo, detenerlo limpiamente
if "${COMPOSE[@]}" exec -T "$FW_SERVICE" pgrep -f suricata >/dev/null 2>&1; then
    log_info "Reiniciando proceso Suricata existente"
    "${COMPOSE[@]}" exec -T "$FW_SERVICE" pkill -f suricata || true
    sleep 1
fi
"${COMPOSE[@]}" exec -T "$FW_SERVICE" rm -f /var/run/suricata.pid /run/suricata.pid

# Crear directorio de logs si no existiera
"${COMPOSE[@]}" exec -T "$FW_SERVICE" mkdir -p /var/log/suricata

# Ejecutar Suricata como demonio inspeccionando la interfaz wan
"${COMPOSE[@]}" exec -T "$FW_SERVICE" suricata -D -c /etc/suricata/suricata.yaml -i wan

sleep 2
if "${COMPOSE[@]}" exec -T "$FW_SERVICE" pgrep -f suricata >/dev/null 2>&1; then
    log_ok "Suricata IDS en ejecución y monitoreando la interfaz wan"
else
    die "Suricata falló al iniciar en ${FW_SERVICE}."
fi
