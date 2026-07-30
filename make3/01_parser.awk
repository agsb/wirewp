# ==============================================================================
# MÓDULO 1: PARSER E CONSTRUÇÃO DAS ESTRUTURAS DE DADOS
# ==============================================================================

BEGIN {
    FS = " " # Separador de campos por espaço
    ERR_COUNT = 0
}

# --- PROCESSAMENTO DO ARQUIVO DE COMPONENTES ---
FILENAME ~ /componentes\.csv$/ {
    if ($1 == "" || $1 ~ /^#/) next; # Pula linhas vazias ou comentários

    pack = $1
    type = $2
    pins = $3
    name = $4

    if (type == "DIP" || type == "CON" || type == "SIL" || type == "DSC") {
        lib_type[pack] = type
        lib_pins_count[pack] = pins
        lib_width[pack] = name  # Distância entre fileiras (em 0.1 inch)
        current_pack = pack
    } 
    else if (type == "PIN") {
        if (current_pack == "") {
            print "ERRO [PARSER]: Pino definido sem componente associado antes: " $0 > "/dev/stderr"
            ERR_COUNT++
            next
        }
        # Estrutura: lib_pin_name[pack, pin_number] = pin_name
        lib_pin_name[current_pack, pins] = name
    }
    next
}

# --- PROCESSAMENTO DO NETLIST ---
FILENAME ~ /netlist\.csv$/ {
    if ($1 == "" || $1 ~ /^#/) next;

    part = $1
    pin  = $2
    wire = $3

    # Define dimensões da placa
    if (part == "BRD") {
        board_w = pin
        board_h = wire
        next
    }

    # Instanciação de componente
    if (part == "COB") {
        inst_pack[pin] = wire # pin = ID no circuito (ex: U1), wire = Commercial Pack (ex: 74HC00)
        inst_count++
        inst_list[inst_count] = pin
        next
    }

    # Configurações e Conexões de pinos dos componentes
    if (pin == "0") {
        if (wire ~ /^anchor_/) {
            split(wire, coords, "_")
            inst_status[part] = "ANCHOR"
            inst_x[part] = coords[2]
            inst_y[part] = coords[3]
        } else if (wire == "dynamic") {
            inst_status[part] = "DYNAMIC"
            # Posição inicial no centro do grid para o algoritmo de placement
            inst_x[part] = int(board_w / 2)
            inst_y[part] = int(board_h / 2)
        }
    } else {
        # Adiciona conexão à Netlist
        net_name = wire
        if (!(net_name in net_exists)) {
            net_exists[net_name] = 1
            net_count++
            net_list[net_count] = net_name
        }
        
        # Incrementa contador de nós da net
        net_node_count[net_name]++
        idx = net_node_count[net_name]
        
        # Guarda a referência do nó da rede
        net_node_part[net_name, idx] = part
        net_node_pin[net_name, idx]  = pin
        
        # Mapeamento reverso (Pino -> Net)
        pin_to_net[part, pin] = net_name
    }
    next
}

