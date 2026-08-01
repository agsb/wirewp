# ==============================================================================
# MÓDULO 08: RENDERIZADOR VETORIAL SVG REALÍSTICO 300 DPI (08_svg.awk)
# ==============================================================================

function svg_lookup_physical_pin(chip_model, searched_pin_name,    max_pins, k, current_name) {
    if (searched_pin_name ~ /^[0-9]+$/) return searched_pin_name
    
    max_pins = COMP_LIB_PINS[chip_model]
    if (!max_pins) max_pins = 40 
    
    for (k = 1; k <= max_pins; k++) {
        current_name = RAW_PIN_DB[chip_model, k]
        if (current_name == searched_pin_name) {
            return k
        }
    }
    return ""
}

function render_svg(layer,    filename, dpi, scale, pw, ph, inst, model, type, pins, row_w, cx, cy, i, j, px, py, u_net, prio, color, opacity, p1_coord, p2_coord, x1, y1, x2, y2, part1, pin1, part2, pin2, phys_p1, phys_p2, current_seen, q) {
    dpi = 300
    scale = 30 
    
    # ASCII char code 34 is the standard double-quote (")
    # This blinda the output file against XML header parsing mismatch bugs
    q = sprintf("%c", 34)
    
    if (BOARD_MAX_W + 0 == 0) BOARD_MAX_W = 80
    if (BOARD_MAX_H + 0 == 0) BOARD_MAX_H = 60
    
    pw = int(BOARD_MAX_W * scale)
    ph = int(BOARD_MAX_H * scale)
    filename = "board_" layer ".svg"
    
    # W3C COMPLIANCE FIRED: Forcing double quotes via string injection to bypass browser style alert blocks
    print "<?xml version=" q "1.0" q " encoding=" q "UTF-8" q " standalone=" q "no" q "?>" > filename
    print "<svg xmlns=" q "http://w3.org" q " width=" q pw "px" q " height=" q ph "px" q " viewBox=" q "0 0 " pw " " ph q ">" >> filename
    
    # Internal component style guidelines
    print "<style>text { font-family: 'Courier New', Courier, monospace; user-select: none; text-rendering: optimizeLegibility; }</style>" >> filename
    
    # Dark green FR4 core substrate masking layer
    print "<rect width='" pw "' height='" ph "' fill='rgb(26,51,30)' stroke='rgb(15,31,18)' stroke-width='4'/>" >> filename
    
    # Standard grid layout pin matrices
    for (i = 1; i < BOARD_MAX_W; i++) {
        for (j = 1; j < BOARD_MAX_H; j++) {
            px = int(i * scale)
            py = int(j * scale)
            if (layer == "bottom") px = int(pw - px)
            print "<circle cx='" px "' cy='" py "' r='3' fill='rgb(17,17,11)' stroke='rgb(212,175,55)' stroke-width='1'/>" >> filename
        }
    }
    
    if (layer == "top") {
        delete current_seen
        for (inst in COMP_INST_MODEL) {
            if (inst == "" || inst == "COB" || current_seen[inst]++) continue
            
            model = COMP_INST_MODEL[inst]
            type = COMP_LIB_TYPE[model]
            pins = COMP_LIB_PINS[model]
            row_w = COMP_LIB_ROW_W[model]
            
            cx = int((COMP_POS_X[inst] + 0) * scale)
            cy = int((COMP_POS_Y[inst] + 0) * scale)
            
            if (cx == 0 || cy == 0) continue 
            
            if (type == "DIP") {
                print "<rect x='" (cx - 5) "' y='" (cy - 5) "' width='" int((row_w * scale) + 10) "' height='" int(((((pins/2)-1) * scale) + 10)) "' fill='none' stroke='rgb(255,255,255)' stroke-width='2' stroke-dasharray='4,2'/>" >> filename
                print "<path d='M " int(cx + (row_w*scale)/2 - 10) " " cy " A 10 10 0 0 0 " int(cx + (row_w*scale)/2 + 10) " " cy "' fill='none' stroke='rgb(255,255,255)' stroke-width='2'/>" >> filename
                print "<text x='" int(cx + (row_w*scale)/2) "' y='" int(cy + ((pins/4)*scale)) "' fill='rgb(255,255,255)' font-size='14' font-weight='bold' text-anchor='middle'>" inst ":" model "</text>" >> filename
            } else if (type == "SIL" || type == "CON") {
                print "<rect x='" (cx - 5) "' y='" (cy - 5) "' width='10' height='" int((((pins-1) * scale) + 10)) "' fill='none' stroke='rgb(255,255,255)' stroke-width='2'/>" >> filename
                print "<text x='" (cx + 15) "' y='" (cy + 10) "' fill='rgb(255,255,255)' font-size='10'>" inst "</text>" >> filename
            } else if (type == "DSC") {
                print "<circle cx='" int(cx + scale/2) "' cy='" int(cy + scale/2) "' r='12' fill='none' stroke='rgb(255,204,102)' stroke-width='2'/>" >> filename
                print "<text x='" int(cx + scale/2) "' y='" int(cy + scale/2 + 4) "' fill='rgb(255,204,102)' font-size='8' font-weight='bold' text-anchor='middle'>" inst "</text>" >> filename
            }
        }
    } else if (layer == "bottom") {
        for (i = 1; i <= ROUTE_COUNT; i++) {
            u_net = ROUTES[i, "net"]
            prio = NET_PRIORITY[u_net]
            
            part1 = ROUTES[i, "p1_part"]
            pin1  = ROUTES[i, "p1_pin_num"]
            part2 = ROUTES[i, "p2_part"]
            pin2  = ROUTES[i, "p2_pin_num"]
            
            if (part1 == "" || part2 == "" || part1 == "COB" || part2 == "COB") continue
            
            phys_p1 = svg_lookup_physical_pin(COMP_INST_MODEL[part1], pin1)
            phys_p2 = svg_lookup_physical_pin(COMP_INST_MODEL[part2], pin2)
            
            if (phys_p1 == "") phys_p1 = (pin1 ~ /^[0-9]+$/) ? pin1 : "1"
            if (phys_p2 == "") phys_p2 = (pin2 ~ /^[0-9]+$/) ? pin2 : "1"
            
            delete p1_coord; delete p2_coord
            get_pin_grid_coords(part1, phys_p1, p1_coord)
            get_pin_grid_coords(part2, phys_p2, p2_coord)
            
            x1 = int(pw - (((p1_coord["X"] + 0) == 0 ? 1 : (p1_coord["X"] + 0)) * scale))
            y1 = int(((p1_coord["Y"] + 0) == 0 ? 1 : (p1_coord["Y"] + 0)) * scale)
            x2 = int(pw - (((p2_coord["X"] + 0) == 0 ? 1 : (p2_coord["X"] + 0)) * scale))
            y2 = int(((p2_coord["Y"] + 0) == 0 ? 1 : (p2_coord["Y"] + 0)) * scale)
            
            if (prio == 1) { 
                if (u_net ~ /^(GND|DGND|VSS|AGND)$/) color = "rgb(0,0,0)"; 
                else color = "rgb(255,0,0)"; 
                opacity = "0.9"; 
            } 
            else if (prio == 2) { color = "rgb(0,0,255)"; opacity = "0.8"; }     
            else if (prio == 3) { color = "rgb(0,255,0)"; opacity = "0.8"; }     
            else if (prio == 4) { color = "rgb(255,255,0)"; opacity = "0.85"; }  
            else if (prio == 5) { color = "rgb(255,0,255)"; opacity = "0.9"; }   
            else { color = "rgb(255,255,255)"; opacity = "0.6"; }                
            
            if (x1 > 0 && y1 > 0 && x2 > 0 && y2 > 0) {
                print "<path d='M " x1 " " y1 " L " x2 " " y1 " L " x2 " " y2 "' fill='none' stroke='" color "' stroke-width='3' stroke-linecap='round' stroke-linejoin='round' opacity='" opacity "'/>" >> filename
                print "<text x='" int(x1 + 6) "' y='" int(y1 + 4) "' fill='rgb(160,160,160)' font-size='8' font-weight='bold'>" part1 "." phys_p1 "</text>" >> filename
                print "<text x='" int(x2 + 6) "' y='" int(y2 + 4) "' fill='rgb(160,160,160)' font-size='8' font-weight='bold'>" part2 "." phys_p2 "</text>" >> filename
            }
        }
    }
    
    print "</svg>" >> filename
    close(filename)
    print "[RENDER] Camada técnica \"" layer "\" salva com sucesso em: " filename > "/dev/stderr"
}

