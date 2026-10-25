#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

require_root() { :; }
parse_args "$@"

TARGET_SERVICE="target"
COMPOSE_FILE="${ROOT_DIR}/lab/compose/docker-compose.yml"
COMPOSE=(docker compose -f "$COMPOSE_FILE")
AIDE_CONF="${ROOT_DIR}/lab/compose/target/aide.conf"

if [[ ! -f "$AIDE_CONF" ]]; then
    die "No se encuentra ${AIDE_CONF}"
fi

TARGET_ID="$("${COMPOSE[@]}" ps -q "$TARGET_SERVICE" 2>/dev/null || true)"

# --check: verificar integridad del sistema frente a la base de datos de hashes AIDE.
if ! is_apply; then
    log_info "Modo check: verificando configuración y base AIDE en ${TARGET_SERVICE}"
    [[ -s "$AIDE_CONF" ]] && log_ok "aide.conf presente"

    if [[ -z "$TARGET_ID" ]]; then
        log_warn "Contenedor ${TARGET_SERVICE} no está activo para ejecutar chequeo de integridad"
        summary
        exit 0
    fi

    if ! "${COMPOSE[@]}" exec -T "$TARGET_SERVICE" test -f /var/lib/aide/aide.db; then
        log_warn "Base de datos AIDE no inicializada en ${TARGET_SERVICE}. Ejecutá con --apply primero."
        summary
        exit 0
    fi

    log_info "Ejecutando verificación de integridad (aide --check)"
    if "${COMPOSE[@]}" exec -T "$TARGET_SERVICE" aide --config /etc/aide/aide.conf --check; then
        log_ok "Integridad de archivos preservada: sin alteraciones detectadas"
    else
        log_warn "AIDE detectó cambios o discrepancias en los archivos monitoreados"
    fi
    summary
    exit 0
fi

# --apply: inicializar la base criptográfica de hashes AIDE en target.
if [[ -z "$TARGET_ID" ]]; then
    die "El servicio ${TARGET_SERVICE} no está levantado. Ejecutá make lab-up primero."
fi

log_info "Inicializando base criptográfica de AIDE en ${TARGET_SERVICE}"
"${COMPOSE[@]}" exec -T "$TARGET_SERVICE" mkdir -p /var/lib/aide
"${COMPOSE[@]}" exec -T "$TARGET_SERVICE" aide --config /etc/aide/aide.conf --init
"${COMPOSE[@]}" exec -T "$TARGET_SERVICE" cp /var/lib/aide/aide.db.new /var/lib/aide/aide.db

if "${COMPOSE[@]}" exec -T "$TARGET_SERVICE" test -s /var/lib/aide/aide.db; then
    log_ok "Base criptográfica AIDE generada correctamente en /var/lib/aide/aide.db"
else
    die "Fallo al inicializar la base de datos de AIDE"
fi
