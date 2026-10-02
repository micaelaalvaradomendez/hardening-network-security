#!/usr/bin/env bash
# Verifica la topología del laboratorio levantado (make lab-up):
# ruteo entre zonas a través de fw, servicios del target y ausencia de caminos alternativos.
set -euo pipefail

COMPOSE_FILE="$(cd "$(dirname "$0")/.." && pwd)/lab/compose/docker-compose.yml"
FAILS=0

run() { docker compose -f "$COMPOSE_FILE" exec -T "$@"; }

check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "[PASS] ${desc}"
    else
        echo "[FAIL] ${desc}"
        FAILS=$((FAILS + 1))
    fi
}

hops_via_fw() {
    # El primer salto hacia la otra zona debe ser la interfaz de fw en la zona de origen.
    local node="$1" dest="$2" gw="$3"
    run "$node" traceroute -n -w1 -q1 -m2 "$dest" | awk 'NR==2 {print $2}' | grep -qx "$gw"
}

no_other_interfaces() {
    # El nodo solo debe tener la interfaz de su zona (más loopback).
    local node="$1" count
    count="$(run "$node" ip -brief -4 address show | grep -vc '^lo')"
    [[ "$count" -eq 1 ]]
}

echo "== Ruteo entre zonas"
check "attacker -> target (wan -> dmz)"          run attacker ping -c1 -W2 10.66.10.10
check "attacker -> target pasa por fw"           hops_via_fw attacker 10.66.10.10 10.66.0.2
check "admin -> target (mgmt -> dmz)"            run admin ping -c1 -W2 10.66.10.10
check "target -> admin (dmz -> mgmt)"            run target ping -c1 -W2 10.66.20.10

echo "== Servicios del target"
check "HTTP 80 accesible desde wan"              run attacker curl -fsS --max-time 3 -o /dev/null http://10.66.10.10/
check "SSH con clave desde admin (operador)"     run admin ssh -o BatchMode=yes -o ConnectTimeout=3 target true

echo "== Aislamiento"
check "attacker tiene una sola interfaz"         no_other_interfaces attacker
check "target tiene una sola interfaz"           no_other_interfaces target
check "admin tiene una sola interfaz"            no_other_interfaces admin
# shellcheck disable=SC2016  # se expande dentro del contenedor, no acá
check "fw tiene forwarding activo"               run fw sh -c '[ "$(sysctl -n net.ipv4.ip_forward)" = 1 ]'

# Prueba de que no existe camino alternativo: con la pata dmz de fw caída, wan no alcanza dmz.
# (Pausar el contenedor no sirve: el forwarding lo hace el kernel, no un proceso.)
run fw ip link set dmz down
trap 'run fw ip link set dmz up || true' EXIT
check "sin fw no hay camino wan -> dmz"          bash -c "! docker compose -f '$COMPOSE_FILE' exec -T attacker ping -c1 -W2 10.66.10.10"
run fw ip link set dmz up
trap - EXIT
check "fw restaurado: wan -> dmz otra vez OK"    run attacker ping -c1 -W3 10.66.10.10

echo
if [[ "$FAILS" -gt 0 ]]; then
    echo "${FAILS} verificación(es) fallaron."
    exit 1
fi
echo "Topología OK."
