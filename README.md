# Hardening Linux & Auditoría de Redes

[![ci](https://github.com/micaelaalvaradomendez/hardening-network-security/actions/workflows/ci.yml/badge.svg)](https://github.com/micaelaalvaradomendez/hardening-network-security/actions/workflows/ci.yml)
![Debian](https://img.shields.io/badge/Debian-13-A81D33?logo=debian&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-blue)

Laboratorio reproducible de bastionado de servidores Linux y seguridad de redes: scripts Bash idempotentes con controles alineados a **CIS Debian Linux Benchmark**, filtrado stateful con **nftables**, trazabilidad con **auditd**, protección contra fuerza bruta con **fail2ban** y un **informe de pentesting ético** que mide la reducción de la superficie de ataque antes y después de la remediación.

Surge del *Diplomado Universitario en Administración de Redes Linux con Orientación en Ciberseguridad y Ethical Hacking* (UTN-FRD).

> **Estado:** en desarrollo. Ver [hoja de ruta](#hoja-de-ruta).

---

## Topología

![Topología del laboratorio](diagramas/topologia-laboratorio.svg)

- **Red y pentesting** → Docker Compose (`lab/compose/`). Cada zona es una red macvlan aislada: todo tráfico entre zonas atraviesa `fw` y el lab no depende del firewall del host. Detalle en [docs/arquitectura-red.md](docs/arquitectura-red.md).
- **Hardening de sistema operativo** (auditd, módulos de kernel, sysctl, AppArmor) → VM Debian 13 con Vagrant/libvirt (`lab/vm/`), porque un contenedor comparte el kernel del host. Los scripts omiten contenedores y bare metal; solo aplican dentro de una VM detectada.

## Uso rápido

```bash
make help       # lista de targets
make lab-up     # genera claves y levanta el laboratorio
make test-lab   # verifica ruteo, servicios y aislamiento entre zonas
make baseline   # Nmap, ssh-audit, Nikto y Lynis -> evidencias/antes/<run-id>/
make exploit-demo # prueba acotada de Hydra y FTP anónimo -> evidencias/antes/<run-id>/
make vm-up       # levanta Debian 13 con Vagrant + libvirt
make vm-baseline # captura Lynis/SSH antes del hardening
make vm-check    # audita controles sin modificar la VM
make vm-harden   # aplica hardening en la VM (requiere baseline previa)
make vm-down     # apaga la VM
make harden     # aplica el bastionado
make audit      # auditoría posterior -> evidencias/despues/
make report     # comparativa antes/después
make lint test  # shellcheck + bats (corren en contenedores)
make diagram    # renderiza diagramas/ con PlantUML
```

Los scripts de bastionado aceptan `--check` (default, no modifica nada) y `--apply` (aplica con backup previo) y son idempotentes. `baseline.sh` y `exploit-demo.sh` ejecutan auditorías contra el laboratorio y guardan sus salidas.

La Fase B deja intencionalmente expuestos SSH con `root:toor`, FTP anónimo y el listado `/backup/` de Apache. Se ejecutan solo dentro de las redes `internal` del laboratorio; no publiques puertos del target en el host ni reutilices esa contraseña. `make exploit-demo` hace hasta tres intentos SSH con una wordlist de laboratorio pequeña y luego comprueba FTP anónimo.

`make baseline` fija como único objetivo `10.66.10.10` y guarda cada salida bajo `evidencias/antes/<run-id>/`. Nikto se ejecuta desde la imagen oficial `ghcr.io/sullo/nikto:2.6.1`, compartiendo el namespace de red de `attacker`. El código de salida de `ssh-audit` queda en `ssh-audit.status`; un informe válido puede devolver un código distinto de cero cuando detecta algoritmos débiles. Lynis se ejecuta dentro del contenedor target y es solo una referencia: no se debe comparar su índice con una auditoría de la VM de Fase C.

Para la Fase C necesitás Vagrant, el plugin `vagrant-libvirt`, QEMU/KVM y libvirt. El flujo esperado es `make vm-up`, `make vm-baseline`, `make vm-check` y, después de revisar la baseline, `make vm-harden`. La VM comparte el repo en `/workspace` vía rsync; las evidencias se escriben en el host bajo `evidencias/vm/antes/`. Para medir el estado posterior, usa `BASELINE_PHASE=despues make vm-baseline`. Los controles del SO se aplican únicamente desde dentro de esa VM; `vm-harden` exige que exista una baseline previa completa.

## Estructura

| Carpeta | Contenido |
|---|---|
| `scripts/` | Bastionado: sistema, SSH, firewall, auditd, aislamiento de servicios. `lib/common.sh` define el contrato común. |
| `firewall/` | `nftables.conf` y `fail2ban/jail.local`. |
| `lab/` | Entorno reproducible: Compose (red) y Vagrant/libvirt (SO). |
| `docs/` | Arquitectura de red, matriz de controles e informe de pentesting. |
| `evidencias/` | Salidas de Nmap, Lynis y ssh-audit antes y después. |
| `tests/` | Batería de verificación con bats-core. |

## Hoja de ruta

- [x] Fase 0 — Esqueleto, contrato de scripts, CI
- [x] Fase A — Topología del laboratorio
- [x] Fase B — Target vulnerable y auditoría baseline
- [ ] Fase C — Hardening de sistema operativo (VM; implementación y validación en curso)
- [ ] Fase D — Filtrado de red y fail2ban
- [ ] Fase E — Verificación y comparativa
- [ ] Fase F — Informe de pentesting

## Aviso de uso ético

Este repositorio es material educativo. Las técnicas de reconocimiento y explotación se ejecutan **exclusivamente contra los nodos del laboratorio** definidos acá. Usarlas contra sistemas sin autorización expresa y por escrito es ilegal. Todas las direcciones IP son de laboratorio.

## Licencia

[MIT](LICENSE) · Las referencias a CIS Benchmarks citan solo identificadores de control; el texto de los benchmarks pertenece al Center for Internet Security.
