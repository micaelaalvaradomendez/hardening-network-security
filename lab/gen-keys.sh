#!/usr/bin/env bash
# Genera el par de claves SSH del laboratorio (nodo admin -> target).
# Idempotente: si la clave ya existe no la regenera. Nunca se commitea (ver .gitignore).
set -euo pipefail

SECRETS_DIR="$(cd "$(dirname "$0")" && pwd)/.secrets"
KEY="${SECRETS_DIR}/admin_ed25519"

mkdir -p "$SECRETS_DIR"
chmod 700 "$SECRETS_DIR"

if [[ -f "$KEY" ]]; then
    echo "[OK]    Clave del laboratorio ya existe: ${KEY}"
    exit 0
fi

ssh-keygen -q -t ed25519 -N '' -C "lab-admin@hardening-network-security" -f "$KEY"
echo "[OK]    Clave generada: ${KEY}"
