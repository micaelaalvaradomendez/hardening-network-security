# Nodo auditor/atacante en la zona wan. Herramientas de pentesting adicionales se suman en la Fase B.
FROM debian:trixie-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        iproute2 iputils-ping traceroute nmap netcat-openbsd curl openssh-client tcpdump \
 && rm -rf /var/lib/apt/lists/*

COPY common/lab-net.sh /usr/local/lib/lab-net.sh
COPY attacker/entrypoint.sh /usr/local/bin/entrypoint.sh
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
