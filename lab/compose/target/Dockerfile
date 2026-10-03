# Servidor de servicios en la dmz: instalación Debian "por defecto" con SSH y HTTP.
# Las debilidades deliberadas del baseline se agregan en la Fase B; el bastionado, en C y D.
FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
       iproute2 iputils-ping openssh-server apache2 sudo nftables procps vsftpd lynis \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --shell /bin/bash --groups sudo operador

COPY common/lab-net.sh /usr/local/lib/lab-net.sh
COPY target/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY target/sshd-lab-vulnerable.conf /etc/ssh/sshd_config.d/99-lab-vulnerable.conf
COPY target/apache-lab-vulnerable.conf /etc/apache2/conf-available/lab-vulnerable.conf
COPY target/vsftpd.conf /etc/vsftpd.conf

RUN a2enconf lab-vulnerable \
 && rm -f /var/www/html/index.html \
 && install -d -m 0755 /var/www/html/backup /srv/ftp \
 && printf '%s\n' 'Lab backup directory listing enabled.' > /var/www/html/backup/notes.txt \
 && printf '%s\n' 'Anonymous FTP is enabled for this isolated lab.' > /srv/ftp/welcome.txt

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
