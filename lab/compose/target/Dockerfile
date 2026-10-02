# Servidor de servicios en la dmz: instalación Debian "por defecto" con SSH y HTTP.
# Las debilidades deliberadas del baseline se agregan en la Fase B; el bastionado, en C y D.
FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        iproute2 iputils-ping openssh-server apache2 sudo nftables procps \
 && rm -rf /var/lib/apt/lists/* \
 && useradd --create-home --shell /bin/bash --groups sudo operador

COPY common/lab-net.sh /usr/local/lib/lab-net.sh
COPY target/entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
