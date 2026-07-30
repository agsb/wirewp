# ==============================================================================
# MÓDULO 5: SIMULAÇÃO ELETROMAAGNÉTICA (EMI) E RELATÓRIO TÉCNICO
# ==============================================================================

# Bloco final que dispara todo o fluxo computacional
END {
    # 1. Executa Validação
    validate_system()

    # 2. Executa Posicionamento Físico
    run_placement()

    # 3. Executa Roteamento
    run_router()

    # --- EMISSÃO DE RELATÓRIO COMPLETO ---
    print "================================================================================"
    print "            ESPECIFICAÇÃO DE MONTAGEM E RELATÓRIO WIRE-WRAP DE PCB              "
    print "================================================================================"
    print "TAMANHO DA PLACA: " board_w " x " board_h " furos (Matriz 0.1\" / 2.54mm)"
    print "COMPONENTES INSTANCIADOS: " inst_count
    print "================================================================================\n"

    # --- SEÇÃO 1: BILL OF MATERIALS (BOM) & PLACEMENT ---
    print "--- 1. POSICIONAMENTO FINAL DOS COMPONENTES (PLACEMENT) ---"
    printf "%-8s %-12s %-8s %-10s %-12s\n", "PART", "PACOTE", "TIPO", "STATUS", "POSIÇÃO (X,Y)"
    print "--------------------------------------------------------------------------------"
    for (i = 1; i <= inst_count; i++) {
        p = inst_list[i]
        pack = inst_pack[p]
        printf "%-8s %-12s %-8s %-10s (%d, %d)\n", p, pack, lib_type[pack], inst_status[p], inst_x[p], inst_y[p]
    }
    print "\n"

    # --- SEÇÃO 2: INSTRUÇÕES DE FIAÇÃO WIRE-WRAP ---
    print "--- 2. LISTA DE FIAÇÃO ORDENADA POR PRIORIDADE ---"
    printf "%-6s %-10s %-14s %-14s %-8s %-8s %-10s\n", "PRIO", "NET", "ORIGEM (Z)", "DESTINO (Z)", "DIST(mm)", "TIPO", "ESTADO"
    print "--------------------------------------------------------------------------------"

    total_wire_len_mm = 0
    max_crosstalk_mv = 0
    critical_net = "N/A"

    for (r = 1; r <= route_total; r++) {
        net     = routes[r, "net"]
        prio    = routes[r, "prio"]
        from    = routes[r, "from"]
        to      = routes[r, "to"]
        g_len   = routes[r, "grid_len"]
        is_tw   = routes[r, "is_twist"]
        z1      = routes[r, "z1"]
        z2      = routes[r, "z2"]

        # Conversão de grid para mm (1 furo = 2.54mm)
        len_mm = g_len * 2.54

        # Se for Par Trançado, aplica o acréscimo de +20% no comprimento
        if (is_tw == 1) {
            len_mm *= 1.20
            wire_type = "TWIST+GND"
        } else {
            wire_type = "NORMAL"
        }

        total_wire_len_mm += len_mm

        # Cálculos de Simulação Eletromagnética
        inductance_nH = len_mm * 0.82
        if (is_tw == 1) {
            crosstalk_mV = inductance_nH * 0.02
        } else {
            crosstalk_mV = inductance_nH * 0.15
        }

        if (crosstalk_mV > max_crosstalk_mv) {
            max_crosstalk_mv = crosstalk_mV
            critical_net = net
        }

        # Checagem de Erro de Empilhamento (Limite: 2 voltas por pino)
        status_z = "OK"
        if (z1 > 2 || z2 > 2) {
            status_z = "OVERWRAP!"
            ERR_COUNT++
        }

        from_str = sprintf("%s (Z%d)", from, z1)
        to_str   = sprintf("%s (Z%d)", to, z2)

        printf "NIVEL %d %-10s %-14s %-14s %-8.1f %-10s %-10s\n", prio, net, from_str, to_str, len_mm, wire_type, status_z
    }
    print "\n"

    # --- SEÇÃO 3: DIAGNÓSTICO E ELETROMAGNETISMO ---
    print "--- 3. SUMÁRIO ELETROMAGNÉTICO (EMI) E RECURSOS ---"
    print "--------------------------------------------------------------------------------"
    printf "COMPRIMENTO TOTAL DE FIO REQUERIDO : %.2f mm (%.2f metros)\n", total_wire_len_mm, total_wire_len_mm / 1000.0
    printf "MAIOR NÍVEL DE RUÍDO (CROSSTALK)   : %.3f mV (Net: %s)\n", max_crosstalk_mv, critical_net
    
    # Checagem final de pinos isolados / desconectados (Nível 7)
    unconnected_count = 0
    for (n = 1; n <= net_count; n++) {
        net = net_list[n]
        if (net_node_count[net] == 1) {
            p = net_node_part[net, 1]
            pin = net_node_pin[net, 1]
            print "ALERTA [NÍVEL 7]: Pino isolado sem conexão -> Componente: " p ", Pino: " pin " (Net: " net ")"
            unconnected_count++
        }
    }

    print "================================================================================"
    if (ERR_COUNT > 0) {
        print "STATUS FINAL: CONCLUÍDO COM ALERTAS/ERROS (" ERR_COUNT " erros de Overwrap/Sistema)"
    } else {
        print "STATUS FINAL: ROTEAMENTO CONCLUÍDO COM SUCESSO (0 Erros Físicos)"
    }
    print "================================================================================"
}

