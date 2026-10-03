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

## Controles

| Script | Controles aplicados |
|---|---|
| `01-system-hardening.sh` | Sysctl de red/kernel, blacklist de módulos y restricción de `su` al grupo `su-admin`. Agrega solo el grupo; las cuentas autorizadas deben añadirse explícitamente. |
| `02-ssh-bastion.sh` | Deshabilita root/password/keyboard-interactive, permite clave pública y limita SSH al grupo `ssh-admin`; valida con `sshd -t` y recarga el servicio. Se niega a aplicar si no encuentra una clave autorizada en `/home`. |
| `04-auditd-rules.sh` | Audita archivos de identidad/sudoers, ejecuciones privilegiadas y cambios de hora. La regla `-e 2` vuelve inmutable la política hasta reiniciar. |
| `05-service-isolation.sh` | Sandbox systemd de Apache y perfil AppArmor específico. |

Las referencias a CIS describen alineación de controles, no certifican cumplimiento. Lynis debe compararse entre baselines tomadas en la misma VM; no contra el contenedor de Fase B.