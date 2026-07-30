# Fixed Components (Lock to edges/connectors)
# ANCHOR [ChipID] [X] [Y]
#ANCHOR USB_PORT  0   10
#ANCHOR BAR_LED   20  20

# Wire Connections (Netlist)
# [ChipA] [ChipB] [Weight]
#USB_PORT MCU     5
#MCU      RAM     4
#RAM      BAR_LED 3
#MCU      BAR_LED 1

#!/usr/bin/awk -f

# 1. Initialization and Hyperparameters
BEGIN {
    ITERATIONS = 100       # Optimization step cycles
    K_ATTRACT = 0.1        # Hooke's spring constant
    K_REPULSE = 25.0       # Magnetic node repulsion strength
    COOLING = 0.90         # Multiplier to scale down step range
    DAMPING = 0.5          # Initial movement vector dampening
}

# Skip comments and empty whitespace lines
/^[[:space:]]*#/ || /^[[:space:]]*$/ { next }

# 2. Parse Anchor Lines
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

# 3. Parse Wire Connections
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
    # 4. Initialize Non-Anchored Chips Randomly
    srand()
    for (i = 1; i <= num_chips; i++) {
        c = chips[i]
        if (!is_anchored[c]) {
            x[c] = int(rand() * 20)
            y[c] = int(rand() * 20)
        }
    }

    # 5. Force-Directed Optimization Loop
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

        # 6. Apply Forces ONLY to Non-Anchored Nodes
        for (i = 1; i <= num_chips; i++) {
            c = chips[i]
            if (!is_anchored[c]) {
                x[c] += fx[c] * DAMPING
                y[c] += fy[c] * DAMPING
            }
        }

        # Diminish system temperature energy
        DAMPING *= COOLING
    }

    # 7. Print Results (Rounds output values to the closest integer grid hole)
    print "--- Optimized Board Coordinates (With Anchor Flags) ---"
    printf "%-12s | %-6s | %-6s | %-s\n", "Component", "Grid X", "Grid Y", "Status"
    print "--------------------------------------------------------"
    for (i = 1; i <= num_chips; i++) {
        c = chips[i]
        grid_x = int(x[c] + 0.5)
        grid_y = int(y[c] + 0.5)
        status = is_anchored[c] ? "[LOCKED]" : "[AUTO]"
        printf "%-12s | %-6d | %-6d | %-s\n", c, grid_x, grid_y, status
    }
}

# Key Modificationsis_anchored Array Mapping: When the tokenizer hits an ANCHOR indicator, it bypasses random placement and pins those specific X/Y coordinate paths.Conditional Transformation Step: Inside the vector application loop, an if (!is_anchored[c]) gate prevents the physical manipulation of the chip coordinates, ensuring locked components act as immovable gravity wells that pull or push the other floating chips toward optimal zones.
