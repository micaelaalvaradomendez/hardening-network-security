#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
parse_args "$@"
if ! require_vm "auditd rules"; then summary; exit 0; fi

RULES_FILE="/etc/audit/rules.d/99-hardening-network-security.rules"

apply_file "$RULES_FILE" <<'EOF'
-w /etc/passwd -p wa -k identity
-w /etc/group -p wa -k identity
-w /etc/shadow -p wa -k identity
-w /etc/gshadow -p wa -k identity
-w /etc/sudoers -p wa -k scope
-w /etc/sudoers.d/ -p wa -k scope
-w /var/log/faillog -p wa -k logins
-w /var/log/lastlog -p wa -k logins
-a always,exit -F arch=b64 -S execve -F euid=0 -k privileged-commands
-a always,exit -F arch=b32 -S execve -F euid=0 -k privileged-commands
-a always,exit -F arch=b64 -S adjtimex,settimeofday,clock_settime -k time-change
-a always,exit -F arch=b32 -S adjtimex,settimeofday,clock_settime -k time-change
-e 2
EOF

if is_apply; then
    systemctl enable --now auditd
    if [[ "$HNS_CHANGES" -gt 0 ]]; then
        augenrules --check
        if auditctl -s | grep -q '^enabled 2$'; then
            log_warn "auditd is immutable; updated rules will load after reboot"
        else
            augenrules --load
        fi
    else
        log_ok "auditd rules already match; skipping reload"
    fi
fi
summary