# Estación de administración en mgmt: único origen autorizado para SSH (se exige en la Fase D).
FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        iproute2 iputils-ping openssh-client curl hydra \
 && rm -rf /var/lib/apt/lists/*

COPY common/lab-net.sh /usr/local/lib/lab-net.sh
COPY admin/entrypoint.sh /usr/local/bin/entrypoint.sh
COPY admin/ban-demo-passwords.txt /usr/local/share/hns/ban-demo-passwords.txt
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
