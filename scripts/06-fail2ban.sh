#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# Estos scripts solo orquestan comandos de Docker (que corren como root dentro
# de los contenedores); no modifican el host directamente, por lo que no se
# requiere root en el host.
require_root() { :; }
parse_args "$@"

TARGET_SERVICE="target"
COMPOSE_FILE="${ROOT_DIR}/lab/compose/docker-compose.yml"
COMPOSE=(docker compose -f "$COMPOSE_FILE")
JAIL_LOCAL="${ROOT_DIR}/firewall/fail2ban/jail.local"
JAIL_D="${ROOT_DIR}/firewall/fail2ban/jail.d"

if [[ ! -f "$JAIL_LOCAL" ]]; then
    die "No se encuentra ${JAIL_LOCAL}"
fi

# --check: solo verificar que los archivos de configuración existan.
if ! is_apply; then
    log_info "Modo check: verificando configuración de fail2ban"
    [[ -f "$JAIL_LOCAL" ]] && log_ok "jail.local presente"
    [[ -d "$JAIL_D" ]] && log_ok "directorio jail.d presente"
    summary
    exit 0
fi

# --apply: instalar configuración en el contenedor target y (re)arrancar fail2ban.
TARGET_ID="$("${COMPOSE[@]}" ps -q "$TARGET_SERVICE")"
if [[ -z "$TARGET_ID" ]]; then
    die "El servicio ${TARGET_SERVICE} no está levantado. Ejecutá make lab-up primero."
fi

log_info "Copiando configuración de fail2ban a ${TARGET_SERVICE}"
"${COMPOSE[@]}" cp "$JAIL_LOCAL" "${TARGET_SERVICE}:/etc/fail2ban/jail.local"
if [[ -d "$JAIL_D" ]]; then
    "${COMPOSE[@]}" exec -T "$TARGET_SERVICE" mkdir -p /etc/fail2ban/jail.d
    for f in "$JAIL_D"/*; do
        [[ -f "$f" ]] || continue
        "${COMPOSE[@]}" cp "$f" "${TARGET_SERVICE}:/etc/fail2ban/jail.d/$(basename "$f")"
    done
fi

log_info "Arrancando / recargando fail2ban en ${TARGET_SERVICE}"
if "${COMPOSE[@]}" exec -T "$TARGET_SERVICE" pgrep -x fail2ban-server >/dev/null 2>&1; then
    "${COMPOSE[@]}" exec -T "$TARGET_SERVICE" fail2ban-client reload >/dev/null 2>&1 || true
else
    "${COMPOSE[@]}" exec -T "$TARGET_SERVICE" fail2ban-client -x start >/dev/null 2>&1 || true
fi

# Esperar a que fail2ban esté listo
for _ in $(seq 1 10); do
    if "${COMPOSE[@]}" exec -T "$TARGET_SERVICE" fail2ban-client status >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

if "${COMPOSE[@]}" exec -T "$TARGET_SERVICE" fail2ban-client status >/dev/null 2>&1; then
    log_ok "fail2ban activo en ${TARGET_SERVICE}"
else
    log_warn "fail2ban no respondió; revisar logs del contenedor target"
fi

summary
