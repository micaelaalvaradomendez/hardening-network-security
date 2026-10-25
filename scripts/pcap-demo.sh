#!/usr/bin/env bash
# Genera una captura pcap que demuestra la diferencia entre reject y drop en fw.
# WAN (attacker -> target:22) se descarta silenciosamente (drop).
# MGMT (admin -> target:80) se rechaza con ICMP admin-prohibited (reject).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/lab/compose/docker-compose.yml"
COMPOSE=(docker compose -f "$COMPOSE_FILE")
OUTPUT_PCAP="${1:-${ROOT_DIR}/evidencias/despues/reject-vs-drop.pcap}"
OUTPUT_TXT="${OUTPUT_PCAP%.pcap}.txt"

mkdir -p "$(dirname "$OUTPUT_PCAP")"

echo "== Iniciando captura tcpdump en fw..."
"${COMPOSE[@]}" exec -T fw rm -f /tmp/demo.pcap
"${COMPOSE[@]}" exec -d fw tcpdump -U -i any -nn -w /tmp/demo.pcap "tcp port 22 or tcp port 80 or icmp"
sleep 1

echo "== [1/2] Probando DROP desde WAN (attacker: 10.66.0.10 -> target: 10.66.10.10:22)..."
"${COMPOSE[@]}" exec -T attacker nc -z -w 1 10.66.10.10 22 >/dev/null 2>&1 || true

echo "== [2/2] Probando REJECT desde MGMT (admin: 10.66.20.10 -> target: 10.66.10.10:80)..."
"${COMPOSE[@]}" exec -T admin curl -fsS -m 1 http://10.66.10.10/ >/dev/null 2>&1 || true

sleep 1
"${COMPOSE[@]}" exec -T fw pkill -f tcpdump || true
sleep 1

# Copiar el pcap del contenedor al host
docker compose -f "$COMPOSE_FILE" cp fw:/tmp/demo.pcap "$OUTPUT_PCAP"
"${COMPOSE[@]}" exec -T fw rm -f /tmp/demo.pcap

echo "== Captura guardada en ${OUTPUT_PCAP}"
echo "== Paquetes capturados:"
if command -v tcpdump >/dev/null 2>&1; then
    tcpdump -r "$OUTPUT_PCAP" -nn | tee "$OUTPUT_TXT"
else
    "${COMPOSE[@]}" exec -T fw tcpdump -r "$OUTPUT_PCAP" -nn | tee "$OUTPUT_TXT"
fi

