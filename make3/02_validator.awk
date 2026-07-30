# ==============================================================================
# MÓDULO 2: VALIDADOR DE REGRAS DE NEGÓCIO E INTEGRIDADE
# ==============================================================================

function validate_system() {
    print "=== INICIANDO VALIDAÇÃO DE INTEGRIDADE DA PCB ===" > "/dev/stderr"

    # 1. Validar Dimensões da Placa
    if (board_w <= 0 || board_h <= 0) {
        print "FATAL ERROR: Dimensões da placa (BRD) inválidas ou não definidas." > "/dev/stderr"
        exit 1
    }

    # 2. Validar se os componentes em COB existem na biblioteca
    for (i = 1; i <= inst_count; i++) {
        p = inst_list[i]
        pack = inst_pack[p]
        if (!(pack in lib_type)) {
            print "FATAL ERROR: Componente " p " usa o pacote '" pack "' não definido em componentes.csv!" > "/dev/stderr"
            ERR_COUNT++
        }
    }

    # 3. Validar se os pinos referenciados na Netlist existem na biblioteca do componente
    for (n = 1; n <= net_count; n++) {
        net = net_list[n]
        nodes = net_node_count[net]
        for (j = 1; j <= nodes; j++) {
            p = net_node_part[net, j]
            pin_id = net_node_pin[net, j]
            pack = inst_pack[p]

            # Checa se o pino existe no componente
            found = 0
            for (k = 1; k <= lib_pins_count[pack]; k++) {
                if (lib_pin_name[pack, k] == pin_id || k == pin_id) {
                    found = 1
                    break
                }
            }
            if (!found) {
                print "ERRO [VALIDAÇÃO]: Pino '" pin_id "' não existe no pacote " pack " (Componente " p ")" > "/dev/stderr"
                ERR_COUNT++
            }
        }
    }

    if (ERR_COUNT > 0) {
        print "ABORTANDO: " ERR_COUNT " erro(s) de validação encontrado(s)." > "/dev/stderr"
        exit 1
    }
    print ">>> VALIDAÇÃO CONCLUÍDA COM SUCESSO! <<<\n" > "/dev/stderr"
}

