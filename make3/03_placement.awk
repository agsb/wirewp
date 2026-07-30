# ==============================================================================
# MÓDULO 3: POSICIONAMENTO E ALOCAÇÃO ESPACIAL NA MATRIZ
# ==============================================================================

function get_pin_grid_coords(part, pin_id, out_coords) {
    pack = inst_pack[part]
    
    # Resolve se o pin_id é um nome (ex: VCC) ou número direto
    if ((pack, pin_id) in lib_pin_num) {
        p_num = lib_pin_num[pack, pin_id]
    } else {
        p_num = pin_id + 0
    }

    base_x = inst_x[part]
    base_y = inst_y[part]
    type = lib_type[pack]
    pins_tot = lib_pins_count[pack]
    width = lib_width[pack]

    if (type == "DIP") {
        half = pins_tot / 2
        if (p_num <= half) {
            # Lado Esquerdo do CI (descendo)
            out_coords["x"] = base_x
            out_coords["y"] = base_y + (p_num - 1)
        } else {
            # Lado Direito do CI (subindo)
            out_coords["x"] = base_x + width
            out_coords["y"] = base_y + (pins_tot - p_num)
        }
    } else {
        # Componente SIP / Passivo Linear
        out_coords["x"] = base_x
        out_coords["y"] = base_y + (p_num - 1)
    }
}

# Algoritmo de Alocação e Posicionamento dos Componentes
function run_placement() {
    # Coordenadas iniciais na matriz (com margem de borda)
    cur_x = 2
    cur_y = 2
    max_y_in_row = 0
    max_board_x = 0
    max_board_y = 0

    for (i = 1; i <= inst_count; i++) {
        p = inst_list[i]
        pack = inst_pack[p]
        type = lib_type[pack]
        pins = lib_pins_count[pack]
        w = lib_width[pack]

        # Calcula altura física necessária ocupada pelo componente na grade
        comp_h = (type == "DIP") ? int(pins / 2) : pins

        # Posiciona componente atual
        inst_x[p] = cur_x
        inst_y[p] = cur_y

        # Atualiza limite máximo da linha
        if (comp_h > max_y_in_row) {
            max_y_in_row = comp_h
        }

        # Calcula área ocupada para dimensão da placa
        right_x = (type == "DIP") ? (cur_x + w) : cur_x
        bottom_y = cur_y + comp_h - 1

        if (right_x > max_board_x) max_board_x = right_x
        if (bottom_y > max_board_y) max_board_y = bottom_y

        # Avança coluna de posicionamento (deslocamento no eixo X)
        # Garante um espaçamento de pelo menos 2 furos entre CIs
        cur_x += (type == "DIP") ? (w + 3) : 3

        # Se ultrapassar 30 furos na horizontal, salta para a próxima linha
        if (cur_x > 30) {
            cur_x = 2
            cur_y += max_y_in_row + 2
            max_y_in_row = 0
        }
    }

    # Define dimensões totais da placa universal (com margem de segurança)
    board_w = max_board_x + 2
    board_h = max_board_y + 2
}

# Ponto de entrada do posicionamento
END {
    # Garante execução apenas se o parser tiver finalizado sem erros
    if (NR > 0 && !placement_done) {
        run_placement()
        placement_done = 1
    }
}
