# Detección Activa & Monitoreo de Integridad (Fase H)

Este documento detalla la arquitectura de **detección de intrusiones en red (NIDS)** y **monitoreo de integridad de archivos (FIM)** implementada en el laboratorio de bastionado. Con esta fase, el entorno cubre tanto la **prevención activa** (nftables, fail2ban) como la **detección y auditoría forense (Blue Team / SecOps)**.

---

## 1. Detección de Intrusiones en Red con Suricata (NIDS)

El firewall perimetral (`fw`, 10.66.0.2 / 10.66.10.2) ejecuta **Suricata 7** en modo inspección de paquetes (`AF_PACKET`) sobre las interfaces `wan` y `dmz`.

### Reglas de Detección Personalizadas (`firewall/suricata/rules/lab-detection.rules`)

| SID | Firma / Mensaje | Técnica MITRE ATT&CK | Vector Evaluado |
|---|---|---|---|
| `1000001` | `SCAN TCP Null scan detectado` | **T1046** (Network Service Discovery) | Paquetes TCP sin flags configuradas (`flags:0`) comúnmente usados para evasión de firewalls sin estado. |
| `1000002` | `SCAN TCP Xmas scan detectado` | **T1046** (Network Service Discovery) | Paquetes TCP con flags FIN, PSH y URG activas simultáneamente (`flags:FPU`). |
| `1000003` | `SCAN TCP FIN scan detectado` | **T1046** (Network Service Discovery) | Paquetes TCP únicamente con flag FIN activa (`flags:F`). |
| `1000004` | `AUTH SSH Fuerza bruta detectada` | **T1110** (Brute Force) | Más de 5 intentos de conexión TCP SYN dirigidos al puerto 22 en un intervalo de 30 segundos (`threshold: type both, track by_src, count 5, seconds 30`). |

### Registro de Alertas (`/var/log/suricata/fast.log`)

Al ejecutarse `make ids-demo`, desde el nodo atacante (`attacker`, 10.66.0.10) se disparan los escaneos sigilosos con `nmap` y la ráfaga de conexiones al puerto 22. Suricata procesa el tráfico y registra las alertas en `fast.log`:

```text
[**] [1:1000001:1] SCAN TCP Null scan detectado (MITRE T1046) [**] [Classification: (null)] [Priority: 3] {TCP} 10.66.0.10:39842 -> 10.66.10.10:80
[**] [1:1000002:1] SCAN TCP Xmas scan detectado (MITRE T1046) [**] [Classification: (null)] [Priority: 3] {TCP} 10.66.0.10:39843 -> 10.66.10.10:80
[**] [1:1000003:1] SCAN TCP FIN scan detectado (MITRE T1046) [**] [Classification: (null)] [Priority: 3] {TCP} 10.66.0.10:39844 -> 10.66.10.10:80
[**] [1:1000004:1] AUTH SSH Fuerza bruta detectada (MITRE T1110) [**] [Classification: (null)] [Priority: 3] {TCP} 10.66.0.10:41200 -> 10.66.10.10:22
```

---

## 2. Monitoreo de Integridad de Archivos con AIDE (FIM)

En el servidor expuesto de la DMZ (`target`, 10.66.10.10) se ejecuta **AIDE** (*Advanced Intrusion Detection Environment*).

### Rutas Monitoreadas (`lab/compose/target/aide.conf`)

* **Cuentas de usuario y credenciales (MITRE T1078, T1098):** `/etc/passwd`, `/etc/shadow`, `/etc/group`, `/etc/gshadow`, `/etc/sudoers`.
* **Configuración de servicios y acceso:** `/etc/ssh/.*`, `/etc/vsftpd.conf`.
* **Persistencia mediante tareas programadas (MITRE T1053.003):** `/etc/crontab`, `/etc/cron.*`.
* **Binarios del sistema (MITRE T1565):** `/bin`, `/sbin`, `/usr/bin`, `/usr/sbin`, `/usr/local/bin`.

Atributos evaluados: permisos (`p`), inodo (`i`), enlaces (`n`), usuario (`u`), grupo (`g`), tamaño (`s`), tiempo de modificación (`m`), tiempo de cambio de metadatos (`c`) y hash criptográfico **SHA256**.

### Demostración de Detección de Modificaciones (`make fim-demo`)

El script `scripts/fim-demo.sh` simula una intrusión inyectando una cuenta no autorizada (`backdoor_hacker:x:0:0::/root:/bin/bash`) en `/etc/passwd` y un job de persistencia en `/etc/cron.d/malicious_cron`. Al ejecutar `aide --check`:

```text
AIDE found differences between database and filesystem!!

Summary:
  Total number of entries:	14
  Added entries:		1
  Removed entries:		0
  Changed entries:		1

---------------------------------------------------
Added entries:
---------------------------------------------------
f++++++++++++++++: /etc/cron.d/malicious_cron

---------------------------------------------------
Changed entries:
---------------------------------------------------
f > ... mc..H    : /etc/passwd

Detailed information about changes:
File: /etc/passwd
 Size      : 839                              | 885
 Mtime     : 2026-09-18 00:00:00 +0000        | 2026-10-25 20:49:58 +0000
 Ctime     : 2026-10-02 23:19:17 +0000        | 2026-10-25 20:49:58 +0000
 SHA256    : ITUhlMxTO8WHhyFQdFDYZ9KMyxwvXNdz | dZATi7HYEpwRf/vEfUPaVTmJ1Dj5pZNQ
```

El script restaura automáticamente los archivos a su estado original para garantizar idempotencia en subsecuentes ejecuciones.

---

## 3. Comandos de Operación

| Comando | Acción |
|---|---|
| `make ids-apply` | Inicia el motor Suricata en el firewall (`fw`) con las reglas de laboratorio. |
| `make ids-demo` | Lanza escaneos y fuerza bruta desde `attacker` y muestra las alertas de Suricata en vivo. |
| `make fim-baseline` | Inicializa o re-genera la base criptográfica de hashes AIDE en `target`. |
| `make fim-demo` | Inyecta alteraciones deliberadas en `target`, ejecuta `aide --check` y restaura el estado. |
| `make test-detection` | Suite automatizada de verificación de salud para Suricata y AIDE. |
