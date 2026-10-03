#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_ID="${BASELINE_RUN_ID:-$(date -u +%Y%m%dT%H%M%SZ)}"
PHASE="${BASELINE_PHASE:-antes}"
[[ "$PHASE" == "antes" || "$PHASE" == "despues" ]] || {
    printf 'BASELINE_PHASE debe ser antes o despues.\n' >&2
    exit 2
}
OUTPUT_DIR="${BASELINE_OUTPUT_DIR:-${ROOT_DIR}/evidencias/vm/${PHASE}/${RUN_ID}}"

if [[ ! "$RUN_ID" =~ ^[A-Za-z0-9._-]+$ ]]; then
    printf 'BASELINE_RUN_ID contiene caracteres no permitidos: %s\n' "$RUN_ID" >&2
    exit 2
fi
command -v vagrant >/dev/null 2>&1 || {
    printf 'Vagrant no está instalado. Instalá Vagrant y el plugin vagrant-libvirt.\n' >&2
    exit 1
}

mkdir -p "$OUTPUT_DIR"
(cd "${ROOT_DIR}/lab/vm" && vagrant status --machine-readable | grep -q ',state,running$') || {
    printf 'La VM no está activa. Ejecutá make vm-up primero.\n' >&2
    exit 1
}

capture() {
    local name="$1" command="$2" status=0
    printf '==> %s\n' "$name"
    (cd "${ROOT_DIR}/lab/vm" && vagrant ssh -c "$command") >"${OUTPUT_DIR}/${name}.txt" 2>&1 || status=$?
    if [[ "$status" -ne 0 ]]; then
        printf 'Falló %s (exit %s); revisar %s/%s.txt\n' "$name" "$status" "$OUTPUT_DIR" "$name" >&2
        return "$status"
    fi
    printf '    guardado en %s/%s.txt\n' "$OUTPUT_DIR" "$name"
}

capture_findings() {
    local name="$1" command="$2" status=0
    printf '==> %s\n' "$name"
    (cd "${ROOT_DIR}/lab/vm" && vagrant ssh -c "$command") >"${OUTPUT_DIR}/${name}.txt" 2>&1 || status=$?
    printf 'exit_code=%s\n' "$status" >"${OUTPUT_DIR}/${name}.status"
    if grep -Fq '(gen) banner:' "${OUTPUT_DIR}/${name}.txt"; then
        printf '    guardado en %s/%s.txt (exit %s; informe con hallazgos)\n' \
            "$OUTPUT_DIR" "$name" "$status"
        return 0
    fi
    printf 'Escaneo incompleto: revisar %s/%s.txt\n' "$OUTPUT_DIR" "$name" >&2
    return 1
}

cat >"${OUTPUT_DIR}/run-info.txt" <<EOF
run_id=${RUN_ID}
started_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)
vm=Debian 13 Trixie via Vagrant/libvirt
phase=${PHASE}
EOF

capture lynis 'sudo lynis audit system --quick --no-colors'
capture_findings ssh-audit 'ssh-audit --skip-rate-test localhost'
capture listening-sockets 'sudo ss -tulpn'
capture sshd-effective-config 'sudo sshd -T'

touch "${OUTPUT_DIR}/baseline.complete"
printf '\nBaseline VM guardada en %s\n' "$OUTPUT_DIR"