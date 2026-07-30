# ==============================================================================
# MÓDULO 5: ANÁLISE DE FÍSICA/EMI, Z-STACKING E GERADOR DE RELATÓRIO
# ==============================================================================

# Calcula a distância Manhattan entre dois pinos
function calc_manhattan_dist(f_part, f_pin, t_part, t_pin,    c1, c2) {
    get_pin_grid_coords(f_part, f_pin, c1)
    get_pin_grid_coords(t_part, t_pin, c2)
    
    dx = c1["x"] - c2["x"]
    dy = c1["y"] - c2["y"]
    if (dx < 0) dx = -dx
    if (dy < 0) dy = -dy
    return dx + dy
}

# Análise de Física, Verificação de Regras Wire-Wrap e EMI
function generate_report(    r, net, prio, from, to, f_arr, t_arr, dist, total_len, wire_count) {
    total_len = 0
    wire_count = route_total
    
    # Limpa contadores de Z-stacking por pino
    delete pin_z_stack

    print "\n================================================================================"
    print "                 RELATÓRIO COMPLETO DE COMPILAÇÃO E ANÁLISE EMI                 "
    print "================================================================================"
    printf "Dimensão da Placa: %d x %d furos (0.1\" / 2.54mm Grid Wire-Wrap)\n", board_w, board_h
    printf "Total de Componentes: %d | Total de Conexões (Roteamentos): %d\n", inst_count, route_total
    print "--------------------------------------------------------------------------------"
    print "ID | REDE       | PRIO | DE          | PARA        | DIST(furos) | Z-LEVEL | TWIST?"
    print "--------------------------------------------------------------------------------"

    for (r = 1; r <= route_total; r++) {
        net  = routes[r, "net"]
        prio = routes[r, "prio"]
        from = routes[r, "from"]
        to   = routes[r, "to"]

        split(from, f_arr, "-")
        split(to, t_arr, "-")

        # 1. Análise Físico-Espacial (Distância real na grade de 0.1")
        dist = calc_manhattan_dist(f_arr[1], f_arr[2], t_arr[1], t_arr[2])
        total_len += dist

        # 2. Controle de Empilhamento Z (Z-Stacking: máximo 2 níveis por pino)
        pin_z_stack[from]++
        pin_z_stack[to]++
        
        z_level_f = pin_z_stack[from]
        z_level_t = pin_z_stack[to]
        
        # Define nível máximo atingido nesta conexão
        z_display = (z_level_f > z_level_t) ? z_level_f : z_level_t

        # Flag de verificação de violação de limite físico do pino
        z_warn = (z_level_f > 2 || z_level_t > 2) ? " [ALERTA: Z>2!]" : ""

        # 3. Lógica EMI / Par Trançado (Twist Pair)
        # Sinais de altíssima prioridade (Prio 4/5 - Relógios/Alta Frequência) exigem par trançado com GND
        is_high_freq = (prio >= 4)
        has_twist = (is_high_freq || routes[r, "twist"] == 1) ? "SIM (GND)" : "NÃO"

        printf("%02d | %-10s |  %d   | %-11s | %-11s | %-11d | L%-6d%s | %s\n", 
            r, net, prio, from, to, dist, z_display, z_warn, has_twist)
    }

    print "--------------------------------------------------------------------------------"
    print "=== RESUMO DE ENGENHARIA E FÍSICA DA PLACA ==="
    printf "Comprimento Total de Fio Requerido: %.2f polegadas (%.2f cm)\n", (total_len * 0.1), (total_len * 0.254)
    printf "Média de Comprimento por Ligação:  %.2f polegadas\n", (wire_count > 0 ? (total_len / wire_count) * 0.1 : 0)
    
    # Validação de Segurança Física dos Pinos
    violations = 0
    for (p in pin_z_stack) {
        if (pin_z_stack[p] > 2) {
            print " [ERRO DE FISICA] Pino " p " excedeu o limite de 2 conexões Wire-Wrap (Empilhou " pin_z_stack[p] ")!"
            violations++
        }
    }
    
    if (violations == 0) {
        print " [OK] Verificação de Z-Stacking concluída sem violações físicas de pinos."
    } else {
        printf(" [FALHA] Encontradas %d violações de limite físico nos pinos!\n", violations)
    }
    print "================================================================================\n"
}
