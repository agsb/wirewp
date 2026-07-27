
#!/usr/bin/awk -f

# ChipA  ChipB     Weight
# MCU    RAM    	5
# MCU    SENSOR 	2
# RAM    DISPLAY 	3

# 1. Parse Input: Build chip list and adjacency matrix
BEGIN {
    # Algorithm Hyperparameters
    ITERATIONS = 100       # Total cooling cycles
    K_ATTRACT = 0.1        # Spring hook constant
    K_REPULSE = 20.0       # Repulsive magnet constant
    COOLING = 0.90         # Temperature dampening factor
    DAMPING = 0.5          # Movement step speed damping
}

# Skip comments or empty lines
/^[[:space:]]*#/ || /^[[:space:]]*$/ { next }

{
    chip1 = $1
    chip2 = $2
    weight = ($3 == "") ? 1 : $3  # Default weight to 1 if missing

    # Track unique chip names
    if (!(chip1 in seen)) { chips[++num_chips] = chip1; seen[chip1] = 1 }
    if (!(chip2 in seen)) { chips[++num_chips] = chip2; seen[chip2] = 1 }

    # Store connection weights bidirectionally
    adj[chip1, chip2] = weight
    adj[chip2, chip1] = weight
}

END {
    # 2. Initialization: Place chips randomly on a 20x20 grid space
    srand()
    for (i = 1; i <= num_chips; i++) {
        c = chips[i]
        x[c] = int(rand() * 20)
        y[c] = int(rand() * 20)
    }

    # 3. Main Optimization Loop
    for (step = 1; step <= ITERATIONS; step++) {
        
        # Reset force vectors for this iteration
        for (i = 1; i <= num_chips; i++) {
            c = chips[i]
            fx[c] = 0
            fy[c] = 0
        }

        # Calculate Repulsive Forces (every chip pushes away every other chip)
        for (i = 1; i <= num_chips; i++) {
            c1 = chips[i]
            for (j = 1; j <= num_chips; j++) {
                if (i == j) continue
                c2 = chips[j]

                dx = x[c1] - x[c2]
                dy = y[c1] - y[c2]
                
                # Avoid division by zero if two chips share exact coordinates
                if (dx == 0 && dy == 0) { dx = 0.1; dy = 0.1 }
                
                dist_sq = (dx * dx) + (dy * dy)
                dist = sqrt(dist_sq)

                # Coulomb's law variant for node spacing
                f_rep = K_REPULSE / dist_sq
                fx[c1] += (dx / dist) * f_rep
                fy[c1] += (dy / dist) * f_rep
            }
        }

        # Calculate Attractive Forces (connected pins pull together)
        for (i = 1; i <= num_chips; i++) {
            c1 = chips[i]
            for (j = 1; j <= num_chips; j++) {
                if (i == j) continue
                c2 = chips[j]

                # Check if a connection exists
                if ((c1, c2) in adj) {
                    dx = x[c2] - x[c1]
                    dy = y[c2] - y[c1]
                    dist = sqrt((dx * dx) + (dy * dy))
                    
                    if (dist == 0) continue

                    # Hooke's law: force proportional to distance and net weight
                    f_att = K_ATTRACT * dist * adj[c1, c2]
                    fx[c1] += (dx / dist) * f_att
                    fy[c1] += (dy / dist) * f_att
                }
            }
        }

        # Update positions using calculated forces and dampening factor
        for (i = 1; i <= num_chips; i++) {
            c = chips[i]
            
            # Step movement bounded by current system temperature limits
            x[c] += fx[c] * DAMPING
            y[c] += fy[c] * DAMPING
        }

        # Cool down the system step energy
        DAMPING *= COOLING
    }

    # 4. Output Results: Round to nearest whole numbers for the universal PCB grid
    print "--- Optimized Chip Placement Grid Coordinates ---"
    printf "%-12s | %-5s | %-5s\n", "Chip ID", "Grid X", "Grid Y"
    print "--------------------------------------------------"
    for (i = 1; i <= num_chips; i++) {
        c = chips[i]
        # Rounding floating math to integer board coordinates
        grid_x = int(x[c] + 0.5)
        grid_y = int(y[c] + 0.5)
        printf "%-12s | %-6d | %-6d\n", c, grid_x, grid_y
    }
}

# How it WorksAdjacency Array: The code maps out connections between chips inside standard multidimensional AWK arrays (adj[chip1, chip2]).Force Calculations: For every cycle, it aggregates spring attractions for pins sharing wires, while calculating geometric pushbacks (K_REPULSE / dist_sq) to keep independent chips from stacking on top of each other.PCB Discretization: At the final stage (END), the continuous coordinate values are mathematically snapped into discrete whole integers (int(val + 0.5)) to map correctly onto the physical grid holes of your prototype board.If you want, I can modify this script to include fixed anchor points (like locking a power connector or USB port to the edge of the board) so the chips arrange around them. Would you like to add that constraint?
