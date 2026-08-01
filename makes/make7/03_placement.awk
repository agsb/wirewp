# ==============================================================================
# MÓDULO 03: POSICIONADOR FÍSICO FORCE-DIRECTED & SNAP-TO-GRID (03_placement.awk)
# ==============================================================================

function get_pin_grid_coords(part, pin_id, out_coords,    model, type, total_pins, row_w, cx, cy, p_num, side, idx) {
    model = COMP_INST_MODEL[part]
    type = COMP_LIB_TYPE[model]
    total_pins = COMP_LIB_PINS[model]
    row_w = COMP_LIB_ROW_W[model]
    
    cx = COMP_POS_X[part]
    cy = COMP_POS_Y[part]
    p_num = pin_id + 0 
    
    if (type == "DIP") {
        side = (p_num <= total_pins / 2) ? 0 : 1
        if (side == 0) {
            out_coords["X"] = cx
            out_coords["Y"] = cy + (p_num - 1)
        } else {
            idx = total_pins - p_num
            out_coords["X"] = cx + row_w
            out_coords["Y"] = cy + idx
        }
    } else if (type == "SIL" || type == "CON") {
        out_coords["X"] = cx
        out_coords["Y"] = cy + (p_num - 1)
    } else if (type == "DSC") {
        # Para capacitores DSC com 0.2" de espaçamento, o pino 1 fica em (X, Y) e o pino 2 fica em (X, Y+2)
        if (p_num == 1) {
            out_coords["X"] = cx
            out_coords["Y"] = cy
        } else {
            out_coords["X"] = cx
            out_coords["Y"] = cy + 2
        }
    } else {
        out_coords["X"] = cx
        out_coords["Y"] = cy
    }
}

function run_force_directed_placement(    iter, u, v, net, i, j, fx, fy, dx, dy, dist, force, overlap, clearance_furos, seed, pins_u, pins_v, body_h_u, body_h_v, member_u, member_v, sep_u, sep_v, comp_u, comp_v, model_u, type_u, cap_id) {
    if (!BOARD_MAX_W) BOARD_MAX_W = 80
    if (!BOARD_MAX_H) BOARD_MAX_H = 60
    clearance_furos = 3
    
    seed = 123456789
    
    for (u in COMP_INST_MODEL) {
        if (COMP_PLACEMENT_MODE[u] == "FIXED") {
            COMP_POS_X[u] = int(COMP_ANCHOR_X[u])
            COMP_POS_Y[u] = int(COMP_ANCHOR_Y[u])
        } else {
            seed = (seed * 31337 + 17) % 1000003
            COMP_POS_X[u] = 10 + (seed % (BOARD_MAX_W - 25))
            seed = (seed * 31337 + 17) % 1000003
            COMP_POS_Y[u] = 10 + (seed % (BOARD_MAX_H - 25))
        }
    }
    
    for (iter = 1; iter <= 30; iter++) {
        for (u in COMP_INST_MODEL) {
            if (COMP_PLACEMENT_MODE[u] == "FIXED") continue 
            fx = 0; fy = 0
            
            for (v in COMP_INST_MODEL) {
                if (u == v) continue 
                dx = COMP_POS_X[u] - COMP_POS_X[v]
                dy = COMP_POS_Y[u] - COMP_POS_Y[v]
                dist = sqrt(dx*dx + dy*dy) + 0.001
                
                if (dist < 18) { 
                    force = 60.0 / (dist * dist + 0.01)
                    fx += (dx / dist) * force
                    fy += (dy / dist) * force
                }
            }
            
            for (net in NET_MEMBERS_COUNT) {
                for (i = 1; i <= NET_MEMBERS_COUNT[net]; i++) {
                    member_u = NET_MEMBERS[net, i]
                    sep_u = index(member_u, ";")
                    comp_u = substr(member_u, 1, sep_u - 1)
                    
                    if (comp_u == u) {
                        for (j = 1; j <= NET_MEMBERS_COUNT[net]; j++) {
                            member_v = NET_MEMBERS[net, j]
                            sep_v = index(member_v, ";")
                            comp_v = substr(member_v, 1, sep_v - 1)
                            
                            if (comp_v != u) {
                                dx = COMP_POS_X[comp_v] - COMP_POS_X[u]
                                dy = COMP_POS_Y[comp_v] - COMP_POS_Y[u]
                                fx += dx * 0.05
                                fy += dy * 0.05
                            }
                        }
                    }
                }
            }
            
            COMP_POS_X[u] += fx
            COMP_POS_Y[u] += fy
            
            if (COMP_POS_X[u] < 5) COMP_POS_X[u] = 5
            if (COMP_POS_X[u] > BOARD_MAX_W - 12) COMP_POS_X[u] = BOARD_MAX_W - 12
            if (COMP_POS_Y[u] < 5) COMP_POS_Y[u] = 5
            if (COMP_POS_Y[u] > BOARD_MAX_H - 15) COMP_POS_Y[u] = BOARD_MAX_H - 15
        }
    }
    
    for (u in COMP_INST_MODEL) {
        if (COMP_PLACEMENT_MODE[u] == "FIXED") continue
        COMP_POS_X[u] = int(COMP_POS_X[u] + 0.5)
        COMP_POS_Y[u] = int(COMP_POS_Y[u] + 0.5)
    }
    
    for (iter = 1; iter <= 10; iter++) {
        for (u in COMP_INST_MODEL) {
            if (COMP_PLACEMENT_MODE[u] == "FIXED") continue
            overlap = 1
            while (overlap == 1) {
                overlap = 0
                for (v in COMP_INST_MODEL) {
                    if (u == v) continue
                    
                    pins_u = COMP_LIB_PINS[COMP_INST_MODEL[u]]
                    pins_v = COMP_LIB_PINS[COMP_INST_MODEL[v]]
                    body_h_u = (pins_u / 2) > 0 ? (pins_u / 2) : pins_u
                    body_h_v = (pins_v / 2) > 0 ? (pins_v / 2) : pins_v
                    
                    dx = abs(COMP_POS_X[u] - COMP_POS_X[v])
                    dy = abs(COMP_POS_Y[u] - COMP_POS_Y[v])
                    
                    if (dx < (clearance_furos + 3) && dy < (body_h_v + clearance_furos)) {
                        COMP_POS_Y[u] += (body_h_v + clearance_furos)
                        overlap = 1
                        
                        if (COMP_POS_Y[u] > BOARD_MAX_H - 15) {
                            COMP_POS_Y[u] = 5
                            COMP_POS_X[u] += 8
                        }
                    }
                }
            }
        }
    }

    # ==========================================================================
    # GERADOR DE CAPACITORES: Passo mecânico padronizado de 0.2" (2 furos)
    # ==========================================================================
    for (u in COMP_INST_MODEL) {
        model_u = COMP_INST_MODEL[u]
        type_u = COMP_LIB_TYPE[model_u]
        
        if (type_u == "DIP" && u !~ /^C_/) {
            cap_id = "C_" u
            COMP_INST_MODEL[cap_id] = "CAP_100NF"
            COMP_PLACEMENT_MODE[cap_id] = "FIXED"
            
            # Aloca a origem do corpo do capacitor 1 furo à esquerda do CI alvo
            COMP_POS_X[cap_id] = COMP_POS_X[u] - 1
            COMP_POS_Y[cap_id] = COMP_POS_Y[u]
            
            if (COMP_POS_X[cap_id] < 2) {
                COMP_POS_X[cap_id] = COMP_POS_X[u] + COMP_LIB_ROW_W[model_u] + 1
            }
            
            NET_MAP[cap_id, 1] = "VCC"
            NET_MAP[cap_id, 2] = "GND"
            
            DB_NAME_TO_PIN["CAP_100NF", 1] = "1"
            DB_NAME_TO_PIN["CAP_100NF", 2] = "2"
            
            NET_MEMBERS["VCC", ++NET_MEMBERS_COUNT["VCC"]] = cap_id ";1"
            NET_MEMBERS["GND", ++NET_MEMBERS_COUNT["GND"]] = cap_id ";2"
        }
    }
}

function abs(v) { return v < 0 ? -v : v }

