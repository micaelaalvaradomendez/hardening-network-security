#!/usr/bin/env bash
# Verifica los componentes de detección y monitoreo de integridad (Fase H).
# Ejecutar con el laboratorio levantado y los servicios de IDS/FIM aplicados.
set -euo pipefail

COMPOSE_FILE="$(cd "$(dirname "$0")/.." && pwd)/lab/compose/docker-compose.yml"
FAILS=0

dc_exec() { docker compose -f "$COMPOSE_FILE" exec -T "$@"; }

check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "[PASS] ${desc}"
    else
        echo "[FAIL] ${desc}"
        FAILS=$((FAILS + 1))
    fi
}

echo "== Estado de los servicios de detección (Fase H) =="
check "Suricata está en ejecución en fw"               dc_exec fw pgrep -f suricata
check "Archivo de reglas lab-detection.rules montado" dc_exec fw test -s /etc/suricata/rules/lab-detection.rules
check "Configuración suricata.yaml montada"            dc_exec fw test -s /etc/suricata/suricata.yaml
check "Configuración aide.conf presente en target"    dc_exec target test -s /etc/aide/aide.conf
check "Base de datos AIDE inicializada en target"     dc_exec target test -s /var/lib/aide/aide.db

echo "== Verificación de detección de escaneos (Suricata IDS) =="
# Limpiar log antes de la prueba
dc_exec fw truncate -s 0 /var/log/suricata/fast.log

# Disparar escaneo Null
dc_exec attacker nmap -sN -Pn -p 80 10.66.10.10 >/dev/null 2>&1 || true
sleep 1
check "Alerta generada para TCP NULL scan (SID 1000001)" \
    bash -c "docker compose -f ${COMPOSE_FILE} exec -T fw grep -q '\[1:1000001:' /var/log/suricata/fast.log"

# Disparar escaneo Xmas
dc_exec attacker nmap -sX -Pn -p 80 10.66.10.10 >/dev/null 2>&1 || true
sleep 1
check "Alerta generada para TCP Xmas scan (SID 1000002)" \
    bash -c "docker compose -f ${COMPOSE_FILE} exec -T fw grep -q '\[1:1000002:' /var/log/suricata/fast.log"

# Disparar escaneo FIN
dc_exec attacker nmap -sF -Pn -p 80 10.66.10.10 >/dev/null 2>&1 || true
sleep 1
check "Alerta generada para TCP FIN scan (SID 1000003)" \
    bash -c "docker compose -f ${COMPOSE_FILE} exec -T fw grep -q '\[1:1000003:' /var/log/suricata/fast.log"

echo "== Verificación de integridad de archivos (AIDE FIM) =="
check "AIDE valida integridad sin alteraciones"       dc_exec target aide --config /etc/aide/aide.conf --check

echo
if [[ "$FAILS" -gt 0 ]]; then
    echo "${FAILS} verificación(es) de detección fallaron."
    exit 1
fi
echo "Detección IDS y Monitoreo FIM OK."
