#!/usr/bin/env bash
set -euo pipefail
# shellcheck source=SCRIPTDIR/../common/lab-net.sh
source /usr/local/lib/lab-net.sh

lab_net_setup

# rsyslog debe estar corriendo para que /var/log/auth.log exista y fail2ban (polling)
# pueda leer los intentos fallidos de SSH.
rsyslogd 2>/dev/null || true

: "${LAB_WEAK_ROOT_PASSWORD:?LAB_WEAK_ROOT_PASSWORD must be set for this intentionally vulnerable target}"
printf 'root:%s\n' "$LAB_WEAK_ROOT_PASSWORD" | chpasswd

# Clave pública del nodo admin para el usuario operador. Se copia (no se monta directo)
# porque sshd exige que authorized_keys pertenezca al usuario y no sea escribible por otros.
if [[ -f /lab-keys/admin_ed25519.pub ]]; then
    install -d -m 700 -o operador -g operador /home/operador/.ssh
    install -m 600 -o operador -g operador /lab-keys/admin_ed25519.pub /home/operador/.ssh/authorized_keys
fi

mkdir -p /run/sshd
/usr/sbin/sshd -t
/usr/sbin/sshd

apache2ctl configtest
apache2ctl start
/usr/sbin/vsftpd /etc/vsftpd.conf &

# fail2ban se arranca con el contenedor si su configuración está presente.
if [[ -f /etc/fail2ban/jail.local ]]; then
    fail2ban-client -x start 2>/dev/null || true
fi

echo "[target] sshd, apache2, vsftpd, rsyslog y fail2ban iniciados"

exec sleep infinity
