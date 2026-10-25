#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=SCRIPTDIR/../common/lab-net.sh
source /usr/local/lib/lab-net.sh

lab_net_setup

# Renombrar interfaces según la IP asignada (wan, dmz, mgmt) para
# garantizar compatibilidad universal con todas las versiones de Docker (< 28.1).
for iface in $(ip -o -4 addr show | awk '{print $2}' | grep -v '^lo'); do
    # Si la interfaz viene con sub-interfaz (ej. eth0@if15), nos quedamos con el nombre base
    base_iface="${iface%%@*}"
    ip_addr="$(ip -o -4 addr show dev "$base_iface" | awk '{print $4}')"
    case "$ip_addr" in
        10.66.0.2/*) target_name="wan" ;;
        10.66.10.2/*) target_name="dmz" ;;
        10.66.20.2/*) target_name="mgmt" ;;
        *) target_name="" ;;
    esac
    if [[ -n "$target_name" && "$base_iface" != "$target_name" ]]; then
        ip link set dev "$base_iface" down
        ip link set dev "$base_iface" name "$target_name"
        ip link set dev "$target_name" up
    fi
done

# Fase A: sin filtrado. El contenedor arranca con el ruleset vacío (forwarding
# abierto) para que los tests de topología (test-lab) validen el estado "antes".
# El filtrado endurecido se carga con `make harden` (03-firewall-nftables.sh).
nft flush ruleset
echo "[fw] ip_forward=$(sysctl -n net.ipv4.ip_forward) · ruleset vacío (forwarding abierto, antes Fase D)"

exec sleep infinity
