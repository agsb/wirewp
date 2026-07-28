
#!/usr/bin/awk -f

# input file:
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


# Troubleshooting

# 1. Identify Spacing and Size Collisions
# variations
# K_REPULSE = 50.0  # Boost this value to push component bodies further apart
# K_ATTRACT = 0.08  # Lower this value to reduce overly aggressive pin pulls

# 2. Verify Pin Numbering and Grid Alignments
# CHECK INGREDIENTS: If total pins = 14, legal target pins are 1 through 14
#CHIP MY_IC DIP 14 3
#NET SPI_DATA TOP MY_IC 7 OTHER_CHIP 2  # Pin 7 is valid (on the bottom row)

# 3. Handle Off-Grid Border Drift
# Lock large connectors safely away from floating logic spaces
#ANCHOR POWER_HDR 2  2  # Lower left corner
#ANCHOR MAIN_MCU  20 10 # Centered target workspace location

# 4. Fix Dual-Layer Trace Crossings (Short Circuits)
# Route primarily horizontal long runs underneath the board
#NET BUS_LINE_H BOT MCU 5 RAM 1
# Route primarily vertical short jumps on top of the board
#NET BUS_LINE_V TOP MCU 6 RAM 2  

# DO IT

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
        
        calculated_holes[w] = holes
        calculated_inches[w] = inches

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

    # 11. PRINT STRATEGIC ASSEMBLY CHECK-OFF SHEET
    print "========================================================================================="
    print "                       PCB PROTOTYPE ASSEMBLY CHECK-OFF SHEET                            "
    print "========================================================================================="
    print "Instructions: Assemble components from lowest profile height to highest profile height.\n"
    
    print "STEP 1: PLACE & SOLDER PASSIVE DISCRETE COMPONENTS (Resistors, Capacitors)"
    print "-----------------------------------------------------------------------------------------"
    printf "[ ]  %-10s | %-8s | Pin 1 Anchor: [%d, %d] | Spans: %d holes\n", "Comp ID", "Type", "X", "Y", "Size"
    print "-----------------------------------------------------------------------------------------"
    for (i = 1; i <= num_chips; i++) {
        c = chips[i]
        if (pkg_type[c] == "DISC") {
            printf "[ ]  %-10s | %-8s | Pin 1 Anchor: [%d, %d] | Spans: %d holes\n", c, pkg_type[c], grid_x[c], grid_y[c], chip_span[c]
        }
    }
    
    print "\nSTEP 2: PLACE & SOLDER PROFILE HARDWARE SOCKETS (IC Sockets & Pin Headers)"
    print "-----------------------------------------------------------------------------------------"
    printf "[ ]  %-10s | %-8s | Pin 1 Anchor: [%d, %d] | Total Size: %d Pins\n", "Comp ID", "Footprint", "X", "Y", "Pins"
    print "-----------------------------------------------------------------------------------------"
    for (i = 1; i <= num_chips; i++) {
        c = chips[i]
        if (pkg_type[c] == "DIP" || pkg_type[c] == "SIL") {
            printf "[ ]  %-10s | %-8s | Pin 1 Anchor: [%d, %d] | Total Size: %d Pins %s\n", c, pkg_type[c], grid_x[c], grid_y[c], chip_pins[c], (is_anchored[c]?"[LOCKED]":"")
        }
    }

    print "\nSTEP 3: CUT, STRIP & ROUTE TOP-LAYER INTERCONNECT WIRES"
    print "-----------------------------------------------------------------------------------------"
    printf "[ ]  %-10s | Cut Length  | Net Destination Paths Map Location\n", "Net Name"
    print "-----------------------------------------------------------------------------------------"
    for (w = 1; w <= num_wires; w++) {
        if (wire_layer[w] == "TOP") {
            c1 = wire_from_c[w]; p1 = wire_from_p[w]; c2 = wire_to_c[w]; p2 = wire_to_p[w]
            p1_x = grid_x[c1] + get_pin_offset(c1, p1, "X"); p1_y = grid_y[c1] + get_pin_offset(c1, p1, "Y")
            p2_x = grid_x[c2] + get_pin_offset(c2, p2, "X"); p2_y = grid_y[c2] + get_pin_offset(c2, p2, "Y")
            printf "[ ]  %-10s | %3.1f\" (%2dmm) | %s(P%s)[%d,%d] ---> %s(P%s)[%d,%d]\n", wire_net[w], calculated_inches[w], (calculated_inches[w]*25.4), c1, p1, p1_x, p1_y, c2, p2, p2_x, p2_y
        }
    }

    print "\nSTEP 4: CUT, STRIP & ROUTE BOTTOM-LAYER SOLDER INTERCONNECT BRIDGES"
    print "-----------------------------------------------------------------------------------------"
    printf "[ ]  %-10s | Cut Length  | Net Destination Paths Map Location\n", "Net Name"
    print "-----------------------------------------------------------------------------------------"
    for (w = 1; w <= num_wires; w++) {
        if (wire_layer[w] == "BOTTOM") {
            c1 = wire_from_c[w]; p1 = wire_from_p[w]; c2 = wire_to_c[w]; p2 = wire_to_p[w]
            p1_x = grid_x[c1] + get_pin_offset(c1, p1, "X"); p1_y = grid_y[c1] + get_pin_offset(c1, p1, "Y")
            p2_x = grid_x[c2] + get_pin_offset(c2, p2, "X"); p2_y = grid_y[c2] + get_pin_offset(c2, p2, "Y")
            printf "[ ]  %-10s | %3.1f\" (%2dmm) | %s(P%s)[%d,%d] ---> %s(P%s)[%d,%d]\n", wire_net[w], calculated_inches[w], (calculated_inches[w]*25.4), c1, p1, p1_x, p1_y, c2, p2, p2_x, p2_y
        }
    }
    
    print "\nSTEP 5: INJECT CHIPS INTO EMBEDDED SOCKET HARDWARE PIPELINES & RUN CONTINUITY TEST"
    print "-----------------------------------------------------------------------------------------"
    for (i = 1; i <= num_chips; i++) {
        c = chips[i]
        if (pkg_type[c] == "DIP") {
		printf "[ ]  Insert Silicon IC Body into Mounted %d-Pin Socket Bracket Base: %s\n", chip_pins[c], c
		}
	}
    print "[ ]  Perform multimeter beep check on all VCC/GND rails to ensure NO short-circuits exist."
    print "=========================================================================================\n"

# 12. DRAW TOP LAYER VISUALIZATION
	print "======================================================================"
	print "   TOP LAYER MAP VISUALIZATION (Component Side - wires route up top)"
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
	print "+\n"

# 13. DRAW BOTTOM LAYER VISUALIZATION
	print "======================================================================"
	print "   BOTTOM LAYER MAP VISUALIZATION (Solder Side - seen from underneath)"
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


