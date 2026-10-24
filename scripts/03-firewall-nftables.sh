#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
# Estos scripts solo orquestan comandos de Docker (que corren como root dentro
# de los contenedores); no modifican el host directamente, por lo que no se
# requiere root en el host.
require_root() { :; }
parse_args "$@"

NFT_CONF="${ROOT_DIR}/firewall/nftables.conf"
FW_SERVICE="fw"
COMPOSE_FILE="${ROOT_DIR}/lab/compose/docker-compose.yml"
COMPOSE=(docker compose -f "$COMPOSE_FILE")

if [[ ! -f "$NFT_CONF" ]]; then
    die "No se encuentra ${NFT_CONF}"
fi

# --check: verificar que el archivo de reglas exista (la validación de sintaxis
# con nft -c ocurre dentro del contenedor fw en --apply, que tiene NET_ADMIN).
if ! is_apply; then
    log_info "Modo check: verificando archivo de reglas nftables"
    [[ -s "$NFT_CONF" ]] && log_ok "nftables.conf presente y no vacío"
    summary
    exit 0
fi

# --apply: cargar reglas en el contenedor fw.
FW_ID="$("${COMPOSE[@]}" ps -q "$FW_SERVICE")"
if [[ -z "$FW_ID" ]]; then
    die "El servicio ${FW_SERVICE} no está levantado. Ejecutá make lab-up primero."
fi

log_info "Cargando reglas nftables en ${FW_SERVICE} (desde /etc/nftables.conf montado)"

# El archivo nftables.conf está montado de solo lectura en /etc/nftables.conf
# (ver docker-compose.yml). Solo hay que cargarlo en el kernel.
"${COMPOSE[@]}" exec -T "$FW_SERVICE" nft -f /etc/nftables.conf
"${COMPOSE[@]}" exec -T "$FW_SERVICE" nft -f /etc/nftables.conf

log_info "Verificando ruleset cargado"
if ! "${COMPOSE[@]}" exec -T "$FW_SERVICE" nft list ruleset >/dev/null 2>&1; then
    die "No se pudo verificar el ruleset de nftables en ${FW_SERVICE}"
fi
log_ok "Reglas nftables cargadas en ${FW_SERVICE}"

summary
