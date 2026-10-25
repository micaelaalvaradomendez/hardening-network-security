#!/usr/bin/env bash
# Demostración reproducible de fail2ban (Fase D):
# 1. Verifica conectividad SSH legítima desde admin (MGMT) con su clave autorizada.
# 2. Ejecuta Hydra con contraseñas erróneas para el usuario root desde admin.
# 3. Verifica que fail2ban detecta los fallos (maxretry=3) y banea la IP 10.66.20.10.
# 4. Verifica que la IP está en el set de nftables (addr-set-sshd).
# 5. Comprueba que las conexiones SSH posteriores son rechazadas de inmediato.
# 6. Desbanea la IP y restaura la conectividad del laboratorio.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT_DIR}/lab/compose/docker-compose.yml"
COMPOSE=(docker compose -f "$COMPOSE_FILE")
OUTPUT_FILE="${1:-${ROOT_DIR}/evidencias/despues/fail2ban-demo.txt}"

mkdir -p "$(dirname "$OUTPUT_FILE")"

run_demo() {
    echo "=========================================================="
    echo "DEMOSTRACIÓN DE FAIL2BAN & NFTABLES EN LA DMZ"
    echo "Fecha (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "=========================================================="

    echo
    echo "== 1. Estado inicial: verificación de acceso legítimo desde admin"
    if "${COMPOSE[@]}" exec -T admin ssh -o BatchMode=yes -o ConnectTimeout=3 target true; then
        echo "[OK] Conexión SSH desde admin (10.66.20.10) autorizada con clave ed25519."
    else
        echo "[FAIL] No se pudo conectar vía SSH antes de la prueba."
        return 1
    fi

    echo
    echo "== 2. Estado de fail2ban antes del ataque"
    "${COMPOSE[@]}" exec -T target fail2ban-client status sshd

    echo
    echo "== 3. Lanzando ataque de fuerza bruta SSH con Hydra desde admin"
    "${COMPOSE[@]}" exec -T admin hydra -I -t 1 -w 2 -l root \
        -P /usr/local/share/hns/ban-demo-passwords.txt ssh://10.66.10.10 >/dev/null 2>&1 || true

    # Esperar a que fail2ban procese auth.log y aplique el baneo
    for _ in $(seq 1 10); do
        if "${COMPOSE[@]}" exec -T target fail2ban-client status sshd | grep -q '10.66.20.10'; then
            break
        fi
        sleep 1
    done

    echo
    echo "== 4. Estado de fail2ban tras el ataque"
    "${COMPOSE[@]}" exec -T target fail2ban-client status sshd

    echo
    echo "== 5. Reglas y sets de nftables en target (f2b-table)"
    "${COMPOSE[@]}" exec -T target nft list table inet f2b-table

    echo
    echo "== 6. Verificando bloqueo de SSH desde admin"
    local ssh_test
    ssh_test="$("${COMPOSE[@]}" exec -T admin ssh -o BatchMode=yes -o ConnectTimeout=2 target true 2>&1 || true)"
    if echo "$ssh_test" | grep -qiE 'refused|unreachable'; then
        echo "[OK] Conexión rechazada por nftables a nivel de kernel (bloqueo efectivo)."
    else
        echo "[WARN] La conexión no fue rechazada como se esperaba: $ssh_test"
    fi

    echo
    echo "== 7. Desbaneando IP de admin para restaurar el laboratorio"
    "${COMPOSE[@]}" exec -T target fail2ban-client set sshd unbanip 10.66.20.10 >/dev/null
    sleep 1

    if "${COMPOSE[@]}" exec -T admin ssh -o BatchMode=yes -o ConnectTimeout=3 target true; then
        echo "[OK] Conectividad SSH de admin restaurada exitosamente."
    else
        echo "[FAIL] Error al restaurar conectividad."
        return 1
    fi

    echo
    echo "Demostración de fail2ban completada exitosamente."
}

run_demo | tee "$OUTPUT_FILE"

