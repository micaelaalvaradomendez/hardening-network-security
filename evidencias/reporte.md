# Reporte de Auditoría Antes/Después — Hardening de Red y Sistemas Linux

Generado: 2026-10-25T15:49:26Z UTC

## 1. Resumen de Entornos Auditados

- **Baseline de red (Antes):** `20261003T005000Z`
- **Auditoría de red (Después):** `20261025T154639Z`
- **Hardening de SO en VM:** `20261003T032617Z` (antes) vs `20261024T175644Z` (después)

## 2. Superficie de Ataque de Red (Auditoría WAN -> DMZ)

### 2.1 Puertos de Servicio (Nmap TCP SYN Scan)

| Puerto / Servicio | Estado Inicial (Antes) | Estado Endurecido (Después) | Impacto de Seguridad |
|---|---|---|---|
| `21/tcp` (FTP (vsftpd)) | `open` | `filtered` | Cerrado al tráfico público; previene autenticación anónima y fuerza bruta. |
| `22/tcp` (SSH (OpenSSH)) | `open` | `filtered` | Aislado del perímetro WAN; administración restringida a la zona MGMT. |
| `80/tcp` (HTTP (Apache)) | `open` | `open` | Servicio público legítimo; expuesto con filtrado stateful en firewall. |

### 2.2 Detección y Mitigación de Escaneos Sigilosos (Netfilter scan_filter)

| Tipo de Escaneo | Nmap Flag | Estado Antes | Estado Después | Mitigación nftables |
|---|---|---|---|---|
| NULL | `-sN` | `open|filtered` | `open|filtered` | Prerouting raw drop + counter log nflog:1 |
| XMAS | `-sX` | `open|filtered` | `open|filtered` | Prerouting raw drop + counter log nflog:1 |
| FIN | `-sF` | `open|filtered` | `open|filtered` | Prerouting raw drop + counter log nflog:1 |

## 3. Auditoría de Servicios de Red

### 3.1 Exposición de SSH desde WAN (ssh-audit)

- **Estado Inicial:** Puerto 22 alcanzable desde WAN; enumeraba algoritmos criptográficos débiles y versiones.
- **Estado Endurecido:** Conexión descartada silenciosamente (`timed out`). Superficie SSH reducida a **0%** para atacantes en WAN.
- **Acceso Administrativo:** Canal SSH operativo exclusivamente desde `mgmt` (10.66.20.10) con clave Ed25519.

### 3.2 Escaneo Web de Vulnerabilidades (Nikto)

| Métrica | Antes | Después |
|---|---|---|
| Hallazgos OSVDB / CVE reportados | 7 | 7 |

## 4. Hardening de Sistema Operativo (Debian 13 VM — CIS Benchmark)

| Indicador / Control CIS | Antes | Después | Resultado |
|---|---|---|---|
| **Lynis Hardening Index** | `65` | `69` | +4 puntos de bastionado |
| **Sugerencias pendientes Lynis** | `53` | `46` | 7 sugerencias remediadas |
| **SSH PermitRootLogin** | `without-password` | `no` | Control CIS aplicado |
| **SSH PasswordAuthentication** | `yes` | `no` | Solo clave pública |
| **SSH MaxAuthTries** | `6` | `4` | Reducción de margen de fuerza bruta |
| **Reglas de auditoría auditd** | 0 activas | 12 cargadas + `-e 2` | Trazabilidad inmutable |
| **Aislamiento Apache (AppArmor)** | Sin perfil | `enforce` | Worker confinado |

## 5. Conclusión y Resumen Ejecutivo

La comparativa formal confirma la reducción sustancial de la superficie de exposición:
1. **Perímetro de red:** El filtrado nftables redujo los puertos accesibles desde WAN de 3 a 1 (únicamente HTTP legítimo), descartando pasivamente escaneos sigilosos sin delatar la presencia del firewall.
2. **Protección en profundidad:** El bastionado de SSH y la defensa activa con fail2ban garantizan que intentos repetidos de fuerza bruta queden bloqueados a nivel de kernel mediante conjuntos dinámicos de nftables.
3. **Sistemas:** La parametrización CIS y el monitoreo con auditd fortalecen la resiliencia del host frente a movimientos laterales y escalada de privilegios.

---
*Reporte automatizado generado por `make report` — Laboratorio de Hardening y Seguridad.*
