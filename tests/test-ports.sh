#!/usr/bin/env bash
# Verifica el filtrado de puertos (whitelist) y disponibilidad de servicios legítimos.
# Fase E — Verificación y diff.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/lab/compose/docker-compose.yml"
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

echo "=========================================================="
echo "BATERÍA DE PRUEBAS DE PUERTOS Y DISPONIBILIDAD (FASE E)"
echo "=========================================================="

echo
echo "== 1. Whitelist WAN (attacker: 10.66.0.10 -> target: 10.66.10.10)"
check "Puerto 80/TCP abierto y responde HTTP 200" \
    dc_exec attacker curl -fsS --max-time 3 -o /dev/null http://10.66.10.10/

check "Puerto 22/TCP cerrado/filtrado hacia WAN" \
    bash -c "! docker compose -f ${COMPOSE_FILE} exec -T attacker nc -z -w 2 10.66.10.10 22"

check "Puerto 21/TCP cerrado/filtrado hacia WAN" \
    bash -c "! docker compose -f ${COMPOSE_FILE} exec -T attacker nc -z -w 2 10.66.10.10 21"

check "Nmap confirma puerto 80 open y puertos 21,22 filtered desde WAN" \
    bash -c "docker compose -f ${COMPOSE_FILE} exec -T attacker nmap -n -Pn -sS -p 21,22,80 10.66.10.10 | grep -q '80/tcp open' && docker compose -f ${COMPOSE_FILE} exec -T attacker nmap -n -Pn -sS -p 21,22,80 10.66.10.10 | grep -q '22/tcp filtered' && docker compose -f ${COMPOSE_FILE} exec -T attacker nmap -n -Pn -sS -p 21,22,80 10.66.10.10 | grep -q '21/tcp filtered'"

echo
echo "== 2. Whitelist MGMT (admin: 10.66.20.10 -> target: 10.66.10.10)"
check "Puerto 22/TCP disponible para administración (SSH con clave)" \
    dc_exec admin ssh -o BatchMode=yes -o ConnectTimeout=3 target true

check "Puerto 80/TCP bloqueado desde MGMT (principio de mínimo privilegio)" \
    bash -c "! docker compose -f ${COMPOSE_FILE} exec -T admin curl -fsS --max-time 2 -o /dev/null http://10.66.10.10/"

check "Puerto 21/TCP bloqueado desde MGMT" \
    bash -c "! docker compose -f ${COMPOSE_FILE} exec -T admin nc -z -w 2 10.66.10.10 21"

echo
echo "== 3. Disponibilidad y sanidad del servicio legítimo (HTTP)"
check "Servicio HTTP entrega contenido válido" \
    bash -c "docker compose -f ${COMPOSE_FILE} exec -T attacker curl -fsS http://10.66.10.10/ | grep -qiE 'html|apache|index'"

echo
if [[ "$FAILS" -gt 0 ]]; then
    echo "ERROR: ${FAILS} prueba(s) de puertos fallaron."
    exit 1
fi
echo "Todas las pruebas de puertos y disponibilidad pasaron exitosamente."
