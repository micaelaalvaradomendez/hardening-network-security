#!/usr/bin/env bash
# Sanity check automatizado de directivas y controles CIS (Fase E).
# Verifica controles de red en el laboratorio y controles de SO en la VM / evidencias.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/lab/compose/docker-compose.yml"
FAILS=0

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
echo "VERIFICACIÓN DE DIRECTIVAS CIS IMPLEMENTADAS (FASE E)"
echo "=========================================================="

echo
echo "== 1. Controles de Filtrado de Red y Perímetro (CIS / Principio Mínimo Privilegio)"
check "nftables: Política DROP por defecto en input (fw)" \
    bash -c "docker compose -f ${COMPOSE_FILE} exec -T fw nft list chain inet hns_filter input | grep -q 'policy drop'"

check "nftables: Política DROP por defecto en forward (fw)" \
    bash -c "docker compose -f ${COMPOSE_FILE} exec -T fw nft list chain inet hns_filter forward | grep -q 'policy drop'"

check "nftables: Stateful conntrack (established,related accept) activo" \
    bash -c "docker compose -f ${COMPOSE_FILE} exec -T fw nft list chain inet hns_filter forward | grep -q 'ct state established,related accept'"

check "nftables: Mitigación de escaneos TCP anómalos (NULL/XMAS/SYN+FIN)" \
    bash -c "docker compose -f ${COMPOSE_FILE} exec -T fw nft list chain inet hns_filter scan_filter | grep -q 'scan-null' && docker compose -f ${COMPOSE_FILE} exec -T fw nft list chain inet hns_filter scan_filter | grep -q 'scan-xmas'"

check "Kernel fw: Reenvío IPv4 habilitado con ruteo controlado" \
    bash -c "docker compose -f ${COMPOSE_FILE} exec -T fw sysctl -n net.ipv4.ip_forward | grep -q '^1$'"

echo
echo "== 2. Controles de Host y Protección contra Fuerza Bruta (DMZ target)"
check "fail2ban activo con jail sshd en target" \
    bash -c "docker compose -f ${COMPOSE_FILE} exec -T target fail2ban-client status sshd | grep -q 'Status for the jail: sshd'"

check "Permisos estrictos en claves SSH autorizadas (600 / 700)" \
    bash -c "docker compose -f ${COMPOSE_FILE} exec -T target stat -c '%a' /home/operador/.ssh/authorized_keys | grep -q '^600$'"

echo
echo "== 3. Controles CIS de Hardening de SO (Debian 13 VM)"
VM_DESPUES_DIR="$(find "${ROOT_DIR}/evidencias/vm/despues" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"
if [[ -n "$VM_DESPUES_DIR" && -f "${VM_DESPUES_DIR}/sshd-effective-config.txt" ]]; then
    echo "Verificando evidencias post-hardening de la VM en ${VM_DESPUES_DIR}:"
    check "CIS SSH: PermitRootLogin deshabilitado (no)" \
        grep -qiE '^permitrootlogin no[[:space:]]*' "${VM_DESPUES_DIR}/sshd-effective-config.txt"

    check "CIS SSH: PasswordAuthentication deshabilitada (no)" \
        grep -qiE '^passwordauthentication no[[:space:]]*' "${VM_DESPUES_DIR}/sshd-effective-config.txt"

    check "CIS SSH: MaxAuthTries restringido (<= 4)" \
        grep -qiE '^maxauthtries [1-4][[:space:]]*' "${VM_DESPUES_DIR}/sshd-effective-config.txt"

    check "CIS SSH: X11Forwarding deshabilitado (no)" \
        grep -qiE '^x11forwarding no[[:space:]]*' "${VM_DESPUES_DIR}/sshd-effective-config.txt"

    check "CIS Lynis: Índice de hardening verificado >= 68" \
        grep -qiE 'Hardening index *: *([6-9][0-9]|100)' "${VM_DESPUES_DIR}/lynis.txt"

    check "CIS auditd: Inmutabilidad de reglas configurada (-e 2)" \
        grep -q -- '-e 2' "${ROOT_DIR}/scripts/04-auditd-rules.sh"
else
    echo "[SKIP] No se encontró directorio de evidencias de VM post-hardening."
fi

echo
if [[ "$FAILS" -gt 0 ]]; then
    echo "ERROR: ${FAILS} verificación(es) CIS fallaron."
    exit 1
fi
echo "Todas las verificaciones de controles CIS pasaron exitosamente."
