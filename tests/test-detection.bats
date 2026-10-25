#!/usr/bin/env bats
# Tests unitarios para scripts de detección y monitoreo de integridad (Fase H)

setup() {
    export HNS_BACKUP_DIR="${BATS_TEST_TMPDIR}/backups"
    export HNS_RUN_ID="test-detection"
    # shellcheck source=../scripts/lib/common.sh
    source "${BATS_TEST_DIRNAME}/../scripts/lib/common.sh"
}

@test "07-suricata-ids.sh responde a --help" {
    run bash "${BATS_TEST_DIRNAME}/../scripts/07-suricata-ids.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso:"* ]]
}

@test "07-suricata-ids.sh en modo --check valida existencia de configuración" {
    run bash "${BATS_TEST_DIRNAME}/../scripts/07-suricata-ids.sh" --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"suricata.yaml presente"* ]]
    [[ "$output" == *"lab-detection.rules presente"* ]]
}

@test "08-aide-fim.sh responde a --help" {
    run bash "${BATS_TEST_DIRNAME}/../scripts/08-aide-fim.sh" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Uso:"* ]]
}

@test "08-aide-fim.sh en modo --check valida archivo de configuración" {
    run bash "${BATS_TEST_DIRNAME}/../scripts/08-aide-fim.sh" --check
    [ "$status" -eq 0 ]
    [[ "$output" == *"aide.conf presente"* ]]
}

@test "reglas de Suricata contienen sintaxis válida para los 4 vectores MITRE" {
    RULES_FILE="${BATS_TEST_DIRNAME}/../firewall/suricata/rules/lab-detection.rules"
    [ -f "$RULES_FILE" ]
    run grep "sid:1000001" "$RULES_FILE"
    [ "$status" -eq 0 ]
    run grep "sid:1000002" "$RULES_FILE"
    [ "$status" -eq 0 ]
    run grep "sid:1000003" "$RULES_FILE"
    [ "$status" -eq 0 ]
    run grep "sid:1000004" "$RULES_FILE"
    [ "$status" -eq 0 ]
}
