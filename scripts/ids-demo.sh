#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

COMPOSE_FILE="${ROOT_DIR}/lab/compose/docker-compose.yml"
COMPOSE=(docker compose -f "$COMPOSE_FILE")
FW_SERVICE="fw"
ATTACKER_SERVICE="attacker"
TARGET_IP="10.66.10.10"

log_info "=== Demostración de Detección de Intrusiones (Suricata IDS) ==="

# Asegurar que Suricata esté corriendo
if ! "${COMPOSE[@]}" exec -T "$FW_SERVICE" pgrep -f suricata >/dev/null 2>&1; then
    log_info "Suricata no está corriendo. Iniciando con 07-suricata-ids.sh --apply..."
    bash "${SCRIPT_DIR}/07-suricata-ids.sh" --apply
fi

# Limpiar fast.log para aislar las alertas de la prueba actual
"${COMPOSE[@]}" exec -T "$FW_SERVICE" truncate -s 0 /var/log/suricata/fast.log || true

log_info "1. Ejecutando escaneo sigiloso TCP NULL Scan desde ${ATTACKER_SERVICE} (MITRE T1046)..."
"${COMPOSE[@]}" exec -T "$ATTACKER_SERVICE" nmap -sN -Pn -p 80,22 "$TARGET_IP" >/dev/null 2>&1 || true

log_info "2. Ejecutando escaneo sigiloso TCP Xmas Scan desde ${ATTACKER_SERVICE} (MITRE T1046)..."
"${COMPOSE[@]}" exec -T "$ATTACKER_SERVICE" nmap -sX -Pn -p 80,22 "$TARGET_IP" >/dev/null 2>&1 || true

log_info "3. Ejecutando escaneo sigiloso TCP FIN Scan desde ${ATTACKER_SERVICE} (MITRE T1046)..."
"${COMPOSE[@]}" exec -T "$ATTACKER_SERVICE" nmap -sF -Pn -p 80,22 "$TARGET_IP" >/dev/null 2>&1 || true

log_info "4. Simulando ráfaga de intentos de conexión SSH repetidos (MITRE T1110)..."
for _ in {1..7}; do
    "${COMPOSE[@]}" exec -T "$ATTACKER_SERVICE" timeout 1 bash -c "nc -z -w 1 ${TARGET_IP} 22" >/dev/null 2>&1 || true
done

sleep 2

log_info "=== Alertas registradas en /var/log/suricata/fast.log en el Firewall ==="
ALERT_LOG="$("${COMPOSE[@]}" exec -T "$FW_SERVICE" cat /var/log/suricata/fast.log || true)"

if [[ -z "$ALERT_LOG" ]]; then
    die "No se registraron alertas en el IDS. Verifique la captura en ${FW_SERVICE}."
fi

printf '%s\n' "$ALERT_LOG"

# Validación de cobertura de reglas
echo ""
log_info "Verificación de firmas detectadas:"
for sid in 1000001 1000002 1000003 1000004; do
    if grep -q "\[1:${sid}:" <<< "$ALERT_LOG"; then
        log_ok "Regla SID ${sid} disparada con éxito"
    else
        log_warn "Regla SID ${sid} no encontrada en el log"
    fi
done

log_ok "Demostración de detección de IDS Suricata completada con éxito."
