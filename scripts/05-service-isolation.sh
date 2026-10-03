#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./scripts/lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"
parse_args "$@"
if ! require_vm "Apache sandboxing"; then summary; exit 0; fi

UNIT_DIR="/etc/systemd/system/apache2.service.d"
UNIT_FILE="${UNIT_DIR}/hardening-network-security.conf"
APPARMOR_FILE="/etc/apparmor.d/usr.sbin.apache2-hns"

apply_file "$UNIT_FILE" <<'EOF'
[Service]
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectSystem=full
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
ReadWritePaths=/var/log/apache2 /var/lock/apache2 /run/apache2 /var/lib/apache2
EOF

apply_file "$APPARMOR_FILE" <<'EOF'
#include <tunables/global>

/usr/sbin/apache2 flags=(attach_disconnected) {
  #include <abstractions/base>
  #include <abstractions/nameservice>
  capability net_bind_service,
  network inet stream,
  network inet6 stream,
  /etc/apache2/** r,
  /etc/ssl/** r,
  /usr/sbin/apache2 mr,
  /usr/lib/**/apache2/modules/** mr,
  /usr/share/apache2/** r,
  /var/www/** r,
  /var/log/apache2/** rw,
  /var/lock/apache2/** rwk,
  /run/apache2/** rw,
  /var/lib/apache2/** rw,
  /tmp/** rw,
  /var/tmp/** rw,
  /dev/urandom r,
  /proc/meminfo r,
  /proc/cpuinfo r,
  /proc/sys/kernel/random/uuid r,
}
EOF

if is_apply; then
    apparmor_parser --skip-kernel-load -r "$APPARMOR_FILE"
    systemd-analyze verify apache2.service
    apparmor_parser -r "$APPARMOR_FILE"
    systemctl daemon-reload
    systemctl restart apache2
fi
summary