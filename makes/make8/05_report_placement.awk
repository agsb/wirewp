# ==============================================================================
# MÓDULO 05: RELATÓRIO TÉCNICO DE POSICIONAMENTO E DRC (05_report_placement.awk)
# ==============================================================================

function generate_placement_report(    inst, model, p_vcc, p_gnd, coord_p1, coord_vcc, coord_gnd, p1_str, vcc_str, gnd_str, target_ci, cap_p1, cap_p2) {
    print "========================================================================================================================================================"
    print "                                                              RELATÓRIO TÉCNICO COMPILADO DE ENGENHARIA E PLACEMENT"
    print "========================================================================================================================================================"
    print "\n[PLACEMENT] MAPA GEOMÉTRICO DE ALOCAÇÃO DE CIRCUITOS INTEGRADOS REAIS:"
    print "--------------------------------------------------------------------------------------------------------------------------------------------------------"
    printf "%-12s %-15s %-10s %-10s %-16s %-18s %-18s %-12s\n", "INSTÂNCIA", "MODELO CHIP", "X (FURO)", "Y (FURO)", "PINO_1 (X,Y)", "PINO_GND (X,Y)", "PINO_VCC (X,Y)", "ALOCAÇÃO"
    print "--------------------------------------------------------------------------------------------------------------------------------------------------------"
    for (inst in COMP_INST_MODEL) {
        if (inst == "" || inst == "COB" || inst ~ /^C_/ || seen_inst[inst]++) continue
        model = COMP_INST_MODEL[inst]
        
        delete coord_p1; get_pin_grid_coords(inst, 1, coord_p1); p1_str = "1@(" coord_p1["X"] "," coord_p1["Y"] ")"
        p_gnd = DB_NAME_TO_PIN[model, "GND"]
        if (p_gnd != "") { delete coord_gnd; get_pin_grid_coords(inst, p_gnd, coord_gnd); gnd_str = p_gnd "@(" coord_gnd["X"] "," coord_gnd["Y"] ")" } else { gnd_str = "N/A" }
        p_vcc = DB_NAME_TO_PIN[model, "VCC"]
        if (p_vcc != "") { delete coord_vcc; get_pin_grid_coords(inst, p_vcc, coord_vcc); vcc_str = p_vcc "@(" coord_vcc["X"] "," coord_vcc["Y"] ")" } else { vcc_str = "N/A" }
        
        printf "%-12s %-15s %-10d %-10d %-16s %-18s %-18s %-12s\n", inst, model, COMP_POS_X[inst], COMP_POS_Y[inst], p1_str, gnd_str, vcc_str, COMP_PLACEMENT_MODE[inst]
    }
    delete seen_inst
    
    print "\n[SUMÁRIO DE VALIDAÇÃO] REGRAS ELÉTRICAS E GEOMÉTRICAS (DRC):"
    print "--------------------------------------------------------------------------------------------------------------------------------------------------------"
    print "Status de Curtos-Circuitos VCC/GND : " (DRC_ERRORS > 0 ? "⚠️ FALHA DETECTADA" : "✅ VERIFICADO (0 Curtos)")
    print "Resultado Final do DRC             : " (DRC_ERRORS > 0 ? "❌ REJEITADO" : "✅ APROVADO PARA PRODUÇÃO")
    print "--------------------------------------------------------------------------------------------------------------------------------------------------------\n"
    
    print "[PLACEMENT] SEÇÃO 4: LISTAGEM DE CAPACITORES DE DESACOPLAMENTO BYPASS (TAMANHO PADRÃO 0.2 INCH):"
    print "--------------------------------------------------------------------------------------------------------------------------------------------------------"
    printf "%-15s %-12s %-10s %-18s %-20s %-18s %-20s\n", "CAPACITOR ID", "ALVO (CI)", "PASSO", "PONTA_1_VCC(X,Y)", "CONEXÃO_1 (NET)", "PONTA_2_GND(X,Y)", "CONEXÃO_2 (NET)"
    print "--------------------------------------------------------------------------------------------------------------------------------------------------------"
    for (inst in COMP_INST_MODEL) {
        if (inst ~ /^C_/) {
            target_ci = substr(inst, 3); delete cap_p1; delete cap_p2
            get_pin_grid_coords(inst, 1, cap_p1); get_pin_grid_coords(inst, 2, cap_p2)
            printf "%-15s %-12s %-10s %-18s %-20s %-18s %-20s\n", inst, target_ci, "0.2 inch", "(" cap_p1["X"] "," cap_p1["Y"] ")", "1 @ (VCC)", "(" cap_p2["X"] "," cap_p2["Y"] ")", "2 @ (GND)"
        }
    }
    print "--------------------------------------------------------------------------------------------------------------------------------------------------------\n"
}

