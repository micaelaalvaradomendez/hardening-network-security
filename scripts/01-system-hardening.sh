#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
parse_args "$@"
if ! require_vm "system hardening"; then summary; exit 0; fi

SYSCTL_FILE="/etc/sysctl.d/99-hardening-network-security.conf"
MODULES_FILE="/etc/modprobe.d/99-hardening-network-security.conf"
PAM_SU_FILE="/etc/pam.d/su"

if getent group su-admin >/dev/null; then
    log_ok "Group su-admin exists"
else
    HNS_CHANGES=$((HNS_CHANGES + 1))
    if is_apply; then
        groupadd --system su-admin
        log_ok "Group su-admin created; add trusted accounts to it explicitly"
    else
        log_warn "Group su-admin would be created; add trusted accounts explicitly"
    fi
fi

apply_file "$SYSCTL_FILE" <<'EOF'
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.secure_redirects = 0
net.ipv4.conf.default.secure_redirects = 0
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
kernel.randomize_va_space = 2
kernel.yama.ptrace_scope = 1
fs.suid_dumpable = 0
EOF

apply_file "$MODULES_FILE" <<'EOF'
install dccp /bin/false
install sctp /bin/false
install rds /bin/false
install tipc /bin/false
blacklist dccp
blacklist sctp
blacklist rds
blacklist tipc
EOF

ensure_line "$PAM_SU_FILE" 'auth required pam_wheel.so use_uid group=su-admin'

if is_apply; then
    sysctl --system
fi
summary