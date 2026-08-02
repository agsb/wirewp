# ==============================================================================
# MÓDULO 03: POSICIONADOR DE GRADE DISCRETA - ZERO SOBREPOSIÇÃO (03_placement.awk)
# ==============================================================================

function get_pin_grid_coords(part, pin_id, out_coords,    model, type, total_pins, row_w, cx, cy, p_num, side, idx) {
    model = COMP_INST_MODEL[part]
    type = COMP_LIB_TYPE[model]
    total_pins = COMP_LIB_PINS[model]
    row_w = int(COMP_LIB_ROW_W[model])
    
    cx = int(COMP_POS_X[part])
    cy = int(COMP_POS_Y[part])
    p_num = pin_id + 0 
    
    if (type == "DIP") {
        side = (p_num <= total_pins / 2) ? 0 : 1
        if (side == 0) {
            out_coords["X"] = cx; out_coords["Y"] = cy + (p_num - 1)
        } else {
            idx = total_pins - p_num; out_coords["X"] = cx + row_w; out_coords["Y"] = cy + idx
        }
    } else if (type == "SIL" || type == "CON") {
        out_coords["X"] = cx; out_coords["Y"] = cy + (p_num - 1)
    } else if (type == "DSC" || model == "CAPACITOR") {
        if (p_num == 1) {
            out_coords["X"] = cx; out_coords["Y"] = cy
        } else {
            out_coords["X"] = cx; out_coords["Y"] = cy + 2
        }
    } else {
        out_coords["X"] = cx; out_coords["Y"] = cy
    }
}

function run_force_directed_placement(    u, v, model_u, pins_u, body_h_u, row_w_u, start_x, start_y, current_x, current_y, space_free, check_x, check_y, alloc_success, cap_id, clearance_furos) {
    # REGRA DE ENGENHARIA MANDATÓRIA: 0.4 polegadas = 4 furos de isolamento
    clearance_furos = 4
    
    if (BOARD_MAX_W + 0 == 0) BOARD_MAX_W = 80
    if (BOARD_MAX_H + 0 == 0) BOARD_MAX_H = 60
    
    # Limpa o mapa lógico de furos reservados da placa universal
    for (check_x = 1; check_x <= BOARD_MAX_W; check_x++) {
        for (check_y = 1; check_y <= BOARD_MAX_H; check_y++) {
            GRID_RESERVED[check_x, check_y] = 0
        }
    }
    
    # 1. POSICIONAMENTO DE ANCORAGENS FIXAS (Devem ser alocadas primeiro para garantir prioridade de furos)
    for (u in COMP_INST_MODEL) {
        if (u == "" || u == "COB" || u ~ /^C_/) continue
        if (COMP_PLACEMENT_MODE[u] == "FIXED") {
            COMP_POS_X[u] = int(COMP_ANCHOR_X[u])
            COMP_POS_Y[u] = int(COMP_ANCHOR_Y[u])
            
            model_u = COMP_INST_MODEL[u]
            pins_u = COMP_LIB_PINS[model_u]
            body_h_u = int((pins_u / 2) > 0 ? (pins_u / 2) : pins_u)
            row_w_u = int(COMP_LIB_ROW_W[model_u] + 0); if (row_w_u == 0) row_w_u = 2
            
            # Bloqueia a matriz ao redor da âncora incluindo seu buffer de 0.4"
            for (check_x = COMP_POS_X[u] - clearance_furos; check_x < COMP_POS_X[u] + row_w_u + clearance_furos; check_x++) {
                for (check_y = COMP_POS_Y[u] - clearance_furos; check_y < COMP_POS_Y[u] + body_h_u + clearance_furos; check_y++) {
                    if (check_x >= 1 && check_x <= BOARD_MAX_W && check_y >= 1 && check_y <= BOARD_MAX_H) {
                        GRID_RESERVED[check_x, check_y] = 1
                    }
                }
            }
        }
    }
    
    # 2. ALOCAÇÃO MATRICIAL EM CASCATA COMPACTA PARA COMPONENTES DINÂMICOS
    start_x = 4
    start_y = 4
    current_x = start_x
    current_y = start_y
    
    for (u in COMP_INST_MODEL) {
        if (u == "" || u == "COB" || u ~ /^C_/ || COMP_PLACEMENT_MODE[u] == "FIXED") continue
        
        model_u = COMP_INST_MODEL[u]
        pins_u = COMP_LIB_PINS[model_u]
        body_h_u = int((pins_u / 2) > 0 ? (pins_u / 2) : pins_u)
        row_w_u = int(COMP_LIB_ROW_W[model_u] + 0); if (row_w_u == 0) row_w_u = 2
        
        alloc_success = 0
        
        # Varre a grade discreta procurando o primeiro pixel/furo livre que comporte o bloco
        for (current_x = start_x; current_x <= BOARD_MAX_W - (row_w_u + 2); current_x++) {
            for (current_y = start_y; current_y <= BOARD_MAX_H - (body_h_u + 2); current_y++) {
                
                space_free = 1
                
                # Testa se a janela física do chip colide com alguma reserva existente
                for (check_x = current_x; check_x < current_x + row_w_u; check_x++) {
                    for (check_y = current_y; check_y < current_y + body_h_u; check_y++) {
                        if (GRID_RESERVED[check_x, check_y] == 1) {
                            space_free = 0
                            break
                        }
                    }
                    if (space_free == 0) break
                }
                
                # Se o espaço físico e sua vizinhança estiverem limpos, realiza o travamento estável
                if (space_free == 1) {
                    COMP_POS_X[u] = current_x
                    COMP_POS_Y[u] = current_y
                    
                    # Reserva imediatamente os furos do corpo E o buffer periférico de 0.4" (4 furos)
                    for (check_x = current_x - clearance_furos; check_x < current_x + row_w_u + clearance_furos; check_x++) {
                        for (check_y = current_y - clearance_furos; check_y < current_y + body_h_u + clearance_furos; check_y++) {
                            if (check_x >= 1 && check_x <= BOARD_MAX_W && check_y >= 1 && check_y <= BOARD_MAX_H) {
                                GRID_RESERVED[check_x, check_y] = 1
                            }
                        }
                    }
                    alloc_success = 1
                    break
                }
            }
            if (alloc_success == 1) break
        }
        
        # Alarme de contingência mecânica caso o netlist estoure a densidade física da placa universal lida
        if (alloc_success == 0) {
            print "[ERRO ESPACIAL CRÍTICO]: A placa BRD de " BOARD_MAX_W "x" BOARD_MAX_H " furos esgotou! Não há espaço para o chip: " u " (" model_u ")" > "/dev/stderr"
        }
    }
    
    # 3. FIXAÇÃO DOS CAPACITORES: Posicionados de forma adjacente e travados de forma segura
    for (u in COMP_INST_MODEL) {
        model_u = COMP_INST_MODEL[u]; type_u = COMP_LIB_TYPE[model_u]
        if (type_u == "DIP" && u !~ /^C_/) {
            cap_id = "C_" u; COMP_INST_MODEL[cap_id] = "CAPACITOR"; COMP_PLACEMENT_MODE[cap_id] = "FIXED"
            
            # Aloca 1 furo à esquerda do CI real correspondente
            COMP_POS_X[cap_id] = int(COMP_POS_X[u] - 1)
            COMP_POS_Y[cap_id] = int(COMP_POS_Y[u])
            
            # Se colidir com a borda esquerda da placa inteira, rotaciona e joga para o lado direito do chip
            if (COMP_POS_X[cap_id] < 1) {
                COMP_POS_X[cap_id] = int(COMP_POS_X[u] + COMP_LIB_ROW_W[model_u] + 1)
            }
            
            NET_MAP[cap_id, 1] = "VCC"; NET_MAP[cap_id, 2] = "GND"
            NET_MEMBERS["VCC", ++NET_MEMBERS_COUNT["VCC"]] = cap_id ";1"; NET_MEMBERS["GND", ++NET_MEMBERS_COUNT["GND"]] = cap_id ";2"
        }
    }
}

