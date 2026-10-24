#!/usr/bin/env bash
# Genera un reporte comparativo antes/después del hardening.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT="${ROOT_DIR}/evidencias/reporte.md"

antes_dir="$(find "${ROOT_DIR}/evidencias/antes" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"
despues_dir="$(find "${ROOT_DIR}/evidencias/despues" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | tail -1)"

{
    printf '# Reporte de auditoría antes/después — Hardening de Red\n\n'
    printf 'Generado: %s UTC\n\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    printf '## Resumen\n\n'

    if [[ -z "$antes_dir" ]]; then
        printf 'No se encontró una auditoría "antes" en evidencias/antes/.\n\n'
    else
        printf 'Antes: %s\n\n' "$antes_dir"
    fi

    if [[ -z "$despues_dir" ]]; then
        printf 'No se encontró una auditoría "después" en evidencias/despues/. Ejecutá make audit primero.\n\n'
    else
        printf 'Después: %s\n\n' "$despues_dir"
    fi

    if [[ -n "$antes_dir" && -n "$despues_dir" ]]; then
        printf '## Comparativa de puertos (Nmap TCP SYN)\n\n'
        printf '| Puerto | Antes | Después |\n'
        printf '|--------|-------|---------|\n'

        for port in 21 22 80; do
            a="$(grep -E "^${port}/tcp" "${antes_dir}/nmap-tcp.txt" 2>/dev/null | awk '{print $2}' || echo '—')"
            d="$(grep -E "^${port}/tcp" "${despues_dir}/nmap-tcp.txt" 2>/dev/null | awk '{print $2}' || echo '—')"
            printf '| %s | %s | %s |\n' "$port" "$a" "$d"
        done

        printf '\n## ssh-audit\n\n'
        if [[ -f "${antes_dir}/ssh-audit.txt" && -f "${despues_dir}/ssh-audit.txt" ]]; then
            printf '| Indicador | Antes | Después |\n|-----------|-------|---------|\n'
            a_algs="$(grep -cE '^(ssh-rsa|ssh-ed25519|ecdsa-sha2)' "${antes_dir}/ssh-audit.txt" 2>/dev/null || echo 0)"
            d_algs="$(grep -cE '^(ssh-rsa|ssh-ed25519|ecdsa-sha2)' "${despues_dir}/ssh-audit.txt" 2>/dev/null || echo 0)"
            printf '| Algoritmos de host key | %s | %s |\n' "$a_algs" "$d_algs"
        fi

        printf '\n## Nikto\n\n'
        if [[ -f "${antes_dir}/nikto.txt" && -f "${despues_dir}/nikto.txt" ]]; then
            a_vuln="$(grep -cE 'OSVDB|CVE-' "${antes_dir}/nikto.txt" 2>/dev/null || echo 0)"
            d_vuln="$(grep -cE 'OSVDB|CVE-' "${despues_dir}/nikto.txt" 2>/dev/null || echo 0)"
            printf '| Hallazgos Nikto | %s | %s |\n' "$a_vuln" "$d_vuln"
        fi

        printf '\n## Conclusión\n\n'
        printf 'La comparación muestra la reducción de la superficie de ataque tras aplicar\n'
        printf 'los scripts de bastionado (Fases C y D). Los detalles completos están en\n'
        printf 'evidencias/antes/ y evidencias/despues/.\n\n'
    fi

    printf '%s\n' '---'
    printf '*Reporte generado por make report del laboratorio hardening-network-security.*\n'
} > "$REPORT"

printf 'Reporte escrito en %s\n' "$REPORT"
