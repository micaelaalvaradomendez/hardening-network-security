#!/usr/bin/env bats
# Tests de la biblioteca común: modos check/apply, idempotencia y backups.

setup() {
    export HNS_BACKUP_DIR="${BATS_TEST_TMPDIR}/backups"
    export HNS_RUN_ID="test"
    TARGET="${BATS_TEST_TMPDIR}/etc/ejemplo.conf"
    # shellcheck source=../scripts/lib/common.sh
    source "${BATS_TEST_DIRNAME}/../scripts/lib/common.sh"
}

@test "detect_env devuelve un entorno conocido" {
    run detect_env
    [[ "$output" =~ ^(container|vm|bare-metal)$ ]]
}

@test "parse_args rechaza argumentos desconocidos" {
    run parse_args --inexistente
    [ "$status" -ne 0 ]
    [[ "$output" == *"Argumento desconocido"* ]]
}

@test "modo check no escribe archivos" {
    HNS_MODE=check
    apply_file "$TARGET" <<<"clave = valor"
    [ ! -e "$TARGET" ]
    [ "$HNS_CHANGES" -eq 1 ]
}

@test "require_vm omite bare metal para proteger el host" {
    detect_env() { echo bare-metal; }
    run require_vm "sysctl hardening"
    [ "$status" -ne 0 ]
    [[ "$output" == *"requiere una VM dedicada"* ]]
}

@test "require_vm omite contenedor" {
    detect_env() { echo container; }
    run require_vm "auditd rules"
    [ "$status" -ne 0 ]
    [[ "$output" == *"entorno detectado: container"* ]]
}

@test "require_vm permite VM" {
    detect_env() { echo vm; }
    run require_vm "SSH hardening"
    [ "$status" -eq 0 ]
}

@test "ensure_line en check informa sin escribir" {
    run ensure_line "$TARGET" "auth required pam_wheel.so use_uid group=su-admin"
    [ "$status" -eq 0 ]
    [ ! -e "$TARGET" ]
    [[ "$output" == *"agregaría línea"* ]]
}

@test "ensure_line aplica idempotentemente y respalda el archivo" {
    HNS_MODE=apply
    mkdir -p "$(dirname "$TARGET")"
    printf 'original\n' >"$TARGET"
    ensure_line "$TARGET" "auth required pam_wheel.so use_uid group=su-admin"
    ensure_line "$TARGET" "auth required pam_wheel.so use_uid group=su-admin"
    [ "$(grep -Fc 'auth required pam_wheel.so use_uid group=su-admin' "$TARGET")" -eq 1 ]
    [ "$(cat "${HNS_BACKUP_DIR}/test${TARGET}")" = "original" ]
}

@test "modo apply escribe el archivo con el modo pedido" {
    HNS_MODE=apply
    apply_file "$TARGET" 0600 <<<"clave = valor"
    [ "$(cat "$TARGET")" = "clave = valor" ]
    [ "$(stat -c %a "$TARGET")" = "600" ]
}

@test "apply es idempotente: la segunda corrida no cambia nada" {
    HNS_MODE=apply
    apply_file "$TARGET" <<<"clave = valor"
    HNS_CHANGES=0
    run apply_file "$TARGET" <<<"clave = valor"
    [[ "$output" == *"sin cambios"* ]]
    apply_file "$TARGET" <<<"clave = valor"
    [ "$HNS_CHANGES" -eq 0 ]
}

@test "apply hace backup del archivo previo antes de modificarlo" {
    HNS_MODE=apply
    mkdir -p "$(dirname "$TARGET")"
    echo "original" >"$TARGET"
    apply_file "$TARGET" <<<"nuevo"
    [ "$(cat "${HNS_BACKUP_DIR}/test${TARGET}")" = "original" ]
    [ "$(cat "$TARGET")" = "nuevo" ]
}
