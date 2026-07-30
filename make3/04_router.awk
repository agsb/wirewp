# ==============================================================================
# MÓDULO 4: ROTEAMENTO ORTOGONAL, STACKING E PAR TRANÇADO (TWIST)
# ==============================================================================

function abs(v) { return v < 0 ? -v : v }

# Classificação por RegEx para priorização
function get_net_priority(net) {
    if (net ~ /^(VBAT|VREG|VCC|VDD|VSS|GND|DGND|AGND)$/) return 1
    if (net ~ /^(D[0-9]+|DATA.*)$/) return 2
    if (net ~ /^(A[0-9]+|ADDR.*)$/) return 3
    if (net ~ /^(CS|CLK|WR|RD|EN|RESET)$/) return 4
    if (net ~ /^(ANALOG|AIN.*)$/) return 5
    return 6
}

function run_router() {
    route_total = 0

    # Ordena o processamento por Níveis de Prioridade (1 a 6)
    for (prio = 1; prio <= 6; prio++) {
        for (n = 1; n <= net_count; n++) {
            net = net_list[n]
            if (net_node_count[net] <= 1) continue # Ignora pino solto/desconectado (Nível 7)
            if (get_net_priority(net) != prio) continue

            # --- ALGORITMO NEAREST-NEIGHBOR (DAISY-CHAIN TSP) ---
            # Flag para nós visitados na heurística
            for (k = 1; k <= net_node_count[net]; k++) visited[k] = 0

            curr_idx = 1
            visited[curr_idx] = 1

            for (step = 1; step < net_node_count[net]; step++) {
                best_dist = 999999
                next_idx = -1

                p1 = net_node_part[net, curr_idx]
                x1 = inst_x[p1]; y1 = inst_y[p1]

                # Encontra o pino não visitado mais próximo no grid
                for (j = 1; j <= net_node_count[net]; j++) {
                    if (!visited[j]) {
                        p2 = net_node_part[net, j]
                        x2 = inst_x[p2]; y2 = inst_y[p2]
                        dist = abs(x1 - x2) + abs(y1 - y2) # Distância Manhattan

                        if (dist < best_dist) {
                            best_dist = dist
                            next_idx = j
                        }
                    }
                }

                if (next_idx != -1) {
                    visited[next_idx] = 1
                    p2 = net_node_part[net, next_idx]
                    pin1 = net_node_pin[net, curr_idx]
                    pin2 = net_node_pin[net, next_idx]

                    # --- GESTÃO DE EMPILHAMENTO (PIN STACKING & OVERWRAP) ---
                    pin_stack[p1, pin1]++
                    pin_stack[p2, pin2]++

                    z_level1 = pin_stack[p1, pin1]
                    z_level2 = pin_stack[p2, pin2]

                    # Registra Rota
                    route_total++
                    routes[route_total, "net"]      = net
                    routes[route_total, "prio"]     = prio
                    routes[route_total, "from"]     = p1 "-" pin1
                    routes[route_total, "to"]       = p2 "-" pin2
                    routes[route_total, "grid_len"] = best_dist
                    routes[route_total, "z1"]       = z_level1
                    routes[route_total, "z2"]       = z_level2

                    # --- ACOPLAMENTO PAR TRANÇADO (NÍVEIS 4 E 5) ---
                    if (prio == 4 || prio == 5) {
                        routes[route_total, "is_twist"] = 1
                    } else {
                        routes[route_total, "is_twist"] = 0
                    }

                    curr_idx = next_idx
                }
            }
        }
    }
}


