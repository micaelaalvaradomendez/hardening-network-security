# shellcheck shell=bash
# Biblioteca común para los scripts de bastionado.
# Uso: source "$(dirname "$0")/lib/common.sh"; parse_args "$@"
#
# Contrato de todos los scripts:
#   --check  (default) informa qué cambiaría, sin tocar el sistema.
#   --apply  aplica los cambios, con backup previo de cada archivo modificado.
#   Idempotente: correrlo dos veces seguidas no produce cambios en la segunda.

set -euo pipefail

HNS_MODE="${HNS_MODE:-check}"
HNS_BACKUP_DIR="${HNS_BACKUP_DIR:-/var/backups/hardening-network-security}"
HNS_RUN_ID="${HNS_RUN_ID:-$(date +%Y%m%d-%H%M%S)}"
HNS_CHANGES=0
HNS_SKIPS=0

if [[ -t 1 ]]; then
    _C_RESET=$'\e[0m' _C_BLUE=$'\e[34m' _C_GREEN=$'\e[32m'
    _C_YELLOW=$'\e[33m' _C_GREY=$'\e[90m' _C_RED=$'\e[31m'
else
    _C_RESET='' _C_BLUE='' _C_GREEN='' _C_YELLOW='' _C_GREY='' _C_RED=''
fi

log_info()  { printf '%s[INFO]%s  %s\n' "$_C_BLUE"   "$_C_RESET" "$*"; }
log_ok()    { printf '%s[OK]%s    %s\n' "$_C_GREEN"  "$_C_RESET" "$*"; }
log_warn()  { printf '%s[WARN]%s  %s\n' "$_C_YELLOW" "$_C_RESET" "$*"; }
log_skip()  { printf '%s[SKIP]%s  %s\n' "$_C_GREY"   "$_C_RESET" "$*"; HNS_SKIPS=$((HNS_SKIPS + 1)); }
log_error() { printf '%s[ERROR]%s %s\n' "$_C_RED"    "$_C_RESET" "$*" >&2; }
die()       { log_error "$*"; exit 1; }

usage() {
    cat <<EOF
Uso: $(basename "$0") [--check | --apply]

  --check   Modo auditoría (default): muestra qué cambiaría sin modificar nada.
  --apply   Aplica los cambios (requiere root). Hace backup en ${HNS_BACKUP_DIR}.
  -h        Muestra esta ayuda.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --check) HNS_MODE=check ;;
            --apply) HNS_MODE=apply ;;
            -h|--help) usage; exit 0 ;;
            *) usage >&2; die "Argumento desconocido: $1" ;;
        esac
        shift
    done
    if is_apply; then require_root; fi
    log_info "Modo: ${HNS_MODE} · Entorno: $(detect_env)"
}

is_apply() { [[ "$HNS_MODE" == "apply" ]]; }

require_root() {
    [[ "${EUID:-$(id -u)}" -eq 0 ]] || die "--apply requiere root (usar sudo)."
}

# Imprime: container | vm | bare-metal
detect_env() {
    if command -v systemd-detect-virt >/dev/null 2>&1; then
        if systemd-detect-virt --container --quiet; then echo container; return; fi
        if systemd-detect-virt --vm --quiet; then echo vm; return; fi
    fi
    if [[ -f /.dockerenv || -f /run/.containerenv ]] || grep -qaE 'docker|containerd|kubepods' /proc/1/cgroup 2>/dev/null; then
        echo container
    else
        echo bare-metal
    fi
}

# Los controles de sistema solo se aplican dentro de una VM dedicada. Evita
# modificar el host además de rechazar contenedores que comparten su kernel.
require_vm() {
    local control="$1"
    if [[ "$(detect_env)" != "vm" ]]; then
        log_skip "${control}: requiere una VM dedicada (entorno detectado: $(detect_env))"
        return 1
    fi
}

backup_file() {
    local path="$1"
    [[ -e "$path" ]] || return 0
    local dest="${HNS_BACKUP_DIR}/${HNS_RUN_ID}${path}"
    mkdir -p "$(dirname "$dest")"
    cp -a "$path" "$dest"
    log_info "Backup: ${path} -> ${dest}"
}

ensure_line() {
    local path="$1" line="$2"
    if [[ -f "$path" ]] && grep -Fxq "$line" "$path"; then
        log_ok "${path}: línea presente"
        return 0
    fi

    HNS_CHANGES=$((HNS_CHANGES + 1))
    if ! is_apply; then
        log_warn "${path}: agregaría línea (correr con --apply)"
        return 0
    fi

    backup_file "$path"
    mkdir -p "$(dirname "$path")"
    touch "$path"
    printf '%s\n' "$line" >>"$path"
    log_ok "${path}: línea agregada"
}

# Escribe el contenido de stdin en <destino> solo si difiere del actual.
# Uso: apply_file /etc/sysctl.d/99-x.conf [modo] <<'EOF' ... EOF
apply_file() {
    local dest="$1" mode="${2:-0644}" tmp
    tmp="$(mktemp)"
    cat >"$tmp"

    if [[ -f "$dest" ]] && cmp -s "$tmp" "$dest"; then
        rm -f "$tmp"
        log_ok "${dest}: sin cambios"
        return 0
    fi

    HNS_CHANGES=$((HNS_CHANGES + 1))
    if ! is_apply; then
        rm -f "$tmp"
        log_warn "${dest}: cambiaría (correr con --apply)"
        return 0
    fi

    backup_file "$dest"
    mkdir -p "$(dirname "$dest")"
    install -m "$mode" "$tmp" "$dest"
    rm -f "$tmp"
    log_ok "${dest}: actualizado"
}

summary() {
    if is_apply; then
        log_info "Resumen: ${HNS_CHANGES} cambio(s) aplicado(s), ${HNS_SKIPS} control(es) omitido(s)."
    else
        log_info "Resumen: ${HNS_CHANGES} cambio(s) pendiente(s), ${HNS_SKIPS} control(es) omitido(s)."
    fi
}
