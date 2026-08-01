# ==============================================================================
# MÓDULO 07: EXPORTADOR DE SUMÁRIO HIERÁRQUICO DE FIAÇÃO (07_export.awk)
# ==============================================================================

# Função auxiliar para arredondamento para o próximo múltiplo inteiro superior (Ceil)
function round_to_ceil_cm(value,    int_part) {
    int_part = int(value)
    if (value > int_part) {
        return int_part + 1
    }
    return int_part == 0 ? 1 : int_part
}

function generate_routing_summary(    i, u_net, prio, p1, p2, dist_grid, dist_inch, dist_cm, dist_slack_cm, part1, pin1, part2, pin2, model1, model2, phys_pin1, phys_pin2, sum_file, txt_color, current_prio_group, z1, z2, z1_label, z2_label, z_alert, final_std_cm, final_slack_cm, wrap_wrap_hardware_allowance_cm, SUM_TOTAL_STD, SUM_TOTAL_SLACK) {
    
    sum_file = "board_routing_summary.txt"
    SUM_TOTAL_STD = 0
    SUM_TOTAL_SLACK = 0

    print "==================================================================================================================" > sum_file
    print "                     SUMÁRIO DE DIRETRIZES DE FIAÇÃO E ENROLAMENTO MANUAL WIRE-WRAP" > sum_file
    print "                         (ORDENADO POR PRIORIDADE CLASSE DE BARRAMENTOS HIERÁRQUICOS)" > sum_file
    print "                   [INCLUSO: 6 VOLTAS NUAS + 2 VOLTAS ENCAPADAS POR EXTREMIDADE DE CONEXÃO]" > sum_file
    print "==================================================================================================================" > sum_file
    printf "%-12s %-8s %-12s %-6s %-8s %-12s %-6s %-12s %-12s %-10s %-10s\n", "REDE", "DE_COMP", "PIN_1(DS)", "Z1_POS", "PARA_CMP", "PIN_2(DS)", "Z2_POS", "COMP_STD(cm)", "FOLGA_20%(cm)", "COR_FIO", "STATUS_P" >> sum_file
    print "------------------------------------------------------------------------------------------------------------------" >> sum_file

    # Constante física industrial de hardware por segmento (2 pinos): 4.544 cm
    wrap_wrap_hardware_allowance_cm = 4.544

    for (current_prio_group = 1; current_prio_group <= 7; current_prio_group++) {
        
        if (current_prio_group == 1) print "\n[ CLASSE 1 - POWER / ALIMENTAÇÕES GLOBAIS ]" >> sum_file
        else if (current_prio_group == 2) print "\n[ CLASSE 2 - BARRAMENTO DE DADOS PARALELOS ]" >> sum_file
        else if (current_prio_group == 3) print "\n[ CLASSE 3 - BARRAMENTO DE ENDEREÇAMENTO ]" >> sum_file
        else if (current_prio_group == 4) print "\n[ CLASSE 4 - LINHAS DE CONTROLE CRÍTICO / CLOCK ]" >> sum_file
        else if (current_prio_group == 5) print "\n[ CLASSE 5 - SINAIS ANALÓGICOS SENSÍVEIS (TWIST) ]" >> sum_file
        else if (current_prio_group == 6) print "\n[ CLASSE 6 - REDES LOGICAS GERAIS E INTERCONEXÕES ]" >> sum_file
        else if (current_prio_group == 7) print "\n[ CLASSE 7 - DIAGNÓSTICOS / TERMINAIS ISOLADOS ]" >> sum_file
        print "------------------------------------------------------------------------------------------------------------------" >> sum_file

        for (i = 1; i <= ROUTE_COUNT; i++) {
            u_net = ROUTES[i, "net"]
            prio = NET_PRIORITY[u_net]
            
            if (prio != current_prio_group) continue

            part1 = ROUTES[i, "p1_part"]
            pin1  = ROUTES[i, "p1_pin_num"]
            part2 = ROUTES[i, "p2_part"]
            pin2  = ROUTES[i, "p2_pin_num"]
            
            # CORREÇÃO CRÍTICA: Remove o bloqueio anterior 'continue' e permite processar as rotas de capacitores.
            # No entanto, os capacitores apenas entram na Classe 1 (Alimentação). Isolamos as regras cromáticas e Z deles:
            if (part1 ~ /^C_/ || part2 ~ /^C_/) {
                model1 = COMP_INST_MODEL[part1]
                model2 = COMP_INST_MODEL[part2]
                phys_pin1 = (part1 ~ /^C_/) ? pin1 : DB_NAME_TO_PIN[model1, pin1]
                phys_pin2 = (part2 ~ /^C_/) ? pin2 : DB_NAME_TO_PIN[model2, pin2]
                
                if (u_net ~ /^(GND|DGND|VSS|AGND)$/) txt_color = "PRETO";
                else txt_color = "VERMELHO";
                
                # Força o capacitor a fixar-se na base para melhor barreira contra ruídos EMI
                z1_label = "BAIXO"
                z2_label = "BAIXO"
                z_alert = "OK"
            } else {
                # Fluxo normal para Circuitos Integrados Reais
                model1 = COMP_INST_MODEL[part1]
                model2 = COMP_INST_MODEL[part2]
                
                phys_pin1 = DB_NAME_TO_PIN[model1, pin1]
                phys_pin2 = DB_NAME_TO_PIN[model2, pin2]
                
                if (prio == 1) { 
                    if (u_net ~ /^(GND|DGND|VSS|AGND)$/) txt_color = "PRETO";
                    else txt_color = "VERMELHO";
                } 
                else if (prio == 2) { txt_color = "AZUL"; } 
                else if (prio == 3) { txt_color = "VERDE"; } 
                else if (prio == 4) { txt_color = "AMARELO"; } 
                else if (prio == 5) { txt_color = "MAGENTA"; } 
                else { txt_color = "BRANCO"; }
                
                z1 = ROUTES[i, "p1_z"]
                z2 = ROUTES[i, "p2_z"]
                z1_label = (z1 == 1) ? "BAIXO" : "CIMA"
                z2_label = (z2 == 1) ? "BAIXO" : "CIMA"
                z_alert  = (z1 > 2 || z2 > 2) ? "OVERWRAP" : "OK"
            }
            
            if (phys_pin1 == "") phys_pin1 = (pin1 ~ /^[0-9]+$/) ? pin1 : "1"
            if (phys_pin2 == "") phys_pin2 = (pin2 ~ /^[0-9]+$/) ? pin2 : "1"
            
            delete p1; delete p2
            get_pin_grid_coords(part1, phys_pin1, p1)
            get_pin_grid_coords(part2, phys_pin2, p2)
            
            dist_grid = abs(p1["X"] - p2["X"]) + abs(p1["Y"] - p2["Y"])
            dist_inch = dist_grid * 0.1

            if (prio == 4 || prio == 5) dist_inch = dist_inch * 1.20
            
            dist_cm = (dist_inch * 2.54) + wrap_wrap_hardware_allowance_cm
            dist_slack_cm = dist_cm * 1.20 
            
            final_std_cm   = round_to_ceil_cm(dist_cm)
            final_slack_cm = round_to_ceil_cm(dist_slack_cm)
            
            SUM_TOTAL_STD   += final_std_cm
            SUM_TOTAL_SLACK += final_slack_cm

            printf "%-12s %-8s %-12s %-6s %-8s %-12s %-6s %-12d %-12d %-10s %-10s\n",
                u_net, part1, phys_pin1 " (" pin1 ")", z1_label, part2, phys_pin2 " (" pin2 ")", z2_label, final_std_cm, final_slack_cm, txt_color, z_alert >> sum_file
        }
    }
    
    print "\n------------------------------------------------------------------------------------------------------------------" >> sum_file
    close(sum_file)
    
    print "------------------------------------------------------------------------------------------------------"
    print "               MÉTRICAS CONSOLIDADAS DE MATERIAIS PARA COMPRA / DESPERDÍCIO ZERO"
    print "------------------------------------------------------------------------------------------------------"
    printf "COMPRIMENTO REQUERIDO TOTAL DE CONDUTOR (ENROLAMENTO PADRÃO)  : %d cm (%.2f metros)\n", SUM_TOTAL_STD, (SUM_TOTAL_STD / 100)
    printf "COMPRIMENTO REQUERIDO TOTAL DE CONDUTOR (COM 20%% DE FOLGA): %d cm (%.2f metros)\n", SUM_TOTAL_SLACK, (SUM_TOTAL_SLACK / 100)
    print "------------------------------------------------------------------------------------------------------"
}

