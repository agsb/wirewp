# ==============================================================================
# MÓDULO 08: RENDERIZADOR VETORIAL SVG COM ILHAS QUADRADAS NO BOTTOM (08_svg.awk)
# ==============================================================================

function svg_lookup_physical_pin(chip_model, searched_pin_name,    max_pins, k, current_name) {
    if (searched_pin_name ~ /^[0-9]+$/) return searched_pin_name
    max_pins = COMP_LIB_PINS[chip_model]; if (!max_pins) max_pins = 40 
    for (k = 1; k <= max_pins; k++) { current_name = RAW_PIN_DB[chip_model, k]; if (current_name == searched_pin_name) return k }
    return ""
}

function render_svg(layer,    filename, dpi, scale, pw, ph, inst, model, type, pins, row_w, cx, cy, i, j, px, py, u_net, prio, color, opacity, p1_coord, p2_coord, x1, y1, x2, y2, part1, pin1, part2, pin2, phys_p1, phys_p2, current_seen, q, pin_scan, max_p, p_idx, pin_c, pin_x, pin_y, PIN_HOLES) {
    dpi = 300; scale = 30; q = sprintf("%c", 34)
    
    # Truncamento estrito como inteiro para impedir discrepanças de float no XML
    pw = int(BOARD_MAX_W * scale); ph = int(BOARD_MAX_H * scale); filename = "board_" layer ".svg"
    
    # --------------------------------------------------------------------------
    # MAPEAMENTO PRÉVIO DE PINOS ATIVOS PARA RENDERIZAÇÃO DE ILHAS QUADRADAS
    # --------------------------------------------------------------------------
    if (layer == "bottom") {
        for (pin_scan in COMP_INST_MODEL) {
            if (pin_scan == "" || pin_scan == "COB") continue
            model = COMP_INST_MODEL[pin_scan]
            max_p = COMP_LIB_PINS[model]
            if (max_p + 0 == 0) max_p = 40
            
            for (p_idx = 1; p_idx <= max_p; p_idx++) {
                delete pin_c
                get_pin_grid_coords(pin_scan, p_idx, pin_c)
                pin_x = int(pin_c["X"])
                pin_y = int(pin_c["Y"])
                if (pin_x > 0 && pin_y > 0) {
                    PIN_HOLES[pin_x, pin_y] = 1
                }
            }
        }
    }
    
    # --------------------------------------------------------------------------
    # 1. DECLARAÇÃO DO CABEÇALHO XML E NAMESPACE REGULAMENTAR DA W3C
    # --------------------------------------------------------------------------
    print "<?xml version=" q "1.0" q " encoding=" q "UTF-8" q " standalone=" q "no" q "?>" > filename
    
    # GERADOR W3C ESTREITO: Geração limpa e exata da propriedade W3C com aspas blindadas por caracter ASCII
    print "<svg xmlns=" q "http://w3.org" q " width=" q pw "px" q " height=" q ph "px" q " viewBox=" q "0 0 " pw " " ph q ">" >> filename
    
    print "  <defs>" >> filename
    print "    <style type=" q "text/css" q ">" >> filename
    print "      text { font-family: 'Courier New', Courier, monospace; user-select: none; text-rendering: optimizeLegibility; }" >> filename
    print "      .wire-trace { fill: none; stroke-linecap: round; stroke-linejoin: round; }" >> filename
    print "      .pad-hole { fill: rgb(17,17,11); stroke: rgb(212,175,55); stroke-width: 1; }" >> filename
    print "      .square-pad { fill: rgb(26,26,18); stroke: rgb(212,175,55); stroke-width: 1.5; }" >> filename
    # CORREÇÃO CRÍTICA DO TYPO: Re-envelopado perfeitamente na macro de fluxo do AWK
    print "    </style>" >> filename
    print "  </defs>" >> filename
    
    print "  <g id=" q "pcb-substrate" q ">" >> filename
    print "    <rect width='" pw "' height='" ph "' fill='rgb(26,51,30)' stroke='rgb(15,31,18)' stroke-width='4'/>" >> filename
    print "  </g>" >> filename
    
    # --------------------------------------------------------------------------
    # 4. GERADOR DE GRADE UNIVERSAL DA MATRIZ COM FILTRO SELETIVO DE GEOMETRIA
    # --------------------------------------------------------------------------
    print "  <g id=" q "universal-grid-matrix" q ">" >> filename
    for (i = 1; i < BOARD_MAX_W; i++) {
        for (j = 1; j < BOARD_MAX_H; j++) {
            px = int(i * scale)
            py = int(j * scale)
            
            if (layer == "bottom") {
                px = int(pw - px)
                if (PIN_HOLES[i, j] == 1) {
                    print "    <rect x='" (px - 6) "' y='" (py - 6) "' width='12' height='12' class='square-pad'/>" >> filename
                } else {
                    print "    <circle cx='" px "' cy='" py "' r='3' class='pad-hole'/>" >> filename
                }
            } else {
                print "    <circle cx='" px "' cy='" py "' r='3' class='pad-hole'/>" >> filename
            }
        }
    }
    print "  </g>" >> filename
    
    if (layer == "top") {
        print "  <g id='silkscreen-top-layer'>" >> filename
        delete current_seen
        for (inst in COMP_INST_MODEL) {
            if (inst == "" || inst == "COB" || current_seen[inst]++) continue
            model = COMP_INST_MODEL[inst]; type = COMP_LIB_TYPE[model]; pins = COMP_LIB_PINS[model]; row_w = COMP_LIB_ROW_W[model]
            cx = int((COMP_POS_X[inst] + 0) * scale); cy = int((COMP_POS_Y[inst] + 0) * scale)
            if (cx == 0 || cy == 0) continue 
            if (type == "DIP") {
                print "    <rect x='" (cx - 5) "' y='" (cy - 5) "' width='" int((row_w * scale) + 10) "' height='" int(((((pins/2)-1) * scale) + 10)) "' fill='none' stroke='rgb(255,255,255)' stroke-width='2' stroke-dasharray='4,2'/>" >> filename
                print "    <path d='M " int(cx + (row_w*scale)/2 - 10) " " cy " A 10 10 0 0 0 " int(cx + (row_w*scale)/2 + 10) " " cy "' fill='none' stroke='rgb(255,255,255)' stroke-width='2'/>" >> filename
                print "    <text x='" int(cx + (row_w*scale)/2) "' y='" int(cy + ((pins/4)*scale)) "' fill='rgb(255,255,255)' font-size='14' font-weight='bold' text-anchor='middle'>" inst ":" model "</text>" >> filename
            } else if (type == "SIL" || type == "CON") {
                print "    <rect x='" (cx - 5) "' y='" (cy - 5) "' width='10' height='" int((((pins-1) * scale) + 10)) "' fill='none' stroke='rgb(255,255,255)' stroke-width='2'/>" >> filename
                print "    <text x='" (cx + 15) "' y='" (cy + 10) "' fill='rgb(255,255,255)' font-size='10'>" inst "</text>" >> filename
            } else if (type == "DSC" || model == "CAPACITOR") {
                print "    <circle cx='" int(cx + scale/2) "' cy='" int(cy + scale/2) "' r='12' fill='none' stroke='rgb(255,204,102)' stroke-width='2'/>" >> filename
                print "    <text x='" int(cx + scale/2) "' y='" int(cy + scale/2 + 4) "' fill='rgb(255,204,102)' font-size='8' font-weight='bold' text-anchor='middle'>" inst "</text>" >> filename
            }
        }
        print "  </g>" >> filename
    } else if (layer == "bottom") {
        print "  <g id='routing-bottom-layer'>" >> filename
        for (i = 1; i <= ROUTE_COUNT; i++) {
            u_net = ROUTES[i, "net"]; prio = NET_PRIORITY[u_net]; part1 = ROUTES[i, "p1_part"]; pin1 = ROUTES[i, "p1_pin_num"]; part2 = ROUTES[i, "p2_part"]; pin2 = ROUTES[i, "p2_pin_num"]
            if (part1 == "" || part2 == "" || part1 == "COB" || part2 == "COB") continue
            
            phys_p1 = svg_lookup_physical_pin(COMP_INST_MODEL[part1], pin1)
            phys_p2 = svg_lookup_physical_pin(COMP_INST_MODEL[part2], pin2)
            
            if (phys_p1 == "") phys_p1 = (pin1 ~ /^[0-9]+$/) ? pin1 : "1"
            if (phys_p2 == "") phys_p2 = (pin2 ~ /^[0-9]+$/) ? pin2 : "1"
            
            delete p1_coord; delete p2_coord; get_pin_grid_coords(part1, phys_p1, p1_coord); get_pin_grid_coords(part2, phys_p2, p2_coord)
            
            x1 = int(pw - (((p1_coord["X"] + 0) == 0 ? 1 : (p1_coord["X"] + 0)) * scale)); y1 = int(((p1_coord["Y"] + 0) == 0 ? 1 : (p1_coord["Y"] + 0)) * scale)
            x2 = int(pw - (((p2_coord["X"] + 0) == 0 ? 1 : (p2_coord["X"] + 0)) * scale)); y2 = int(((p2_coord["Y"] + 0) == 0 ? 1 : (p2_coord["Y"] + 0)) * scale)
            
            # Anotações textuais puras e ampliadas (16px) sem a presença de fios no bottom
            if (x1 > 0 && y1 > 0) {
                print "    <text x='" x1 "' y='" int(y1 + 18) "' fill='rgb(220,220,220)' font-size='16' font-weight='bold' text-anchor='middle'>" part1 "." phys_p1 "</text>" >> filename
            }
            if (x2 > 0 && y2 > 0) {
                print "    <text x='" x2 "' y='" int(y2 + 18) "' fill='rgb(220,220,220)' font-size='16' font-weight='bold' text-anchor='middle'>" part2 "." phys_p2 "</text>" >> filename
            }
        }
        print "  </g>" >> filename
    }
    print "</svg>" >> filename; close(filename)
}

