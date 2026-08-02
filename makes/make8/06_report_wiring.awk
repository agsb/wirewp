# ==============================================================================
# MÓDULO 06: RELATÓRIO TÉCNICO DE ENROLAMENTO / WIRING (06_report_wiring.awk)
# ==============================================================================

function generate_wiring_report(    i, u_net, prio, p1, p2, cx, cy, nx, ny, dist_grid, dist_inch, dist_cm, is_twist, z1, z2, z1_label, z2_label, z_alert, l_nh, crosstalk, total_wire_cm, part1, pin1, part2, pin2, model1, model2, phys_pin1, phys_pin2, pin_str1, pin_str2, current_prio_group, txt_color) {
    print "========================================================================================================================================================"
    print "                                                              RELATÓRIO TÉCNICO COMPILADO DE ENROLAMENTO E ANÁLISE EMI"
    print "========================================================================================================================================================"
    print "\n[ROTEAMENTO] TABELA DETALHADA DE SEGMENTOS MANHATTAN (ORDENADA POR PRIORIDADE E COR):"
    
    total_wire_cm = 0
    for (current_prio_group = 1; current_prio_group <= 7; current_prio_group++) {
        if (current_prio_group == 1) print "\n--> CLASSE 1 - POWER / ALIMENTAÇÕES GLOBAIS (FIO VERMELHO / PRETO)"
        else if (current_prio_group == 2) print "\n--> CLASSE 2 - BARRAMENTO DE DADOS PARALELOS (FIO AZUL)"
        else if (current_prio_group == 3) print "\n--> CLASSE 3 - BARRAMENTO DE ENDEREÇAMENTO (FIO VERDE)"
        else if (current_prio_group == 4) print "\n--> CLASSE 4 - LINHAS DE CONTROLE CRÍTICO / CLOCK (FIO AMARELO)"
        else if (current_prio_group == 5) print "\n--> CLASSE 5 - SINAIS ANALÓGICOS SENSÍVEIS (FIO MAGENTA - TWIST)"
        else if (current_prio_group == 6) print "\n--> CLASSE 6 - REDES LÓGICAS GERAIS E INTERCONEXÕES (FIO BRANCO)"
        else print "\n--> CLASSE 7 - DIAGNÓSTICOS / TERMINAIS ISOLADOS (FIO BRANCO)"
        
        print "--------------------------------------------------------------------------------------------------------------------------------------------------------"
        printf "%-12s %-10s %-20s %-8s %-10s %-20s %-8s %-12s %-7s %-10s %-9s %-9s %-8s\n", "REDE", "DE_COMP", "PIN_1(NÚM_NOME)", "Z1_POS", "PARA_CMP", "PIN_2(NÚM_NOME)", "Z2_POS", "MANH(FUROS)", "TWIST", "COR_FIO", "IND(nH)", "XTALK(mV)", "STATUS_Z"
        print "--------------------------------------------------------------------------------------------------------------------------------------------------------"
        
        for (i = 1; i <= ROUTE_COUNT; i++) {
            u_net = ROUTES[i, "net"]; prio = NET_PRIORITY[u_net]; if (prio != current_prio_group) continue
            part1 = ROUTES[i, "p1_part"]; pin1 = ROUTES[i, "p1_pin_num"]; part2 = ROUTES[i, "p2_part"]; pin2 = ROUTES[i, "p2_pin_num"]
            if (part1 ~ /^C_/ || part2 ~ /^C_/) continue
            
            model1 = COMP_INST_MODEL[part1]; model2 = COMP_INST_MODEL[part2]
            phys_pin1 = DB_NAME_TO_PIN[model1, pin1]; phys_pin2 = DB_NAME_TO_PIN[model2, pin2]
            if (phys_pin1 == "") phys_pin1 = (pin1 ~ /^[0-9]+$/) ? pin1 : "1"
            if (phys_pin2 == "") phys_pin2 = (pin2 ~ /^[0-9]+$/) ? pin2 : "1"
            pin_str1 = phys_pin1 " (" pin1 ")"; pin_str2 = phys_pin2 " (" pin2 ")"
            
            delete p1; delete p2; get_pin_grid_coords(part1, phys_pin1, p1); get_pin_grid_coords(part2, phys_pin2, p2)
            dist_grid = abs(p1["X"] - p2["X"]) + abs(p1["Y"] - p2["Y"]); dist_inch = dist_grid * 0.1
            
            if (prio == 1) txt_color = (u_net ~ /^(GND|DGND|VSS|AGND)$/) ? "PRETO" : "VERMELHO"
            else if (prio == 2) txt_color = "AZUL"; else if (prio == 3) txt_color = "VERDE"; else if (prio == 4) txt_color = "AMARELO"; else if (prio == 5) txt_color = "MAGENTA"; else txt_color = "BRANCO"
            
            is_twist = (prio == 4 || prio == 5) ? 1 : 0; if (is_twist) dist_inch = dist_inch * 1.20
            dist_cm = dist_inch * 2.54; total_wire_cm += dist_cm
            z1 = ROUTES[i, "p1_z"]; z2 = ROUTES[i, "p2_z"]
            z1_label = (z1 == 1) ? "BAIXO" : "CIMA"; z2_label = (z2 == 1) ? "BAIXO" : "CIMA"; z_alert = (z1 > 2 || z2 > 2) ? "[ERR_Z]" : "OK"
            l_nh = (dist_cm * 10) * 0.82; crosstalk = is_twist ? (l_nh * 0.02) : (l_nh * 0.15)
            
            printf "%-12s %-10s %-20s %-8s %-10s %-20s %-8s %-12d %-7s %-10s %-9.2f %-9.2f %-8s\n", u_net, part1, pin_str1, z1_label, part2, pin_str2, z2_label, dist_grid, (is_twist ? "SIM":"NÃO"), txt_color, l_nh, crosstalk, z_alert
        }
        print "--------------------------------------------------------------------------------------------------------------------------------------------------------"
    }
    printf "COMPRIMENTO TOTAL ESTIMADO DE CONDUTORES NA PLACA: %.2f cm\n", total_wire_cm
}

