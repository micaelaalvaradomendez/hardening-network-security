#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/lab/compose/docker-compose.yml"
COMPOSE=(docker compose -f "$COMPOSE_FILE")
TARGET_IP="10.66.10.10"
RUN_ID="${BASELINE_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
OUTPUT_DIR="${BASELINE_OUTPUT_DIR:-${ROOT_DIR}/evidencias/antes/${RUN_ID}}"

if [[ ! "$RUN_ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf 'BASELINE_RUN_ID contiene caracteres no permitidos: %s\n' "$RUN_ID" >&2
    exit 2
fi

mkdir -p "$OUTPUT_DIR"
ATTACKER_ID="$("${COMPOSE[@]}" ps -q attacker)"
if [[ -z "$ATTACKER_ID" ]]; then
    printf 'El servicio attacker no está levantado. Ejecutá make lab-up primero.\n' >&2
    exit 1
fi

capture() {
    local name="$1"
    shift
    printf '==> %s\n' "$name"
    if "$@" >"${OUTPUT_DIR}/${name}.txt" 2>&1; then
        printf '    guardado en %s/%s.txt\n' "$OUTPUT_DIR" "$name"
    else
        local status=$?
        printf '    falló (%s); revisar %s/%s.txt\n' "$status" "$OUTPUT_DIR" "$name" >&2
        return "$status"
    fi
}

capture_with_findings() {
    local name="$1"
    shift
    local status=0
    printf '==> %s\n' "$name"
    "$@" >"${OUTPUT_DIR}/${name}.txt" 2>&1 || status=$?
    printf 'exit_code=%s\n' "$status" >"${OUTPUT_DIR}/${name}.status"
    if grep -Fq '(gen) banner:' "${OUTPUT_DIR}/${name}.txt"; then
        printf '    guardado en %s/%s.txt (exit %s; informe con hallazgos)\n' \
            "$OUTPUT_DIR" "$name" "$status"
        return 0
    fi
    printf '    escaneo incompleto (exit %s); revisar %s/%s.txt\n' \
        "$status" "$OUTPUT_DIR" "$name" >&2
    return "${status:-1}"
}

cat >"${OUTPUT_DIR}/run-info.txt" <<EOF
run_id=${RUN_ID}
started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
target=${TARGET_IP}
scanner=attacker (WAN lab network)
scope=TCP ports 21,22,80 only; all scans target the fixed lab IP
EOF

capture ftp-anonymous "${COMPOSE[@]}" exec -T attacker \
    curl --verbose --fail --show-error --list-only \
    --user anonymous:lab@example.invalid "ftp://${TARGET_IP}/"
capture nmap-tcp "${COMPOSE[@]}" exec -T attacker \
    nmap -n -Pn -sS -sV -O --script default,vuln -p 21,22,80 "$TARGET_IP"
capture nmap-null "${COMPOSE[@]}" exec -T attacker \
    nmap -n -Pn -sN -p 21,22,80 "$TARGET_IP"
capture nmap-xmas "${COMPOSE[@]}" exec -T attacker \
    nmap -n -Pn -sX -p 21,22,80 "$TARGET_IP"
capture nmap-fin "${COMPOSE[@]}" exec -T attacker \
    nmap -n -Pn -sF -p 21,22,80 "$TARGET_IP"
capture_with_findings ssh-audit "${COMPOSE[@]}" exec -T attacker \
    ssh-audit --skip-rate-test "$TARGET_IP"
capture nikto docker run --rm --network "container:${ATTACKER_ID}" \
    ghcr.io/sullo/nikto:2.6.1 -host "http://${TARGET_IP}" -nointeractive -nocheck
capture lynis-container "${COMPOSE[@]}" exec -T target lynis audit system --quick --no-colors

printf '\nBaseline guardada en %s\n' "$OUTPUT_DIR"
printf 'Nota: lynis-container.txt describe el contenedor; no es comparable con el índice de la VM de Fase C.\n'