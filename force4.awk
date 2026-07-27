#!/usr/bin/awk -f

## Define Board Boundaries (Width x Height holes)
#BOARD 30 12
#
## Fixed Hardware Anchor Points
#ANCHOR USB_PORT  0   6
#ANCHOR OLED      30  12
#
## Circuit Netlist Connections (ComponentA ComponentB Weight)
#USB_PORT MCU     5
#MCU      RAM     4
#RAM      OLED    3
#MCU      OLED    1
#

# 1. Initialization and Hyperparameters
BEGIN {
    ITERATIONS = 120       # Optimization cycles
    K_ATTRACT = 0.12       # Hooke's spring constant
    K_REPULSE = 28.0       # Magnetic component repulsion strength
    COOLING = 0.90         # Multiplier to scale down step range
    DAMPING = 0.5          # Initial movement vector dampening

    # Default fallback board limits
    BOARD_MAX_X = 20
    BOARD_MAX_Y = 10
}

# Skip comments and empty lines
/^[[:space:]]*#/ || /^[[:space:]]*$/ { next }

# 2. Parse Configuration Input
$1 == "BOARD"  { BOARD_MAX_X = $2; BOARD_MAX_Y = $3; next }
$1 == "ANCHOR" {
    chip = $2; x[chip] = $3; y[chip] = $4; is_anchored[chip] = 1
    if (!(chip in seen)) { chips[++num_chips] = chip; seen[chip] = 1 }
    next
}

# 3. Parse Wire Connections
{
    chip1 = $1; chip2 = $2; weight = ($3 == "") ? 1 : $3
    if (!(chip1 in seen)) { chips[++num_chips] = chip1; seen[chip1] = 1 }
    if (!(chip2 in seen)) { chips[++num_chips] = chip2; seen[chip2] = 1 }
    adj[chip1, chip2] = weight; adj[chip2, chip1] = weight
}

END {
    # 4. Initialize Floating Chips Randomly Inside Board Bounds
    srand()
    for (i = 1; i <= num_chips; i++) {
        c = chips[i]
        if (!is_anchored[c]) {
            x[c] = int(rand() * (BOARD_MAX_X - 2)) + 1
            y[c] = int(rand() * (BOARD_MAX_Y - 2)) + 1
        }
    }

    # 5. Force-Directed Physics Optimization Loop
    for (step = 1; step <= ITERATIONS; step++) {
        for (i = 1; i <= num_chips; i++) { c = chips[i]; fx[c] = 0; fy[c] = 0 }

        # Calculate Repulsive Forces
        for (i = 1; i <= num_chips; i++) {
            c1 = chips[i]
            for (j = 1; j <= num_chips; j++) {
                if (i == j) continue
                c2 = chips[j]
                dx = x[c1] - x[c2]; dy = y[c1] - y[c2]
                if (dx == 0 && dy == 0) { dx = 0.1; dy = 0.1 }
                dist_sq = (dx * dx) + (dy * dy); dist = sqrt(dist_sq)
                f_rep = K_REPULSE / dist_sq
                fx[c1] += (dx / dist) * f_rep; fy[c1] += (dy / dist) * f_rep
            }
        }

        # Calculate Attractive Forces
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

        # 6. Apply Forces and Clip Positions to Board Boundaries
        for (i = 1; i <= num_chips; i++) {
            c = chips[i]
            if (!is_anchored[c]) {
                x[c] += fx[c] * DAMPING; y[c] += fy[c] * DAMPING
                if (x[c] < 0) x[c] = 0
                if (x[c] > BOARD_MAX_X) x[c] = BOARD_MAX_X
                if (y[c] < 0) y[c] = 0
                if (y[c] > BOARD_MAX_Y) y[c] = BOARD_MAX_Y
            }
        }
        DAMPING *= COOLING
    }

    # 7. Coordinate Snapping and Map Preparation
    for (i = 1; i <= num_chips; i++) {
        c = chips[i]
        gx = int(x[c] + 0.5); gy = int(y[c] + 0.5)
        
        # Enforce bounds clamping on rounded values
        if (gx < 0) gx = 0; if (gx > BOARD_MAX_X) gx = BOARD_MAX_X
        if (gy < 0) gy = 0; if (gy > BOARD_MAX_Y) gy = BOARD_MAX_Y
        
        grid_x[c] = gx; grid_y[c] = gy
        
        # Use first character of Chip ID as its ASCII visual marker icon
        marker = substr(c, 1, 1)
        
        # Resolve collisions on the ASCII map screen matrix
        if (map_occupied[gx, gy] != "") {
            # Offset slightly if a slot is already taken on the text grid
            if (gx < BOARD_MAX_X) gx++; else gx--
        }
        map_matrix[gx, gy] = marker
        map_occupied[gx, gy] = c
    }

    # 8. Print Coordinate Table Output
    print "--- Optimized Component Placement Coordinates ---"
    printf "%-3s | %-12s | %-6s | %-6s | %-s\n", "ID", "Component", "Grid X", "Grid Y", "Status"
    print "--------------------------------------------------------"
    for (i = 1; i <= num_chips; i++) {
        c = chips[i]
        printf "[%s] | %-12s | %-6d | %-6d | %-s\n", substr(c,1,1), c, grid_x[c], grid_y[c], (is_anchored[c] ? "LOCKED" : "AUTO")
    }

    # 9. Draw ASCII PCB Grid Map
    print "\n--- Universal PCB Board Map Visualization ---"
    
    # Top border line
    printf "   +"
    for (col = 0; col <= BOARD_MAX_X; col++) printf "-"
    print "+"

    # Board rows (Iterate from Max Y down to 0)
    for (row = BOARD_MAX_Y; row >= 0; row--) {
        printf "%2d |", row
        for (col = 0; col <= BOARD_MAX_X; col++) {
            if ((col, row) in map_matrix) {
                printf "%s", map_matrix[col, row]
            } else {
                printf "."  # Dot represents an empty solder hole
            }
        }
        print "|"
    }

    # Bottom border line
    printf "   +"
    for (col = 0; col <= BOARD_MAX_X; col++) printf "-"
    print "+"
    
    # Column tens alignment hint row
    printf "    "
    for (col = 0; col <= BOARD_MAX_X; col++) {
        if (col % 10 == 0) printf "%d", col / 10
        else printf " "
    }
    print ""
}

