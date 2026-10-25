#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

COMPOSE_FILE="${ROOT_DIR}/lab/compose/docker-compose.yml"
COMPOSE=(docker compose -f "$COMPOSE_FILE")
TARGET_SERVICE="target"

log_info "=== Demostración de Monitoreo de Integridad de Archivos (AIDE FIM) ==="

# Asegurar baseline AIDE inicializado
if ! "${COMPOSE[@]}" exec -T "$TARGET_SERVICE" test -f /var/lib/aide/aide.db; then
    log_info "Base AIDE no inicializada. Ejecutando 08-aide-fim.sh --apply..."
    bash "${SCRIPT_DIR}/08-aide-fim.sh" --apply
fi

# Backup previo de seguridad dentro del contenedor
"${COMPOSE[@]}" exec -T "$TARGET_SERVICE" cp /etc/passwd /tmp/passwd.backup

cleanup() {
    log_info "Restaurando estado original de archivos en ${TARGET_SERVICE}..."
    "${COMPOSE[@]}" exec -T "$TARGET_SERVICE" cp /tmp/passwd.backup /etc/passwd || true
    "${COMPOSE[@]}" exec -T "$TARGET_SERVICE" rm -f /tmp/passwd.backup /etc/cron.d/malicious_cron || true
}
trap cleanup EXIT

log_info "1. Simulando manipulación no autorizada de cuentas (MITRE T1078/T1098)..."
"${COMPOSE[@]}" exec -T "$TARGET_SERVICE" bash -c 'echo "backdoor_hacker:x:0:0::/root:/bin/bash" >> /etc/passwd'

log_info "2. Simulando persistencia maliciosa mediante Cron (MITRE T1053.003)..."
"${COMPOSE[@]}" exec -T "$TARGET_SERVICE" bash -c 'echo "* * * * * root /bin/true" > /etc/cron.d/malicious_cron'

log_info "3. Ejecutando auditoría de integridad criptográfica (aide --check)..."
AIDE_OUTPUT="$("${COMPOSE[@]}" exec -T "$TARGET_SERVICE" aide --config /etc/aide/aide.conf --check 2>&1 || true)"

printf '%s\n' "$AIDE_OUTPUT"

echo ""
log_info "Verificación de detecciones de integridad:"
if grep -q "/etc/passwd" <<< "$AIDE_OUTPUT"; then
    log_ok "Modificación en /etc/passwd detectada con éxito (hash SHA256 / tamaño alterado)"
else
    die "Fallo: AIDE no detectó la modificación en /etc/passwd"
fi

if grep -q "malicious_cron" <<< "$AIDE_OUTPUT" || grep -q "/etc/cron.d" <<< "$AIDE_OUTPUT"; then
    log_ok "Inyección de tarea cron detectada con éxito"
else
    log_warn "Aviso: Entrada de cron no listada explícitamente en el reporte"
fi

log_ok "Demostración de integridad AIDE FIM completada con éxito."
