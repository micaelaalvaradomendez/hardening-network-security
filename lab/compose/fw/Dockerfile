# Firewall perimetral: rutea entre wan, dmz y mgmt.
# Fase A: forwarding abierto (sin reglas). El filtrado se carga en la Fase D.
FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        iproute2 nftables conntrack tcpdump iputils-ping procps \
 && rm -rf /var/lib/apt/lists/*

COPY common/lab-net.sh /usr/local/lib/lab-net.sh
COPY fw/entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
