# shellcheck shell=bash
# Configuración de rutas de cada nodo, a partir de variables definidas en docker-compose.yml.
# Ningún nodo tiene camino directo a otra zona: todo el tráfico entre zonas pasa por `fw`.
#
#   LAB_DEFAULT_GW  Reemplaza la ruta por defecto (nodos de dmz y mgmt, detrás del firewall).
#   LAB_ROUTES      Redes separadas por coma que se alcanzan vía LAB_ROUTE_VIA (nodos de wan).
#   LAB_ROUTE_VIA   Gateway para LAB_ROUTES.

lab_net_setup() {
    if [[ -n "${LAB_DEFAULT_GW:-}" ]]; then
        ip route replace default via "$LAB_DEFAULT_GW"
    fi

    local net routes=()
    IFS=',' read -ra routes <<<"${LAB_ROUTES:-}"
    for net in "${routes[@]}"; do
        ip route replace "$net" via "$LAB_ROUTE_VIA"
    done

    echo "[lab-net] $(hostname): rutas configuradas"
    ip -brief address show | grep -v '^lo'
    ip route show
}
