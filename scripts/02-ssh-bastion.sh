#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
parse_args "$@"
if ! require_vm "SSH hardening"; then summary; exit 0; fi

DROPIN="/etc/ssh/sshd_config.d/99-hardening-network-security.conf"
AUTHORIZED_KEYS="$(find /home -type f -path '*/.ssh/authorized_keys' -size +0c -print -quit 2>/dev/null || true)"
[[ -n "$AUTHORIZED_KEYS" ]] || die "No non-empty authorized_keys found; refusing key-only SSH configuration"

apply_file "$DROPIN" <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
MaxAuthTries 4
X11Forwarding no
AllowGroups ssh-admin
EOF

sshd -t
if is_apply; then
    systemctl reload ssh
fi
summary