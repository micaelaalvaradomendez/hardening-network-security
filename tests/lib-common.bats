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
