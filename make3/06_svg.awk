
# ==============================================================================
# MÓDULO 6: RENDERIZADOR VETORIAL SVG EM ESCALA REAL (300 DPI) & ORQUESTRADOR
# ==============================================================================

# Função auxiliar local para determinação de coordenadas de pinos na grade
function svg_calc_pin_coords(part, pin_id, out_coords) {
    pack = inst_pack[part]
    
    # Resolve se é nome simbólico (ex: VCC, GND) ou número direto do pino
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
            # Lado esquerdo do CI (descendo)
            out_coords["x"] = base_x
            out_coords["y"] = base_y + (p_num - 1)
        } else {
            # Lado direito do CI (subindo)
            out_coords["x"] = base_x + width
            out_coords["y"] = base_y + (pins_tot - p_num)
        }
    } else {
        # Componente SIP ou Passivo
        out_coords["x"] = base_x
        out_coords["y"] = base_y + (p_num - 1)
    }
}

# Gerador Vetorial SVG
function render_svg(view_mode,    dpi, pitch, margin, pad_size, hole_r, svg_w, svg_h, 
                                 filename, gx, gy, vx, px, py, r, prio, from, to, 
                                 f_arr, t_arr, c1, c2, vx1, vx2, x1, y1, x2, y2, 
                                 i, p, pack, type, pins_tot, width, bx, by, 
                                 comp_w, comp_h, notch_x, notch_y, text_x, text_y) {
    
    # Parâmetros Físicos em 300 DPI
    pitch = 30           # 0.1 inch = 30px
    margin = 60          # Margem de borda de 0.2 inch (60px)
    pad_size = 24        # Tamanho do ilhó/pad de solda
    hole_r = 6           # Raio do furo passante

    # Fallback de segurança para enquadramento da placa
    if (board_w < 1) board_w = 20
    if (board_h < 1) board_h = 20

    svg_w = (board_w * pitch) + (margin * 2)
    svg_h = (board_h * pitch) + (margin * 2)

    filename = "pcb_" view_mode ".svg"
    print "=== GERANDO VETOR SVG: " filename " (Visão: " view_mode ") ===" > "/dev/stderr"

    # Cabeçalho do arquivo SVG
    print "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>" > filename
    print "<svg width=\"" svg_w "\" height=\"" svg_h "\" viewBox=\"0 0 " svg_w " " svg_h "\" xmlns=\"http://www.w3.org/2000/svg\">" > filename
    print "  <defs>" > filename
    print "    <style>" > filename
    print "      .board { fill: #2b3a28; stroke: #1a2418; stroke-width: 4; }" > filename
    print "      .pad { fill: #c8a853; stroke: #a08235; stroke-width: 1; }" > filename
    print "      .hole { fill: #111111; }" > filename
    print "      .comp-body { fill: #1e1e1e; stroke: #444444; stroke-width: 2; fill-opacity: 0.85; }" > filename
    print "      .comp-text { font-family: monospace; font-weight: bold; font-size: 14px; fill: #ffffff; text-anchor: middle; }" > filename
    print "      .wire-1 { stroke: #e74c3c; stroke-width: 3; stroke-linecap: round; opacity: 0.8; }" > filename
    print "      .wire-2 { stroke: #3498db; stroke-width: 3; stroke-linecap: round; opacity: 0.8; }" > filename
    print "      .wire-3 { stroke: #2ecc71; stroke-width: 3; stroke-linecap: round; opacity: 0.8; }" > filename
    print "      .wire-4 { stroke: #f1c40f; stroke-dasharray: 6,3; stroke-width: 4; stroke-linecap: round; }" > filename
    print "      .wire-5 { stroke: #9b59b6; stroke-dasharray: 6,3; stroke-width: 4; stroke-linecap: round; }" > filename
    print "      .wire-6 { stroke: #e67e22; stroke-width: 3; stroke-linecap: round; opacity: 0.8; }" > filename
    print "    </style>" > filename
    print "  </defs>" > filename

    # 1. Corpo da Placa (Placa de Circuito Universal)
    print "  <!-- Base da PCB -->" > filename
    print "  <rect class=\"board\" x=\"0\" y=\"0\" width=\"" svg_w "\" height=\"" svg_h "\" rx=\"15\" />" > filename

    # 2. Matriz de Ilhós e Furos (Grade de 0.1")
    print "  <!-- Matriz Universal Wire-Wrap -->" > filename
    for (gx = 1; gx <= board_w; gx++) {
        for (gy = 1; gy <= board_h; gy++) {
            # Se for visão BOTTOM, espelha o eixo X para Wire-Wrap
            vx = (view_mode == "bottom") ? (board_w - gx + 1) : gx
            px = margin + ((vx - 1) * pitch)
            py = margin + ((gy - 1) * pitch)

            print "  <rect class=\"pad\" x=\"" (px - pad_size/2) "\" y=\"" (py - pad_size/2) "\" width=\"" pad_size "\" height=\"" pad_size "\" rx=\"3\" />" > filename
            print "  <circle class=\"hole\" cx=\"" px "\" cy=\"" py "\" r=\"" hole_r "\" />" > filename
        }
    }

    # 3. Lado das Conexões (BOTTOM / Wire-Wrap com Espelhamento)
    if (view_mode == "bottom") {
        print "  <!-- Fiação Wire-Wrap (Lado Inferior Espelhado) -->" > filename
        for (r = 1; r <= route_total; r++) {
            prio = routes[r, "prio"]
            from = routes[r, "from"]
            to   = routes[r, "to"]

            split(from, f_arr, "-")
            split(to, t_arr, "-")

            svg_calc_pin_coords(f_arr[1], f_arr[2], c1)
            svg_calc_pin_coords(t_arr[1], t_arr[2], c2)

            # Aplicação de espelhamento horizontal no lado inferior
            vx1 = (board_w - c1["x"] + 1)
            vx2 = (board_w - c2["x"] + 1)

            x1 = margin + ((vx1 - 1) * pitch)
            y1 = margin + ((c1["y"] - 1) * pitch)
            x2 = margin + ((vx2 - 1) * pitch)
            y2 = margin + ((c2["y"] - 1) * pitch)

            print "  <line class=\"wire-" prio "\" x1=\"" x1 "\" y1=\"" y1 "\" x2=\"" x2 "\" y2=\"" y2 "\" />" > filename
        }
    }

    # 4. Lado dos Componentes (TOP / Silkscreen)
    if (view_mode == "top") {
        print "  <!-- Silkscreen e Encapsulamento dos Componentes -->" > filename
        for (i = 1; i <= inst_count; i++) {
            p = inst_list[i]
            pack = inst_pack[p]
            type = lib_type[pack]
            pins_tot = lib_pins_count[pack]
            width = lib_width[pack]

            bx = inst_x[p]
            by = inst_y[p]

            px = margin + ((bx - 1) * pitch) - (pitch / 2)
            py = margin + ((by - 1) * pitch) - (pitch / 2)

            comp_w = (type == "DIP") ? ((width + 1) * pitch) : (1.5 * pitch)
            comp_h = (type == "DIP") ? (((pins_tot / 2) + 0.5) * pitch) : ((pins_tot + 0.5) * pitch)

            print "  <g id=\"" p "\">" > filename
            print "    <rect class=\"comp-body\" x=\"" px "\" y=\"" py "\" width=\"" comp_w "\" height=\"" comp_h "\" rx=\"5\" />" > filename
            
            # Chafrro/Marca do Pino 1 para CIs DIP
            if (type == "DIP") {
                notch_x = px + (comp_w / 2)
                notch_y = py
                print "    <path d=\"M " (notch_x - 10) " " notch_y " A 10 10 0 0 0 " (notch_x + 10) " " notch_y "\" fill=\"#1a1a1a\" stroke=\"#444444\" />" > filename
            }

            text_x = px + (comp_w / 2)
            text_y = py + (comp_h / 2) + 5
            print "    <text class=\"comp-text\" x=\"" text_x "\" y=\"" text_y "\">" p " (" pack ")</text>" > filename
            print "  </g>" > filename
        }
    }

    print "</svg>" > filename
    close(filename)
}

# ==============================================================================
# ÚNICO PONTO DE ENTRADA E ORQUESTRADOR DO PIPELINE
# ==============================================================================
END {
    # 1. Gera o relatório completo de física, rotas e análise EMI (Módulo 5)
    generate_report()

    # 2. Renderiza as saídas vetoriais em escala real (Módulo 6)
    render_svg("top")
    render_svg("bottom")
}
