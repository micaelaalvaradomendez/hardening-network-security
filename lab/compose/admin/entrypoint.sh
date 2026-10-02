#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=SCRIPTDIR/../common/lab-net.sh
source /usr/local/lib/lab-net.sh

lab_net_setup

if [[ -f /lab-keys/admin_ed25519 ]]; then
    install -d -m 700 /root/.ssh
    install -m 600 /lab-keys/admin_ed25519 /root/.ssh/id_ed25519
    cat >/root/.ssh/config <<'EOF'
Host target
    HostName 10.66.10.10
    User operador
    # Laboratorio efímero: las claves de host cambian en cada rebuild.
    StrictHostKeyChecking accept-new
    UserKnownHostsFile /dev/null
EOF
fi

exec sleep infinity
