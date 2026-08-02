# ==============================================================================
# MÓDULO 04: ROTEADOR DAISY-CHAIN MANHATTAN (04_router.awk)
# ==============================================================================

function run_manhattan_routing(    u_net, total_pts, i, j, visited, current, next_pt, min_d, d, cx, cy, nx, ny, p1, p2, part1, pin1, part2, pin2, split_buffer_1, split_buffer_2) {
    ROUTE_COUNT = 0
    
    for (u_net in NET_MEMBERS_COUNT) {
        total_pts = NET_MEMBERS_COUNT[u_net]
        if (total_pts < 2) continue 
        
        for (i = 1; i <= total_pts; i++) visited[i] = 0
        current = 1; visited[current] = 1
        
        for (i = 1; i < total_pts; i++) {
            min_d = 999999; next_pt = -1
            
            split(NET_MEMBERS[u_net, current], split_buffer_1, ";")
            part1 = split_buffer_1[1]
            pin1  = split_buffer_1[2]
            
            delete p1; get_pin_grid_coords(part1, pin1, p1); cx = p1["X"]; cy = p1["Y"]
            
            for (j = 1; j <= total_pts; j++) {
                if (!visited[j]) {
                    split(NET_MEMBERS[u_net, j], split_buffer_2, ";")
                    part2 = split_buffer_2[1]
                    pin2  = split_buffer_2[2]
                    
                    delete p2; get_pin_grid_coords(part2, pin2, p2); nx = p2["X"]; ny = p2["Y"]
                    
                    # Chamada corrigida com a função abs local declarada abaixo
                    d = abs(cx - nx) + abs(cy - ny)
                    if (d < min_d) { min_d = d; next_pt = j }
                }
            }
            
            if (next_pt != -1) {
                visited[next_pt] = 1; ROUTE_COUNT++
                
                split(NET_MEMBERS[u_net, current], split_buffer_1, ";")
                split(NET_MEMBERS[u_net, next_pt], split_buffer_2, ";")
                
                ROUTES[ROUTE_COUNT, "net"] = u_net
                ROUTES[ROUTE_COUNT, "p1_part"] = split_buffer_1[1]
                ROUTES[ROUTE_COUNT, "p1_pin_num"] = split_buffer_1[2]
                ROUTES[ROUTE_COUNT, "p2_part"] = split_buffer_2[1]
                ROUTES[ROUTE_COUNT, "p2_pin_num"] = split_buffer_2[2]
                
                PIN_Z_LEVEL[split_buffer_1[1], split_buffer_1[2]]++
                PIN_Z_LEVEL[split_buffer_2[1], split_buffer_2[2]]++
                
                ROUTES[ROUTE_COUNT, "p1_z"] = PIN_Z_LEVEL[split_buffer_1[1], split_buffer_1[2]]
                ROUTES[ROUTE_COUNT, "p2_z"] = PIN_Z_LEVEL[split_buffer_2[1], split_buffer_2[2]]
                
                if (PIN_Z_LEVEL[split_buffer_1[1], split_buffer_1[2]] > 2) {
                    print "[ERRO DRC CRÍTICO]: Componente " split_buffer_1[1] " pino " split_buffer_1[2] " [OVERWRAP: MAIS DE 2 FIOS NO PINO!]" > "/dev/stderr"
                }
                if (PIN_Z_LEVEL[split_buffer_2[1], split_buffer_2[2]] > 2) {
                    print "[ERRO DRC CRÍTICO]: Componente " split_buffer_2[1] " pino " split_buffer_2[2] " [OVERWRAP: MAIS DE 2 FIOS NO PINO!]" > "/dev/stderr"
                }
                current = next_pt
            }
        }
    }
}

# CORREÇÃO DEFINITIVA: Injeção da função matemática de valor absoluto local para o roteador
function abs(v) { return v < 0 ? -v : v }

