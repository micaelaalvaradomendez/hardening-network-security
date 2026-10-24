# Filtrado de red y fail2ban (Fase D)

Documenta el diseño de filtrado perimetral del nodo `fw` y la protección contra
fuerza bruta con fail2ban en el nodo `target`. Corresponde a la **Fase D** del
[plan de desarrollo](../PLAN-DESARROLLO-CASO-B.md).

## Topología

```
[attacker] ─ wan 10.66.0.0/24 ─ [fw] ─ dmz 10.66.10.0/24 ─ [target]
                                  └─── mgmt 10.66.20.0/24 ─ [admin]
```

- `fw` es el único router entre zonas. No hay camino L2/L3 entre zonas que no pase por `fw`
  (redes macvlan `internal`; ver [arquitectura-red.md](arquitectura-red.md)).
- Las reglas de `fw` se montan de solo lectura desde `firewall/nftables.conf`.

## Reglas nftables (`firewall/nftables.conf`)

La tabla `inet hns_filter` se declara y borra antes de definirse, lo que hace la carga
idempotente y no interfiere con otras tablas (por ejemplo, las que crea fail2ban).

### Sets
- `public_tcp` — puertos TCP que WAN puede alcanzar en la DMZ (solo `80`/HTTP).
- `mgmt_tcp` — puertos TCP que MGMT puede alcanzar en la DMZ (solo `22`/SSH).
- `dmz_hosts` — IPs de servidores de la DMZ (`10.66.10.10`).
- `mgmt_hosts` — IPs de estaciones de administración (`10.66.20.10`).

### Cadena `scan_filter` (hook `prerouting`, prioridad `raw`)
Detecta y descarta escaneos TCP con combinaciones de flags no legítimas, antes de
conntrack. Cada regla tiene `counter` y envía a `nflog` grupo 1 (legible con
`tcpdump -i nflog:1`):

| Regla | Detecta |
|-------|---------|
| `tcp flags == 0` | NULL scan (`nmap -sN`) |
| `tcp flags == fin|psh|urg` | XMAS scan (`nmap -sX`) |
| `tcp flags == fin|syn|rst|psh|ack|urg` | XMAS con todos los flags |
| `tcp flags & (syn|fin) == syn|fin` | SYN+FIN |
| `tcp flags & (syn|rst) == syn|rst` | SYN+RST |
| `tcp flags & (fin|ack) == fin` | FIN sin ACK (`nmap -sF`) |

Otros escaneos (ACK, Maimon) los clasifica conntrack como `invalid` en `input` y
`forward`.

### Cadena `input` (hacia el propio `fw`)
- Política `drop`.
- Loopback, tráfico `established,related` y ICMP esencial (destination-unreachable,
  time-exceeded, parameter-problem, echo-request desde MGMT) aceptados.
- `invalid` descartado.
- WAN: `drop` silencioso (no revela información).
- Otras interfaces: `reject admin-prohibited`.
- Log con prefijo `hns-input-drop:` antes del descarte por defecto.

### Cadena `forward` (entre zonas)
- Política `drop`.
- WAN → DMZ: solo puertos `public_tcp` hacia `dmz_hosts` (`80`/HTTP).
- MGMT → DMZ: SSH (`mgmt_tcp`) solo desde `mgmt_hosts`, con rate-limit de nuevas
  conexiones (`limit rate over 20/minute burst 20`). El exceso se descarta con log
  (`hns-ssh-ratelimit:`).
- ICMP echo-request limitado desde MGMT.
- Todo lo demás: `drop` de WAN, `reject admin-prohibited` del resto, con log
  (`hns-fwd-drop:`).

### Cadena `output`
- Política `accept`.

## fail2ban (`firewall/fail2ban/`)

Corre en el contenedor `target` para proteger su `sshd` contra fuerza bruta.

### Configuración (`jail.local`)
- `backend = systemd` (estándar en Debian 12/13).
- `banaction = nftables-multiport` (bloqueo a nivel de nftables, no iptables).
- `maxretry = 3`, `findtime = 10m`, `bantime = 10m`.
- `ignoreip = 127.0.0.1/8 ::1` (ninguna estación exenta a propósito).

### Override de contenedor (`jail.d/90-hns-container.local`)
Los contenedores del laboratorio no tienen systemd/journald, por lo que sshd escribe
a `/var/log/auth.log` vía rsyslog y fail2ban lee ese archivo con `backend = polling`.

### Demo de baneo
Desde `admin`, `hydra` contra SSH de `target` con contraseñas erróneas activa la jail
`sshd`; la IP se añade al set de baneados de nftables y las conexiones posteriores
desde esa IP son descartadas.

## Validación

```bash
# 1. Sintaxis de nftables (sin cargar)
make lint            # shellcheck de todos los scripts
nft -c -f firewall/nftables.conf

# 2. Levantar laboratorio y aplicar filtrado
make lab-up
make harden

# 3. Verificar filtrado
make test-fw

# 4. Captura de tráfico (tcpdump en nflog:1)
docker compose exec -T fw tcpdump -i nflog:1 -c 20 -n
```

## Archivos de Fase D

| Archivo | Contenido |
|---------|-----------|
| `firewall/nftables.conf` | Reglas de filtrado perimetral (sets, anti-scan, forward por zona, ICMP) |
| `firewall/fail2ban/jail.local` | Configuración canónica de fail2ban |
| `firewall/fail2ban/jail.d/90-hns-container.local` | Override para contenedor sin systemd |
| `scripts/03-firewall-nftables.sh` | Carga las reglas nftables en `fw` (--check/--apply) |
| `scripts/06-fail2ban.sh` | Instala configuración de fail2ban en `target` (--check/--apply) |
| `tests/test-firewall.sh` | Verificación del estado endurecido |
| `lab/compose/fw/entrypoint.sh` | Carga nftables.conf al arrancar `fw` |
| `lab/compose/target/Dockerfile` | Añade fail2ban y rsyslog |
| `lab/compose/target/entrypoint.sh` | Arranca rsyslog, sshd con `-E /var/log/auth.log`, fail2ban |
