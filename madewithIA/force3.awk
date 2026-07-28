## Define PCB Dimensions (Max Width and Max Height holes)
## BOARD [Max_X] [Max_Y]
#BOARD 30 20
#
## Fixed Components (Anchored)
#ANCHOR USB_PORT  0   10
#ANCHOR BAR_LED   30  20
#
## Wire Connections (Netlist)
#USB_PORT MCU     5
#MCU      RAM     4
#RAM      BAR_LED 3
#MCU      BAR_LED 1

#!/usr/bin/awk -f

# 1. Initialization and Hyperparameters
BEGIN {
    ITERATIONS = 100       # Optimization cycles
    K_ATTRACT = 0.1        # Hooke's spring constant
    K_REPULSE = 25.0       # Magnetic node repulsion strength
    COOLING = 0.90         # Multiplier to scale down step range
    DAMPING = 0.5          # Initial movement vector dampening

    # Default board limits if not specified in the input file
    BOARD_MAX_X = 20
    BOARD_MAX_Y = 20
}

# Skip comments and empty whitespace lines
/^[[:space:]]*#/ || /^[[:space:]]*$/ { next }

# 2. Parse Board Dimension Configuration
$1 == "BOARD" {
    BOARD_MAX_X = $2
    BOARD_MAX_Y = $3
    next
}

# 3. Parse Anchor Lines
$1 == "ANCHOR" {
    chip = $2
    fixed_x = $3
    fixed_y = $4

    # Log coordinates and flag as locked
    x[chip] = fixed_x
    y[chip] = fixed_y
    is_anchored[chip] = 1

    if (!(chip in seen)) { chips[++num_chips] = chip; seen[chip] = 1 }
    next
}

# 4. Parse Wire Connections
{
    chip1 = $1
    chip2 = $2
    weight = ($3 == "") ? 1 : $3

    if (!(chip1 in seen)) { chips[++num_chips] = chip1; seen[chip1] = 1 }
    if (!(chip2 in seen)) { chips[++num_chips] = chip2; seen[chip2] = 1 }

    adj[chip1, chip2] = weight
    adj[chip2, chip1] = weight
}

END {
    # 5. Initialize Non-Anchored Chips Randomly within the Boundaries
    srand()
    for (i = 1; i <= num_chips; i++) {
        c = chips[i]
        if (!is_anchored[c]) {
            x[c] = int(rand() * BOARD_MAX_X)
            y[c] = int(rand() * BOARD_MAX_Y)
        }
    }

    # 6. Force-Directed Optimization Loop
    for (step = 1; step <= ITERATIONS; step++) {
        
        # Reset current force tracking vectors
        for (i = 1; i <= num_chips; i++) {
            c = chips[i]
            fx[c] = 0
            fy[c] = 0
        }

        # Calculate Repulsive Forces
        for (i = 1; i <= num_chips; i++) {
            c1 = chips[i]
            for (j = 1; j <= num_chips; j++) {
                if (i == j) continue
                c2 = chips[j]

                dx = x[c1] - x[c2]
                dy = y[c1] - y[c2]
                
                if (dx == 0 && dy == 0) { dx = 0.1; dy = 0.1 }
                
                dist_sq = (dx * dx) + (dy * dy)
                dist = sqrt(dist_sq)

                f_rep = K_REPULSE / dist_sq
                fx[c1] += (dx / dist) * f_rep
                fy[c1] += (dy / dist) * f_rep
            }
        }

        # Calculate Attractive Forces
        for (i = 1; i <= num_chips; i++) {
            c1 = chips[i]
            for (j = 1; j <= num_chips; j++) {
                if (i == j) continue
                c2 = chips[j]

                if ((c1, c2) in adj) {
                    dx = x[c2] - x[c1]
                    dy = y[c2] - y[c1]
                    dist = sqrt((dx * dx) + (dy * dy))
                    
                    if (dist == 0) continue

                    f_att = K_ATTRACT * dist * adj[c1, c2]
                    fx[c1] += (dx / dist) * f_att
                    fy[c1] += (dy / dist) * f_att
                }
            }
        }

        # 7. Apply Forces and Clip Positions to Hard Boundaries
        for (i = 1; i <= num_chips; i++) {
            c = chips[i]
            if (!is_anchored[c]) {
                x[c] += fx[c] * DAMPING
                y[c] += fy[c] * DAMPING

                # Hard Boundary Clamping (Enforce 0 to BOARD_MAX limits)
                if (x[c] < 0) x[c] = 0
                if (x[c] > BOARD_MAX_X) x[c] = BOARD_MAX_X
                if (y[c] < 0) y[c] = 0
                if (y[c] > BOARD_MAX_Y) x[c] = BOARD_MAX_Y # Safety fix below
                if (y[c] > BOARD_MAX_Y) y[c] = BOARD_MAX_Y
            }
        }

        # Diminish system temperature energy
        DAMPING *= COOLING
    }

    # 8. Print Results Map
    print "--- Board Constraints Configuration ---"
    printf "Board Boundaries: 0 to %d (X) | 0 to %d (Y)\n\n", BOARD_MAX_X, BOARD_MAX_Y
    print "--- Optimized Board Coordinates ---"
    printf "%-12s | %-6s | %-6s | %-s\n", "Component", "Grid X", "Grid Y", "Status"
    print "--------------------------------------------------------"
    for (i = 1; i <= num_chips; i++) {
        c = chips[i]
        grid_x = int(x[c] + 0.5)
        grid_y = int(y[c] + 0.5)
        
        # Final safety catch for rounded output bounds
        if (grid_x < 0) grid_x = 0
        if (grid_x > BOARD_MAX_X) grid_x = BOARD_MAX_X
        if (grid_y < 0) grid_y = 0
        if (grid_y > BOARD_MAX_Y) grid_y = BOARD_MAX_Y

        status = is_anchored[c] ? "[LOCKED]" : "[AUTO]"
        printf "%-12s | %-6d | %-6d | %-s\n", c, grid_x, grid_y, status
    }
}

