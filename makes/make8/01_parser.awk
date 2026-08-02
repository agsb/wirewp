# ==============================================================================
# MÓDULO 01: PARSER DE NETLIST E BIBLIOTECA DINÂMICA (01_parser.awk)
# ==============================================================================

function get_priority(net_name) {
    if (net_name ~ /^(VBAT|VREG|VCC|VDD|VSS|GND|DGND|VREF|AGND)$/) return 1
    if (net_name ~ /^(D[0-9]+|DATA.*)$/) return 2
    if (net_name ~ /^(A[0-9]+|ADDR.*)$/) return 3
    if (net_name ~ /^(CS.*|CE.*|OE.*|WE.*|DS.*|RS.*|CLR.*|CLK.*|WR.*|RD.*|EN.*|RESET)$/) return 4
    if (net_name ~ /^(AN.*)$/) return 5
    if (net_name != "" && net_name != "NC") return 6
    return 7
}

FILENAME !~ /\.awk$/ {
    gsub(/\r/, "", $0)
    if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) next
    
    # componentes.csv: Definição Dinâmica de Tipos, Pinos e Pegadas
    if (NF == 4 && ($2 == "DIP" || $2 == "CON" || $2 == "SIL" || $2 == "DSC")) {
        pack = $1; type = $2; pins = $3; name = $4
        COMP_LIB_TYPE[pack] = type
        COMP_LIB_PINS[pack] = pins
        COMP_LIB_ROW_W[pack] = name
        next
    }
    
    # componentes.csv: Registro dos Pinos de Sinal/Datasheet do Componente
    if (NF == 4 && $2 == "PIN") {
        pack = $1; pin_num = $3; pin_name = $4
        DB_PIN_TO_NAME[pack, pin_num] = pin_name
        DB_NAME_TO_PIN[pack, pin_name] = pin_num
        # Salva o mapeamento de pinos brutos para buscas reversas em renderizações gráficas
        RAW_PIN_DB[pack, pin_num] = pin_name
        next
    }

    # netlist.csv: Processamento de Conectividade e Geometria da Placa
    if (NF == 3) {
        part = $1; pin_id = $2; wire = $3

        if (part == "BRD") {
            BOARD_MAX_W = pin_id; BOARD_MAX_H = wire
        } else if (part == "COB") {
            COMP_INST_MODEL[pin_id] = wire
            COMP_COUNT++
        } else {
            if (pin_id == "0") {
                if (wire ~ /^anchor_/) {
                    anchor_str = substr(wire, 8)
                    sub_pos = index(anchor_str, "_")
                    COMP_ANCHOR_X[part] = substr(anchor_str, 1, sub_pos - 1) + 0
                    COMP_ANCHOR_Y[part] = substr(anchor_str, sub_pos + 1) + 0
                    COMP_PLACEMENT_MODE[part] = "FIXED"
                } else {
                    COMP_PLACEMENT_MODE[part] = "DYNAMIC"
                }
            } else {
                NET_MAP[part, pin_id] = wire
                if (wire != "NC" && wire != "") {
                    NET_MEMBERS[wire, ++NET_MEMBERS_COUNT[wire]] = part ";" pin_id
                    NET_PRIORITY[wire] = get_priority(wire)
                }
            }
        }
        next
    }
}

