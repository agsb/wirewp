
# ==============================================================================
# MÓDULO 6: RENDERIZADOR VETORIAL SVG EM ESCALA REAL (300 DPI)
# ==============================================================================

function render_svg(view_mode) {
    # Constantes físicas para 300 DPI
    dpi = 300
    pitch = 30           # 0.1 inch = 30px a 300 DPI
    margin = 60          # Borda de 0.2 inch na imagem
    pad_size = 24        # Tamanho do pad metálico da matriz
    hole_r = 6           # Raio do furo (1.016mm / 0.04" de diâmetro)

    # Dimensões totais em pixels
    svg_w = (board_w * pitch) + (margin * 2)
    svg_h = (board_h * pitch) + (margin * 2)

    filename = "pcb_" view_mode ".svg"
    print "=== GERANDO SVG: " filename " (Visão: " view_mode ", Resolução: 300 DPI) ===" > "/dev/stderr"

    # Cabeçalho SVG
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

    # 1. Placa de Fenolite / Epóxi
    print "  <!-- PCB Base -->" > filename
    print "  <rect class=\"board\" x=\"0\" y=\"0\" width=\"" svg_w "\" height=\"" svg_h "\" rx=\"15\" />" > filename

    # 2. Matriz Universal de Pads e Furos (Grid 0.1")
    print "  <!-- Matriz de Pads e Furos Wire-Wrap -->" > filename
    for (gx = 1; gx <= board_w; gx++) {
        for (gy = 1; gy <= board_h; gy++) {
            # Se a visão for BOTTOM (Mirror X), inverte a coordenada X visual da matriz
            vx = (view_mode == "bottom") ? (board_w - gx + 1) : gx
            px = margin + ((vx - 1) * pitch)
            py = margin + ((gy - 1) * pitch)

            # Desenha Pad Ilha de Solda + Furo
            print "  <rect class=\"pad\" x=\"" (px - pad_size/2) "\" y=\"" (py - pad_size/2) "\" width=\"" pad_size "\" height=\"" pad_size "\" rx=\"3\" />" > filename
            print "  <circle class=\"hole\" cx=\"" px "\" cy=\"" py "\" r=\"" hole_r "\" />" > filename
        }
    }

    # 3. Renderização de Fiação se for Lado das Conexões (BOTTOM)
    if (view_mode == "bottom") {
        print "  <!-- Redes e Fiação Wire-Wrap (Lado Inferior) -->" > filename
        for (r = 1; r <= route_total; r++) {
            net   = routes[r, "net"]
            prio  = routes[r, "prio"]
            from  = routes[r, "from"]
            to    = routes[r, "to"]

            split(from, f_arr, "-")
            split(to, t_arr, "-")

            # Resolve Coordenadas Reais dos Pinos
            get_pin_grid_coords(f_arr[1], f_arr[2], c1)
            get_pin_grid_coords(t_arr[1], t_arr[2], c2)

            vx1 = (board_w - c1["x"] + 1)
            vx2 = (board_w - c2["x"] + 1)

            x1 = margin + ((vx1 - 1) * pitch)
            y1 = margin + ((c1["y"] - 1) * pitch)
            x2 = margin + ((vx2 - 1) * pitch)
            y2 = margin + ((c2["y"] - 1) * pitch)

            # Desenha linha de fiação no canal
            print "  <line class=\"wire-" prio "\" x1=\"" x1 "\" y1=\"" y1 "\" x2=\"" x2 "\" y2=\"" y2 "\" />" > filename
        }
    }

    # 4. Renderização dos Corpos dos Componentes (TOP VIEW)
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

            # Corpo do Componente
            print "  <g id=\"" p "\">" > filename
            print "    <rect class=\"comp-body\" x=\"" px "\" y=\"" py "\" width=\"" comp_w "\" height=\"" comp_h "\" rx=\"5\" />" > filename
            
            # Marcação do Pino 1 (Notch / Id)
            if (type == "DIP") {
                notch_x = px + (comp_w / 2)
                notch_y = py
                print "    <path d=\"M " (notch_x - 10) " " notch_y " A 10 10 0 0 0 " (notch_x + 10) " " notch_y "\" fill=\"#1a1a1a\" stroke=\"#444444\" />" > filename
            }

            # Nome do Componente no Centro
            text_x = px + (comp_w / 2)
            text_y = py + (comp_h / 2) + 5
            print "    <text class=\"comp-text\" x=\"" text_x "\" y=\"" text_y "\">" p " (" pack ")</text>" > filename
            print "  </g>" > filename
        }
    }

    print "</svg>" > filename
    close(filename)
}

# Invocação Automática no Bloco END estendido
END {
    # Gera ambas as vistas automaticamente
    render_svg("top")      # Visão Superior
    render_svg("bottom")   # Visão Inferior Espelhada em X (Fiação Wire-Wrap)
}

