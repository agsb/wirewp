## Board Size Boundaries (Width x Height holes)
#BOARD 40 18
#
## Physical Footprints:
#CHIP MCU      DIP  28 6
#CHIP RAM      DIP  16 3
#CHIP JTAG_HDR SIL  6
#CHIP R1       DISC 4
#
## Mechanical Anchor Points
#ANCHOR JTAG_HDR 0 10
#
## Pin-to-Pin Connections with Layer Assignment (TOP or BOT)
#NET DATA_BUS TOP MCU 5  RAM 1
#NET DATA_BUS BOT MCU 6  RAM 2
#NET TCK      TOP MCU 24 JTAG_HDR 1
#NET TMS      BOT MCU 23 JTAG_HDR 2
#NET RST_LINE TOP MCU 1  R1 1
#
#

#!/usr/bin/awk -f

# 1. Initialization and Hyperparameters
BEGIN {
    ITERATIONS = 120       # Optimization cycles
    K_ATTRACT = 0.15       # Spring tension strength
    K_REPULSE = 35.0       # Magnetic component repulsion strength
    COOLING = 0.90         # Multiplier to scale down step range
    DAMPING = 0.5          # Initial movement vector dampening

    BOARD_MAX_X = 20
    BOARD_MAX_Y = 10
    num_wires = 0
}

# Skip comments and empty lines
/^[[:space:]]*#/ || /^[[:space:]]*$/ { next }

# 2. Parse Board Boundaries
$1 == "BOARD" { BOARD_MAX_X = $2; BOARD_MAX_Y = $3; next }

# 3. Parse Footprints
$1 == "CHIP" {
    chip_id = $2; package = $3; pkg_type[chip_id] = package
    if (package == "DIP") { chip_pins[chip_id] = $4; chip_width[chip_id] = ($5 == "") ? 3 : $5 }
    else if (package == "SIL") { chip_pins[chip_id] = $4 }
    else if (package == "DISC") { chip_pins[chip_id] = 2; chip_span[chip_id] = $4 }
    next
}

# 4. Parse Mechanical Anchor Points
$1 == "ANCHOR" {
    chip = $2; x[chip] = $3; y[chip] = $4; is_anchored[chip] = 1
    if (!(chip in seen)) { chips[++num_chips] = chip; seen[chip] = 1 }
    next
}

# 5. Parse Dual-Layer Pin-to-Pin Connections
$1 == "NET" {
    net_name = $2; layer = $3; c1 = $4; p1 = $5; c2 = $6; p2 = $7

    if (!(c1 in seen)) { chips[++num_chips] = c1; seen[c1] = 1 }
    if (!(c2 in seen)) { chips[++num_chips] = c2; seen[c2] = 1 }

    adj[c1, c2]++
    adj[c2, c1]++

    num_wires++
    wire_net[num_wires]   = net_name
    wire_layer[num_wires] = (layer == "BOT") ? "BOTTOM" : "TOP"
    wire_from_c[num_wires] = c1
    wire_from_p[num_wires] = p1
    wire_to_c[num_wires]   = c2
    wire_to_p[num_wires]   = p2
    next
}

# 6. Pin-Offset Calculator
function get_pin_offset(chip, pin, axis,    type, pins, half, side, pin_idx) {
    type = pkg_type[chip]; pins = chip_pins[chip]
    if (pins == "" || pins == 0) return 0
    if (type == "DIP") {
        half = pins / 2
        if (pin <= half) { side = 0; pin_idx = pin - 1 }
        else { side = 1; pin_idx = pins - pin }
        if (axis == "X") return side * chip_width[chip]
        if (axis == "Y") return pin_idx * 1
    }
    if (type == "SIL") {
        if (axis == "X") return 0
        if (axis == "Y") return pin - 1
    }
    if (type == "DISC") {
        if (axis == "X") return 0
        if (axis == "Y") return (pin == 1) ? 0 : chip_span[chip]
    }
    return 0
}

END {
    # 7. Initial Random Placements
    srand()
    for (i = 1; i <= num_chips; i++) {
        c = chips[i]
        if (!is_anchored[c]) {
            x[c] = int(rand() * (BOARD_MAX_X - 5)) + 1
            y[c] = int(rand() * (BOARD_MAX_Y - 7)) + 1
        }
    }

    # 8. Force-Directed Physics Optimization Loop
    for (step = 1; step <= ITERATIONS; step++) {
        for (i = 1; i <= num_chips; i++) { c = chips[i]; fx[c] = 0; fy[c] = 0 }
        for (i = 1; i <= num_chips; i++) {
            c1 = chips[i]
            for (j = 1; j <= num_chips; j++) {
                if (i == j) continue
                c2 = chips[j]
                dx = x[c1] - x[c2]; dy = y[c1] - y[c2]
                if (dx == 0 && dy == 0) { dx = 0.1; dy = 0.1 }
                dist_sq = (dx * dx) + (dy * dy)
                f_rep = K_REPULSE / dist_sq
                fx[c1] += (dx / sqrt(dist_sq)) * f_rep; fy[c1] += (dy / sqrt(dist_sq)) * f_rep
            }
        }
        for (i = 1; i <= num_chips; i++) {
            c1 = chips[i]
            for (j = 1; j <= num_chips; j++) {
                if (i == j) continue
                c2 = chips[j]
                if ((c1, c2) in adj) {
                    dx = x[c2] - x[c1]; dy = y[c2] - y[c1]; dist = sqrt((dx * dx) + (dy * dy))
                    if (dist == 0) continue
                    f_att = K_ATTRACT * dist * adj[c1, c2]
                    fx[c1] += (dx / dist) * f_att; fy[c1] += (dy / dist) * f_att
                }
            }
        }
        for (i = 1; i <= num_chips; i++) {
            c = chips[i]
            if (!is_anchored[c]) {
                x[c] += fx[c] * DAMPING; y[c] += fy[c] * DAMPING
                if (x[c] < 0) x[c] = 0; if (x[c] > BOARD_MAX_X) x[c] = BOARD_MAX_X
                if (y[c] < 0) y[c] = 0; if (y[c] > BOARD_MAX_Y) y[c] = BOARD_MAX_Y
            }
        }
        DAMPING *= COOLING
    }

    # 9. Snap Core Origins & Build Footprints + Trace Layers
    for (i = 1; i <= num_chips; i++) {
        c = chips[i]; gx = int(x[c] + 0.5); gy = int(y[c] + 0.5)
        grid_x[c] = gx; grid_y[c] = gy
        
        # Save structural locations
        base_matrix[gx, gy] = substr(c, 1, 1)
        total_p = chip_pins[c]
        for (p = 1; p <= total_p; p++) {
            px = gx + get_pin_offset(c, p, "X"); py = gy + get_pin_offset(c, p, "Y")
            if (px <= BOARD_MAX_X && py <= BOARD_MAX_Y) {
                if (base_matrix[px, py] == "") base_matrix[px, py] = "o" 
            }
        }
    }

    # 10. Dual-Layer Wire Evaluation & Matrix Marking
    top_in = 0; bot_in = 0
    for (w = 1; w <= num_wires; w++) {
        c1 = wire_from_c[w]; p1 = wire_from_p[w]; c2 = wire_to_c[w]; p2 = wire_to_p[w]
        p1_x = grid_x[c1] + get_pin_offset(c1, p1, "X"); p1_y = grid_y[c1] + get_pin_offset(c1, p1, "Y")
        p2_x = grid_x[c2] + get_pin_offset(c2, p2, "X"); p2_y = grid_y[c2] + get_pin_offset(c2, p2, "Y")
        
        dx = p1_x - p2_x; if (dx < 0) dx = -dx
        dy = p1_y - p2_y; if (dy < 0) dy = -dy
        holes = dx + dy
        inches = (holes * 0.1) + 0.2
        
        # Mark targeted terminal holes on the respective layer maps
        if (wire_layer[w] == "TOP") {
            top_in += inches
            top_layer_traces[p1_x, p1_y] = "#"
            top_layer_traces[p2_x, p2_y] = "#"
        } else {
            bot_in += inches
            bot_layer_traces[p1_x, p1_y] = "*"
            bot_layer_traces[p2_x, p2_y] = "*"
        }
    }

    # 11. Print Layout Data Tables
    print "--- Component Core Origin Grid Coordinates ---"
    printf "%-3s | %-12s | %-6s | %-6s | %-s\n", "ID", "Component", "Grid X", "Grid Y", "Footprint Details"
    print "------------------------------------------------------------"
    for (i = 1; i <= num_chips; i++) {
        c = chips[i]
        printf "[%s] | %-12s | %-6d | %-6d | %s (%d pins)\n", substr(c,1,1), c, grid_x[c], grid_y[c], pkg_type[c], chip_pins[c]
    }
    print "-----------------------------------------------------------------------------------------------"
    printf "TOTAL TOP WIRE REQUIRED   : %.1f inches (%.1f mm)\n", top_in, (top_in * 25.4)
    printf "TOTAL BOTTOM WIRE REQUIRED: %.1f inches (%.1f mm)\n", bot_in, (bot_in * 25.4)

    # 12. DRAW TOP LAYER VISUALIZATION
    print "\n======================================================================"
    print "   TOP LAYER MAP VISUALIZATION (Component Side - wires route up top)"
    print "   [ # = Wire Terminal Pin / Connection Node, o = Passive Component Pin ]"
    print "======================================================================"
    printf "   +"
    for (col = 0; col <= BOARD_MAX_X; col++) printf "-"
    print "+"
    for (row = BOARD_MAX_Y; row >= 0; row--) {
        printf "%2d |", row
        for (col = 0; col <= BOARD_MAX_X; col++) {
            if ((col, row) in top_layer_traces) printf "#"
            else if ((col, row) in base_matrix) printf "%s", base_matrix[col, row]
            else printf "."
        }
        print "|"
    }
    printf "   +"
    for (col = 0; col <= BOARD_MAX_X; col++) printf "-"
    print "+"

    # 13. DRAW BOTTOM LAYER VISUALIZATION
    print "\n======================================================================"
    print "   BOTTOM LAYER MAP VISUALIZATION (Solder Side - seen from underneath)"
    print "   [ * = Solder Bridge / Bottom Wire Node, o = Unused Pin Pad Hole ]"
    print "======================================================================"
    printf "   +"
    for (col = 0; col <= BOARD_MAX_X; col++) printf "-"
    print "+"
    for (row = BOARD_MAX_Y; row >= 0; row--) {
        printf "%2d |", row
        for (col = 0; col <= BOARD_MAX_X; col++) {
            if ((col, row) in bot_layer_traces) printf "*"
            else if ((col, row) in base_matrix) printf "%s", base_matrix[col, row]
            else printf "."
        }
        print "|"
    }
    printf "   +"
    for (col = 0; col <= BOARD_MAX_X; col++) printf "-"
    print "+"
}

