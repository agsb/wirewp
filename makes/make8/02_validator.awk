# ==============================================================================
# MÓDULO 02: VALIDADOR DE REGRAS ELÉTRICAS / DRC (02_validator.awk)
# ==============================================================================

function execute_drc_validation(    u_net, model, inst, total_pins, p, net_found) {
    print "[DRC] Iniciando Verificação de Regras Elétricas..." > "/dev/stderr"
    DRC_ERRORS = 0
    
    # 1. Validação de curtos-circuitos e redes flutuantes gerais
    for (u_net in NET_MEMBERS_COUNT) {
        if (NET_MEMBERS_COUNT[u_net] < 2 && NET_PRIORITY[u_net] != 7) {
            print "[DRC AVISO]: Rede flutuante detectada (apenas 1 pino): " u_net > "/dev/stderr"
        }
        if (u_net ~ /VCC/ && u_net ~ /GND/) {
            print "[DRC ERRO CRÍTICO]: Curto-Circuito direto detectado na rede: " u_net > "/dev/stderr"
            DRC_ERRORS++
        }
    }
    
    # 2. Consistência de encapsulamento e verificação de pinos isolados/não ligados
    for (inst in COMP_INST_MODEL) {
        if (inst == "" || inst == "COB" || inst ~ /^C_/) continue
        
        model = COMP_INST_MODEL[inst]
        if (!COMP_LIB_PINS[model]) {
            print "[DRC ERRO]: Componente " inst " possui modelo sem pegada definida no CSV: " model > "/dev/stderr"
            DRC_ERRORS++
            continue
        }
        
        # Auditoria de pinos flutuantes por componente
        total_pins = COMP_LIB_PINS[model]
        for (p = 1; p <= total_pins; p++) {
            if (!((inst, p) in NET_MAP) && NET_MAP[inst, p] == "") {
                pin_name_symbol = DB_PIN_TO_NAME[model, p]
                if (pin_name_symbol != "" && !((inst, pin_name_symbol) in NET_MAP)) {
                    print "[DRC AVISO]: Pino físico " p " (" pin_name_symbol ") do componente " inst " (" model ") NÃO está ligado a nenhum barramento!" > "/dev/stderr"
                } else if (pin_name_symbol == "") {
                    print "[DRC AVISO]: Pino físico " p " do componente " inst " (" model ") NÃO está ligado a nenhum barramento!" > "/dev/stderr"
                }
            }
        }
    }
    
    if (DRC_ERRORS > 0) {
        print "[DRC] Falha na validação elétrica. Total de erros: " DRC_ERRORS > "/dev/stderr"
    } else {
        print "[DRC] Passou com sucesso na validação elétrica de conectividade." > "/dev/stderr"
    }
}

