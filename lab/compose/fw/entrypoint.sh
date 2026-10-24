#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=SCRIPTDIR/../common/lab-net.sh
source /usr/local/lib/lab-net.sh

lab_net_setup

# Fase A: sin filtrado. El contenedor arranca con el ruleset vacío (forwarding
# abierto) para que los tests de topología (test-lab) validen el estado "antes".
# El filtrado endurecido se carga con `make harden` (03-firewall-nftables.sh).
nft flush ruleset
echo "[fw] ip_forward=$(sysctl -n net.ipv4.ip_forward) · ruleset vacío (forwarding abierto, antes Fase D)"

exec sleep infinity
