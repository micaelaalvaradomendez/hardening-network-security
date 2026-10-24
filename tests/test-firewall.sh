#!/usr/bin/env bash
# Verifica el filtrado de red endurecido (Fase D) tras `make harden`.
# Ejecutar con el laboratorio levantado y las reglas nftables cargadas.
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

echo "== Filtrado WAN → DMZ (attacker: 10.66.0.10 → target: 10.66.10.10)"
check "HTTP 80 permitido desde WAN"       dc_exec attacker curl -fsS --max-time 3 -o /dev/null http://10.66.10.10/
check "SSH 22 bloqueado desde WAN"        bash -c "! docker compose -f ${COMPOSE_FILE} exec -T attacker curl -fsS --max-time 3 -o /dev/null http://10.66.10.10:22/"
check "FTP 21 bloqueado desde WAN"        bash -c "! docker compose -f ${COMPOSE_FILE} exec -T attacker nc -z -w2 10.66.10.10 21"
check "Nmap NULL scan detectado/bloqueado" bash -c "docker compose -f ${COMPOSE_FILE} exec -T attacker nmap -n -Pn -sN -p 22,80 10.66.10.10 | grep -qiE 'filtered'"
check "Nmap XMAS scan detectado/bloqueado" bash -c "docker compose -f ${COMPOSE_FILE} exec -T attacker nmap -n -Pn -sX -p 22,80 10.66.10.10 | grep -qiE 'filtered'"

echo "== Filtrado MGMT → DMZ (admin: 10.66.20.10 → target: 10.66.10.10)"
check "SSH 22 permitido desde MGMT"       dc_exec admin ssh -o BatchMode=yes -o ConnectTimeout=3 target true
check "HTTP 80 bloqueado desde MGMT (solo SSH)" bash -c "! docker compose -f ${COMPOSE_FILE} exec -T admin curl -fsS --max-time 3 -o /dev/null http://10.66.10.10/"

echo "== Filtrado DMZ → MGMT (target → admin: 10.66.20.10)"
check "DMZ no alcanza MGMT"               bash -c "! docker compose -f ${COMPOSE_FILE} exec -T target ping -c1 -W2 10.66.20.10"

echo "== Filtrado WAN → MGMT (attacker → admin: 10.66.20.10)"
check "WAN no alcanza MGMT"               bash -c "! docker compose -f ${COMPOSE_FILE} exec -T attacker ping -c1 -W2 10.66.20.10"

echo "== Reglas del firewall en fw"
check "fw tiene cadena hns_filter"        dc_exec fw nft list table inet hns_filter
check "fw tiene anti-scan NULL"           bash -c "docker compose -f ${COMPOSE_FILE} exec -T fw nft list chain inet hns_filter scan_filter | grep -qi 'scan-null'"
check "fw tiene anti-scan XMAS"           bash -c "docker compose -f ${COMPOSE_FILE} exec -T fw nft list chain inet hns_filter scan_filter | grep -qi 'scan-xmas'"
check "fw tiene anti-scan SYN+FIN"        bash -c "docker compose -f ${COMPOSE_FILE} exec -T fw nft list chain inet hns_filter scan_filter | grep -qi 'synfin'"

echo
if [[ "$FAILS" -gt 0 ]]; then
    echo "${FAILS} verificación(es) de firewall fallaron."
    exit 1
fi
echo "Filtrado de red OK."
