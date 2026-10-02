# Estación de administración en mgmt: único origen autorizado para SSH (se exige en la Fase D).
FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        iproute2 iputils-ping openssh-client curl \
 && rm -rf /var/lib/apt/lists/*

COPY common/lab-net.sh /usr/local/lib/lab-net.sh
COPY admin/entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
