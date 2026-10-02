#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=SCRIPTDIR/../common/lab-net.sh
source /usr/local/lib/lab-net.sh

lab_net_setup

# Clave pública del nodo admin para el usuario operador. Se copia (no se monta directo)
# porque sshd exige que authorized_keys pertenezca al usuario y no sea escribible por otros.
if [[ -f /lab-keys/admin_ed25519.pub ]]; then
    install -d -m 700 -o operador -g operador /home/operador/.ssh
    install -m 600 -o operador -g operador /lab-keys/admin_ed25519.pub /home/operador/.ssh/authorized_keys
fi

mkdir -p /run/sshd
/usr/sbin/sshd
apache2ctl start
echo "[target] sshd y apache2 iniciados"

exec sleep infinity
