# Matriz de Políticas y Controles de Hardening (Alineación CIS Benchmark)

Este documento detalla la matriz técnica de controles implementados en el repositorio,
alineados a las recomendaciones del **CIS Debian Linux Benchmark** y a las mejores
prácticas de defensa en profundidad para infraestructuras seguras.

> **Aviso de cumplimiento:** Las referencias a CIS identifican directivas y criterios
> técnicos comúnmente auditados en la industria; no implican certificación formal por
> parte de Center for Internet Security (CIS).

---

## 1. Filtrado de Red y Perímetro (`firewall/nftables.conf`)

| ID / Control | Descripción | Justificación Técnica | Implementación | Verificación |
|---|---|---|---|---|
| **NET-01** | Política por defecto `DROP` en `input` y `forward` | Principio de mínimo privilegio: ningún tráfico de red es permitido a menos que esté explícitamente autorizado. | `policy drop;` en cadenas `input` y `forward` | `nft list chain inet hns_filter input` |
| **NET-02** | Inspección de estados (Stateful Inspection) | Permite respuestas de sesiones legítimas iniciadas (`established, related`) y descarta paquetes inválidos sin procesar la tabla completa. | `ct state established,related accept`<br>`ct state invalid drop` | `tests/test-firewall.sh` |
| **NET-03** | Mitigación de escaneos TCP anómalos (`scan_filter`) | Descarta en `prerouting raw` paquetes con flags ilegales (NULL, XMAS, SYN+FIN) antes del conntrack, evitando consumo innecesario de tablas de estado. | Cadena `scan_filter` con descarte y contadores hacia `nflog:1` | `nmap -sN / -sX` retorna `filtered`; captura en `nflog` |
| **NET-04** | Segmentación estricta por zonas (WAN, DMZ, MGMT) | Aísla los servidores de aplicaciones del perímetro de administración; WAN no puede acceder a SSH ni a MGMT. | Reglas `iifname` / `oifname` con sets `@public_tcp` y `@mgmt_tcp` | `tests/test-ports.sh` |
| **NET-05** | Rate limiting en nuevas conexiones SSH | Mitiga ataques de fuerza bruta y denegación de servicio a nivel de red antes de alcanzar el demonio SSH. | `limit rate over 20/minute burst 20 packets log prefix "hns-ssh-ratelimit: "` | Regla en cadena `forward` |
| **NET-06** | Drop silencioso en WAN vs Reject en MGMT | WAN no recibe respuestas ICMP (evita enumeración de host activo); redes internas reciben `admin-prohibited` inmediato para evitar timeouts. | `iifname "wan" drop`<br>`reject with icmpx type admin-prohibited` | Captura `evidencias/despues/reject-vs-drop.pcap` |

---

## 2. Protección Dinámica contra Fuerza Bruta (`firewall/fail2ban/`)

| ID / Control | Descripción | Justificación Técnica | Implementación | Verificación |
|---|---|---|---|---|
| **F2B-01** | Detección reactiva de autenticaciones fallidas | Monitorea `/var/log/auth.log` (rsyslog) buscando patrones de fallos en SSH. | `jail.local` con `maxretry = 3`, `findtime = 10m` | `fail2ban-client status sshd` |
| **F2B-02** | Bloqueo nativo en kernel con nftables | Bloquea IPs atacantes mediante un `set` dinámico de nftables (`table inet f2b-table`), con orden de complejidad O(1). | `banaction = nftables-multiport` | `nft list table inet f2b-table` |
| **F2B-03** | No exención de hosts de administración | Ninguna IP de red (salvo loopback) está excluida; si una estación MGMT se ve comprometida, fail2ban actúa igual. | `ignoreip = 127.0.0.1/8 ::1` | `make fail2ban-demo` |

---

## 3. Bastionado de Kernel y Memoria (`scripts/01-system-hardening.sh`)

| Control CIS | Parámetro / Directiva | Justificación Técnica | Implementación | Verificación |
|---|---|---|---|---|
| **CIS 3.1.1** | Deshabilitar protocolos de red obsoletos | Módulos `dccp`, `sctp`, `rds`, `tipc` son vectores frecuentes de vulnerabilidades locales de kernel. | `install <modulo> /bin/true` en `/etc/modprobe.d/` | `modprobe --dry-run` |
| **CIS 3.2.1** | `net.ipv4.conf.all.rp_filter = 1` | Validación de ruta inversa (Reverse Path Filtering): previene spoofing de direcciones IP en interfaces de red. | `/etc/sysctl.d/99-security-hardening.conf` | `sysctl net.ipv4.conf.all.rp_filter` |
| **CIS 3.2.2** | `net.ipv4.conf.all.accept_redirects = 0` | Ignora redirecciones ICMP para mitigar ataques de intermediario (Man-in-the-Middle) en la tabla de ruteo. | `accept_redirects = 0` (all y default) | `sysctl net.ipv4.conf.all.accept_redirects` |
| **CIS 3.2.4** | `net.ipv4.conf.all.log_martians = 1` | Registra paquetes con direcciones de origen imposibles o falsificadas en los logs del kernel. | `log_martians = 1` (all y default) | `sysctl net.ipv4.conf.all.log_martians` |
| **CIS 3.2.8** | `net.ipv4.tcp_syncookies = 1` | Mitiga ataques de denegación de servicio por agotamiento de cola SYN (SYN Flood DoS). | `tcp_syncookies = 1` | `sysctl net.ipv4.tcp_syncookies` |
| **CIS 1.5.1** | `fs.suid_dumpable = 0` | Impide que binarios SUID generen core dumps con información sensible o volcados de memoria de credenciales. | `fs.suid_dumpable = 0` | `sysctl fs.suid_dumpable` |
| **CIS 1.5.3** | `kernel.randomize_va_space = 2` | Aleatorización completa del espacio de memoria (ASLR) para dificultar exploits de buffer overflow. | `kernel.randomize_va_space = 2` | `sysctl kernel.randomize_va_space` |
| **CIS 5.6** | Restricción de comando `su` | Limita la ejecución del comando `su` únicamente a los usuarios pertenecientes al grupo autorizado (`su-admin`). | `pam_wheel.so required group=su-admin` en `/etc/pam.d/su` | `grep pam_wheel /etc/pam.d/su` |

---

## 4. Endurecimiento de Acceso Remoto SSH (`scripts/02-ssh-bastion.sh`)

| Control CIS | Directiva SSH | Justificación Técnica | Implementación | Verificación |
|---|---|---|---|---|
| **CIS 5.2.1** | `PermitRootLogin no` | Impide que atacantes hagan ataques dirigidos a la cuenta superusuario por red; exige trazabilidad nominal. | Drop-in `/etc/ssh/sshd_config.d/99-security.conf` | `sshd -T \| grep permitrootlogin` |
| **CIS 5.2.2** | `PasswordAuthentication no` | Erradica vectores de fuerza bruta y spraying de contraseñas; solo permite claves criptográficas (Ed25519/RSA). | `PasswordAuthentication no` | `sshd -T \| grep passwordauthentication` |
| **CIS 5.2.4** | `MaxAuthTries 4` | Cierra la sesión SSH ante 4 intentos erróneos, reduciendo la ventana para ataques de fuerza bruta. | `MaxAuthTries 4` | `sshd -T \| grep maxauthtries` |
| **CIS 5.2.10** | `X11Forwarding no` | Deshabilita el reenvío gráfico X11 para evitar ataques de espionaje de teclado o inyección de eventos X. | `X11Forwarding no` | `sshd -T \| grep x11forwarding` |
| **CIS 5.2.14** | `AllowGroups ssh-admin` | Restringe el inicio de sesión SSH a los miembros explícitos del grupo administrativo dedicado. | `AllowGroups ssh-admin` | `sshd -T \| grep allowgroups` |

---

## 5. Auditoría de Seguridad de Kernel (`scripts/04-auditd-rules.sh`)

| Control CIS | Regla auditd | Justificación Técnica | Tag de Auditoría | Verificación |
|---|---|---|---|---|
| **CIS 4.1.3** | Cambios en `/etc/passwd`, `/etc/shadow`, `/etc/group` | Trazabilidad forense ante creación o alteración no autorizada de cuentas de usuario o contraseñas. | `-k identity` | `auditctl -l \| grep identity` |
| **CIS 4.1.4** | Cambios en configuración de red y hostname | Monitorea modificaciones en interfaces, DNS o configuración de ruteo del sistema. | `-k system-locale` | `auditctl -l \| grep system-locale` |
| **CIS 4.1.8** | Modificaciones en `/etc/sudoers` y `sudoers.d/` | Alerta ante intentos de persistencia o modificación de políticas de escalada de privilegios. | `-k scope` | `auditctl -l \| grep scope` |
| **CIS 4.1.11** | Ejecución de comandos privilegiados (SUID/SGID) | Registra el uso de binarios con bits especiales por usuarios no privilegiados. | `-k privileged` | `auditctl -l \| grep privileged` |
| **CIS 4.1.18** | Inmutabilidad de la configuración (`-e 2`) | Impide que un atacante que obtenga root deshabilite la auditoría sin reiniciar el sistema operativo. | `-e 2` al final del archivo de reglas | `auditctl -s` |

---

## 6. Aislamiento de Servicios Web (`scripts/05-service-isolation.sh`)

| Control | Mecanismo | Justificación Técnica | Implementación | Verificación |
|---|---|---|---|---|
| **SEC-01** | Sandboxing en systemd | Restringe privilegios de ejecución del servidor HTTP: deshabilita namespaces ajenos, restringe escritura en `/tmp` y prohíbe escalada. | Directivas `ProtectSystem=full`, `PrivateTmp=true`, `NoNewPrivileges=true` | `systemctl cat apache2` |
| **SEC-02** | Perfil AppArmor para Apache | Limita los accesos al sistema de archivos del proceso Apache en modo `enforce`; un exploit en una aplicación web no puede leer archivos del sistema fuera del alcance autorizado. | Perfil `/etc/apparmor.d/usr.sbin.apache2` | `aa-status \| grep apache2` |

