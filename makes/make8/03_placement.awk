# ==============================================================================
# MÓDULO 03: POSICIONADOR DE MÁXIMA COMPACTAÇÃO QUANTIZADO (03_placement.awk)
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

function run_force_directed_placement(    iter, u, v, net, i, j, fx, fy, dx, dy, dist, force, overlap, seed, pins_u, pins_v, body_h_u, body_h_v, row_w_u, row_w_v, member_u, member_v, sep_u, sep_v, comp_u, comp_v, model_u, type_u, cap_id, gravity_x, gravity_y, gravity_pull, max_x_box, max_y_hole) {
    clearance_furos = 4 
    
    BOARD_MAX_W = 120
    BOARD_MAX_H = 120
    
    gravity_x = 4; gravity_y = 4; gravity_pull = 0.35 
    seed = 123456789
    
    # 1. QUANTIZAÇÃO INICIAL: Força as sementes diretamente nos furos inteiros da grade
    for (u in COMP_INST_MODEL) {
        if (COMP_PLACEMENT_MODE[u] == "FIXED") {
            COMP_POS_X[u] = int(COMP_ANCHOR_X[u])
            COMP_POS_Y[u] = int(COMP_ANCHOR_Y[u])
        } else {
            seed = (seed * 31337 + 17) % 1000003; COMP_POS_X[u] = int(4 + (seed % 6))
            seed = (seed * 31337 + 17) % 1000003; COMP_POS_Y[u] = int(4 + (seed % 6))
        }
    }
    
    # Solver de forças analítico
    for (iter = 1; iter <= 45; iter++) {
        for (u in COMP_INST_MODEL) {
            if (COMP_PLACEMENT_MODE[u] == "FIXED") continue 
            fx = 0; fy = 0
            
            dx = gravity_x - COMP_POS_X[u]; dy = gravity_y - COMP_POS_Y[u]
            fx += dx * gravity_pull; fy += dy * gravity_pull
            
            for (v in COMP_INST_MODEL) {
                if (u == v) continue 
                dx = COMP_POS_X[u] - COMP_POS_X[v]; dy = COMP_POS_Y[u] - COMP_POS_Y[v]
                dist = sqrt(dx*dx + dy*dy) + 0.001
                if (dist < 12) { force = 35.0 / (dist * dist + 0.01); fx += (dx / dist) * force; fy += (dy / dist) * force }
            }
            
            for (net in NET_MEMBERS_COUNT) {
                for (i = 1; i <= NET_MEMBERS_COUNT[net]; i++) {
                    member_u = NET_MEMBERS[net, i]; sep_u = index(member_u, ";"); comp_u = substr(member_u, 1, sep_u - 1)
                    if (comp_u == u) {
                        for (j = 1; j <= NET_MEMBERS_COUNT[net]; j++) {
                            member_v = NET_MEMBERS[net, j]; sep_v = index(member_v, ";"); comp_v = substr(member_v, 1, sep_v - 1)
                            if (comp_v != u) { dx = COMP_POS_X[comp_v] - COMP_POS_X[u]; dy = COMP_POS_Y[comp_v] - COMP_POS_Y[u]; fx += dx * 0.04; fy += dy * 0.04 }
                        }
                    }
                }
            }
            
            # 2. INTEGRAÇÃO INTEGRAL: Trunca os passos acumulados impedindo posições em ponto flutuante
            COMP_POS_X[u] = int(COMP_POS_X[u] + fx + 0.5)
            COMP_POS_Y[u] = int(COMP_POS_Y[u] + fy + 0.5)
            
            if (COMP_POS_X[u] < 3) COMP_POS_X[u] = 3
            if (COMP_POS_Y[u] < 3) COMP_POS_Y[u] = 3
        }
    }
    
    # Proteção estrita pós-solver
    for (u in COMP_INST_MODEL) {
        COMP_POS_X[u] = int(COMP_POS_X[u] + 0.5)
        COMP_POS_Y[u] = int(COMP_POS_Y[u] + 0.5)
    }
    
    # 3. CORRETOR MATRICIAL ESCALAR: Resolve colisões físicas usando apenas offsets do grid universal
    for (iter = 1; iter <= 20; iter++) {
        for (u in COMP_INST_MODEL) {
            if (COMP_PLACEMENT_MODE[u] == "FIXED" || u ~ /^C_/) continue
            overlap = 1
            while (overlap == 1) {
                overlap = 0
                for (v in COMP_INST_MODEL) {
                    if (u == v || v ~ /^C_/) continue
                    pins_u = COMP_LIB_PINS[COMP_INST_MODEL[u]]; pins_v = COMP_LIB_PINS[COMP_INST_MODEL[v]]
                    body_h_v = int((pins_v / 2) > 0 ? (pins_v / 2) : pins_v)
                    row_w_v = int(COMP_LIB_ROW_W[COMP_INST_MODEL[v]] + 0); if (row_w_v == 0) row_w_v = 1
                    
                    dx = int(abs(COMP_POS_X[u] - COMP_POS_X[v]))
                    dy = int(abs(COMP_POS_Y[u] - COMP_POS_Y[v]))
                    
                    if (dx < (row_w_v + 1) && dy < (body_h_v + 1)) {
                        COMP_POS_Y[u] = int(COMP_POS_Y[u] + body_h_v + 1)
                        overlap = 1
                        if (COMP_POS_Y[u] > BOARD_MAX_H - 12) { 
                            COMP_POS_Y[u] = 3
                            COMP_POS_X[u] = int(COMP_POS_X[u] + row_w_v + 1)
                        }
                    }
                }
            }
        }
    }

    # Posicionamento e fixação rígida quantizada de capacitores
    for (u in COMP_INST_MODEL) {
        model_u = COMP_INST_MODEL[u]; type_u = COMP_LIB_TYPE[model_u]
        if (type_u == "DIP" && u !~ /^C_/) {
            cap_id = "C_" u; COMP_INST_MODEL[cap_id] = "CAPACITOR"; COMP_PLACEMENT_MODE[cap_id] = "FIXED"
            COMP_POS_X[cap_id] = int(COMP_POS_X[u] - 1)
            COMP_POS_Y[cap_id] = int(COMP_POS_Y[u])
            if (COMP_POS_X[cap_id] < 1) COMP_POS_X[cap_id] = int(COMP_POS_X[u] + COMP_LIB_ROW_W[model_u] + 1)
            NET_MAP[cap_id, 1] = "VCC"; NET_MAP[cap_id, 2] = "GND"
            NET_MEMBERS["VCC", ++NET_MEMBERS_COUNT["VCC"]] = cap_id ";1"; NET_MEMBERS["GND", ++NET_MEMBERS_COUNT["GND"]] = cap_id ";2"
        }
    }

    # Bounding Box final
    max_x_box = 0; max_y_hole = 0
    for (u in COMP_INST_MODEL) {
        model_u = COMP_INST_MODEL[u]; pins_u = COMP_LIB_PINS[model_u]
        body_h_u = int((pins_u / 2) > 0 ? (pins_u / 2) : pins_u)
        row_w_u = int(COMP_LIB_ROW_W[model_u] + 0); if (row_w_u == 0) row_w_u = 2
        
        if (int(COMP_POS_X[u] + row_w_u) > max_x_box) max_x_box = int(COMP_POS_X[u] + row_w_u)
        if (int(COMP_POS_Y[u] + body_h_u) > max_y_hole) max_y_hole = int(COMP_POS_Y[u] + body_h_u)
    }
    BOARD_MAX_W = int(max_x_box + 3)
    BOARD_MAX_H = int(max_y_hole + 3)
}

function abs(v) { return v < 0 ? -v : v }

