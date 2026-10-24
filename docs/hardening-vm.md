# Hardening de Debian 13 en VM

La Fase C endurece una VM Debian 13 dedicada. No ejecutes `--apply` en el host: los scripts rechazan cualquier entorno que no se detecte como VM.

## Recorrido

1. Instala Vagrant, el plugin `vagrant-libvirt`, QEMU/KVM y libvirt.
2. Ejecuta `make vm-up` para crear Debian Trixie con SSH, Apache, auditd y AppArmor.
3. Ejecuta `make vm-baseline` antes de cambiar controles. Las salidas quedan en `evidencias/vm/antes/<run-id>/`.
4. Revisa `make vm-check`; `--check` informa cambios y no los aplica.
5. Ejecuta `make vm-harden` para aplicar los cuatro scripts. Los archivos modificados se respaldan bajo `/var/backups/hardening-network-security/`.
6. Vuelve a ejecutar `make vm-check` y `BASELINE_PHASE=despues make vm-baseline` para revisar el estado posterior.

La baseline crea `baseline.complete` solo cuando terminaron todas las capturas. `make vm-harden` exige esa marca en `evidencias/vm/antes/` y no acepta una ejecución parcial.

El `Vagrantfile` deshabilita la carpeta compartida predeterminada `/vagrant`, que el provider libvirt intenta servir con NFS. El repo se sincroniza en una sola dirección por rsync a `/workspace`; ejecuta `vagrant rsync` antes de llamar scripts desde el host.

## Controles

| Script | Controles aplicados |
|---|---|
| `01-system-hardening.sh` | Sysctl de red/kernel, blacklist de módulos y restricción de `su` al grupo `su-admin`. Agrega solo el grupo; las cuentas autorizadas deben añadirse explícitamente. |
| `02-ssh-bastion.sh` | Deshabilita root/password/keyboard-interactive, permite clave pública y limita SSH al grupo `ssh-admin`; valida con `sshd -t` y recarga el servicio. Se niega a aplicar si no encuentra una clave autorizada en `/home`. |
| `04-auditd-rules.sh` | Audita archivos de identidad/sudoers, ejecuciones privilegiadas y cambios de hora. La regla `-e 2` vuelve inmutable la política hasta reiniciar. |
| `05-service-isolation.sh` | Sandbox systemd de Apache y perfil AppArmor específico en modo `enforce`. |

Las referencias a CIS describen alineación de controles, no certifican cumplimiento. Lynis debe compararse entre baselines tomadas en la misma VM; no contra el contenedor de Fase B.

## Verificación antes y después

Comparación entre `evidencias/vm/antes/20261003T032617Z` y `evidencias/vm/despues/20261024T175644Z` en Debian 13 (Trixie):

| Indicador | Antes | Después | Evidencia |
|---|---|---|---|
| **Lynis hardening index** | `65` | `69` (`+4`) | `lynis.txt` (264 pruebas ejecutadas) |
| **Lynis suggestions** | `53` | `46` (`-7`) | Resueltos `NETW-3200` (`dccp`, `sctp`, `rds`, `tipc`), `ACCT-9630` (reglas `auditd` cargadas), `SSH-7408` y `LOGG-2190` |
| **Configuración efectiva SSH (`sshd -T`)** | `permitrootlogin without-password`, `maxauthtries 6`, `x11forwarding yes` | `permitrootlogin no`, `maxauthtries 4`, `x11forwarding no`, `allowgroups ssh-admin` | `sshd-effective-config.txt` |
| **Reglas `auditd` (`auditctl -l`)** | Sin reglas activas | 12 reglas cargadas (`identity`, `scope`, `logins`, `privileged-commands` b64/b32, `time-change` b64/b32) y `enabled 2` | `04-auditd-rules.sh` + runtime |
| **Aislamiento de Apache (`aa-status`)** | Sin perfil dedicado | Perfil `/usr/sbin/apache2` y procesos worker en modo `enforce`; `apache2`, `ssh` y `auditd` activos (`HTTP 200`) | `05-service-isolation.sh` + runtime |