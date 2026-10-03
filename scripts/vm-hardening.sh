#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:---check}"
[[ "$MODE" == "--check" || "$MODE" == "--apply" ]] || {
    printf 'Uso: %s [--check|--apply]\n' "$(basename "$0")" >&2
    exit 2
}
command -v vagrant >/dev/null 2>&1 || {
    printf 'Vagrant no está instalado. Instalá Vagrant y el plugin vagrant-libvirt.\n' >&2
    exit 1
}

VM_DIR="${ROOT_DIR}/lab/vm"
if [[ "$MODE" == "--apply" ]] && ! compgen -G "${ROOT_DIR}/evidencias/vm/antes/*/baseline.complete" >/dev/null; then
    printf 'No hay baseline de VM. Ejecutá make vm-baseline antes de aplicar hardening.\n' >&2
    exit 1
fi
(cd "$VM_DIR" && vagrant status --machine-readable | grep -q ',state,running$') || {
    printf 'La VM no está activa. Ejecutá make vm-up primero.\n' >&2
    exit 1
}
(cd "$VM_DIR" && vagrant rsync)

for script in 01-system-hardening.sh 02-ssh-bastion.sh 04-auditd-rules.sh 05-service-isolation.sh; do
    printf '\n==> %s %s\n' "$script" "$MODE"
    (cd "$VM_DIR" && vagrant ssh -c "sudo bash /workspace/scripts/${script} ${MODE}")
done