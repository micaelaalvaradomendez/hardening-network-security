#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=SCRIPTDIR/../common/lab-net.sh
source /usr/local/lib/lab-net.sh

lab_net_setup

# Fase A: sin filtrado. Se parte de un ruleset vacío para que el estado sea explícito.
nft flush ruleset
echo "[fw] ip_forward=$(sysctl -n net.ipv4.ip_forward) · ruleset vacío (forwarding abierto)"

exec sleep infinity
