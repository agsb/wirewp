
#!/usr/bin/awk -f

# ---------------------------------------------------------
# 1. INICIALIZAÇÃO & PARÂMETROS FÍSICOS DE WIRE WRAP
# ---------------------------------------------------------
BEGIN {
    # Dimensões da placa universal (em furos)
    BOARD_W = 40
    BOARD_H = 30

    # Configurações do Algoritmo
    ITERATIONS = 150
    K_ATTRACT  = 0.22    
    K_REPULSE  = 50.0    
    STEP_SIZE  = 0.4
    DAMPING    = 0.94

    # Dimensões físicas dos pacotes (furos)
    pkg_w["DIP03"] = 4   
    pkg_w["DIP06"] = 7   
    pkg_w["SIL"]   = 1   
    pkg_w["DISC"]  = 3   

    # Pesos de atração para barramentos críticos
    net_weight["VCC"]     = 5.0
    net_weight["GND"]     = 5.0
    net_weight["VSS"]     = 5.0
    net_weight["data"]    = 3.5  
    net_weight["address"] = 3.5  
    net_weight["control"] = 2.5

    # Tabela de Cores de fios Kynar (AWG 30)
    color_map["VCC"]     = "VERMELHO"
    color_map["GND"]     = "PRETO"
    color_map["VSS"]     = "PRETO"
    color_map["data"]    = "AZUL"
    color_map["address"] = "VERDE"
    color_map["control"] = "AMARELO"
    color_fallback       = "BRANCO"

    # --- Parâmetros de Wire Wrap para Lista de Corte ---
    GRID_PITCH_MM = 2.54   # Passo padrão da placa universal (0.1 polegada)
    STRIP_LEN_MM  = 25.0   # 25mm de decapagem em CADA ponta (para ~7 a 8 espiras firmes no pino)
    ROUTING_SLACK = 1.20   # Fator de folga (20% a mais de fio para desviar de pinos e organizar em feixes)

    print "=================================================================="
    print "         COMPILADOR E ANALISADOR DE LAYOUT PARA WIRE WRAP"
    print "=================================================================="
}

# ---------------------------------------------------------
# 2. PARSING DO ARQUIVO DE ENTRADA
# ---------------------------------------------------------
$1 == "chip" {
    name = $2; type = $3; pins = $4;
    is_anchor = ($5 == "anchor") ? 1 : 0
    
    if (!(name in chip_exists)) {
        chips[++chip_count] = name
        chip_exists[name] = 1
        chip_type[name]   = type
        chip_pins[name]   = pins
        chip_anchor[name] = is_anchor
        
        if (type == "DIP03" || type == "DIP06") {
            chip_h[name] = int(pins / 2)
            chip_w[name] = pkg_w[type]
        } else if (type == "SIL") {
            chip_h[name] = pins
            chip_w[name] = pkg_w[type]
        } else { 
            chip_h[name] = 1
            chip_w[name] = pkg_w["DISC"]
        }

        compute_pin_offsets(name, type, pins)

        srand()
        cx[name] = (BOARD_W / 2) + (rand() - 0.5) * 6
        cy[name] = (BOARD_H / 2) + (rand() - 0.5) * 6
    }
    next
}

$1 == "pinname" {
    c_name = $2; p_num = $3; p_name = $4;
    pin_num_to_name[c_name, p_num] = p_name
    pin_name_to_num[c_name, p_name] = p_num
    next
}

$1 == "anchor" {
    name = $2; fx_pos = $3; fy_pos = $4;
    chip_anchor[name] = 1
    cx[name] = fx_pos; cy[name] = fy_pos;
    next
}

$1 == "wire" {
    wire_count++
    net_fullname = $2
    wire_net[wire_count] = net_fullname
    
    # Detecção Automática de Raiz de Barramento (Bus Grouping)
    # Remove números do final da string para achar a raiz (ex: data3 -> data)
    if (net_fullname ~ /[0-9]+$/) {
        match(net_fullname, /[A-Za-z_]+/)
        bus_root = substr(net_fullname, RSTART, RLENGTH)
    } else {
        bus_root = net_fullname
    }
    wire_bus_root[wire_count] = bus_root
    bus_wires_count[bus_root]++
    
    split($3, src_parts, ".")
    wire_src_chip[wire_count] = src_parts
    wire_src_raw[wire_count]  = src_parts
    
    split($4, dst_parts, ".")
    wire_dst_chip[wire_count] = dst_parts
    wire_dst_raw[wire_count]  = dst_parts
    next
}

$1 == "keepout" {
    koz_count++
    koz_x[koz_count] = $2; koz_y[koz_count] = $3;
    koz_w[koz_count] = $4; koz_h[koz_count] = $5;
    next
}

function compute_pin_offsets(c, type, pins,   half, i) {
    if (type == "DIP03" || type == "DIP06") {
        half = pins / 2
        for (i = 1; i <= half; i++) {
            pin_x[c, i] = 0; pin_y[c, i] = i - 1
        }
        for (i = half + 1; i <= pins; i++) {
            pin_x[c, i] = pkg_w[type] - 1; pin_y[c, i] = pins - i
        }
    } else if (type == "SIL") {
        for (i = 1; i <= pins; i++) {
            pin_x[c, i] = 0; pin_y[c, i] = i - 1
        }
    } else if (type == "DISC") {
        pin_x[c, 1] = 0;             pin_y[c, 1] = 0;
        pin_x[c, 2] = pkg_w["DISC"]-1; pin_y[c, 2] = 0;
    }
}

function resolve_pin_number(c, raw_val) {
    if ((c, raw_val) in pin_name_to_num) return pin_name_to_num[c, raw_val]
    return raw_val
}

function inside_keepout(x, y, w, h,    k) {
    for (k = 1; k <= koz_count; k++) {
        if (x < koz_x[k] + koz_w[k] && x + w > koz_x[k] &&
            y < koz_y[k] + koz_h[k] && y + h > koz_y[k]) return k
    }
    return 0
}

# ---------------------------------------------------------
# 3. LOOP ALGORÍTMICO DE FORÇAS DIRECIONADAS
# ---------------------------------------------------------
END {
    for (w = 1; w <= wire_count; w++) {
        u = wire_src_chip[w]
        u_p = resolve_pin_number(u, wire_src_raw[w])
        wire_src_pnum[w] = u_p
        pin_connected[u, u_p] = 1

        v = wire_dst_chip[w]
        v_p = resolve_pin_number(v, wire_dst_raw[w])
        wire_dst_pnum[w] = v_p
        pin_connected[v, v_p] = 1
    }

    for (step = 1; step <= ITERATIONS; step++) {
        for (i = 1; i <= chip_count; i++) {
            u = chips[i]; fx[u] = 0; fy[u] = 0;
        }

        # Forças Repulsivas entre Chips
        for (i = 1; i < chip_count; i++) {
            u = chips[i]
            for (j = i + 1; j <= chip_count; j++) {
                v = chips[j]
                dx = cx[u] - cx[v]; dy = cy[u] - cy[v]
                if (dx == 0 && dy == 0) { dx = 0.5; dy = 0.5; }
                dist = sqrt((dx * dx) + (dy * dy))
                min_dist = (chip_w[u] + chip_w[v] + chip_h[u] + chip_h[v]) / 4
                if (dist < min_dist) {
                    f_rep = (K_REPULSE * min_dist) / (dist * dist)
                    if (!chip_anchor[u]) { fx[u] += (dx / dist) * f_rep; fy[u] += (dy / dist) * f_rep; }
                    if (!chip_anchor[v]) { fx[v] -= (dx / dist) * f_rep; fy[v] -= (dy / dist) * f_rep; }
                }
            }
        }

        # Repulsão das Zonas de Exclusão (Keep-out)
        for (i = 1; i <= chip_count; i++) {
            u = chips[i]; if (chip_anchor[u]) continue
            for (k = 1; k <= koz_count; k++) {
                if (cx[u] < koz_x[k] + koz_w[k] && cx[u] + chip_w[u] > koz_x[k] &&
                    cy[u] < koz_y[k] + koz_h[k] && cy[u] + chip_h[u] > koz_y[k]) {
                    dx = (cx[u] + chip_w[u]/2) - (koz_x[k] + koz_w[k]/2)
                    dy = (cy[u] + chip_h[u]/2) - (koz_y[k] + koz_h[k]/2)
                    if (dx == 0 && dy == 0) { dx = 0.5; dy = 0.5; }
                    dist = sqrt((dx * dx) + (dy * dy))
                    fx[u] += (dx / dist) * K_REPULSE
                    fy[u] += (dy / dist) * K_REPULSE
                }
            }
        }

        # Forças Atrativas baseadas na Raiz do Barramento
        for (w = 1; w <= wire_count; w++) {
            net_root = wire_bus_root[w]
            u = wire_src_chip[w]; u_p = wire_src_pnum[w]
            v = wire_dst_chip[w]; v_p = wire_dst_pnum[w]
            
            u_px = cx[u] + pin_x[u, u_p]; u_py = cy[u] + pin_y[u, u_p]
            v_px = cx[v] + pin_x[v, v_p]; v_py = cy[v] + pin_y[v, v_p]
            
            dx = u_px - v_px; dy = u_py - v_py
            dist = sqrt((dx * dx) + (dy * dy))
            if (dist < 0.5) continue
            
            weight = (net_root in net_weight) ? net_weight[net_root] : 1.0
            f_att = K_ATTRACT * dist * weight
            
            if (!chip_anchor[u]) { fx[u] -= (dx / dist) * f_att; fy[u] -= (dy / dist) * f_att; }
            if (!chip_anchor[v]) { fx[v] += (dx / dist) * f_att; fy[v] += (dy / dist) * f_att; }
        }

        # Atualização de Posições Contínuas
        for (i = 1; i <= chip_count; i++) {
            u = chips[i]; if (chip_anchor[u]) continue
            cx[u] += fx[u] * STEP_SIZE; cy[u] += fy[u] * STEP_SIZE
            
            if (cx[u] < 1) cx[u] = 1
            if (cx[u] > (BOARD_W - chip_w[u])) cx[u] = BOARD_W - chip_w[u]
            if (cy[u] < 1) cy[u] = 1
            if (cy[u] > (BOARD_H - chip_h[u])) cy[u] = BOARD_H - chip_h[u]
        }
        STEP_SIZE *= DAMPING
    }

    # ---------------------------------------------------------
    # 4. ARREDONDAMENTO PARA O GRID & RESOLUÇÃO DE INTERSECÇÃO
    # ---------------------------------------------------------
    for (i = 1; i <= chip_count; i++) {
        u = chips[i]
        snap_x[u] = int(cx[u] + 0.5); snap_y[u] = int(cy[u] + 0.5)
    }

    resolved = 0; loops = 0;
    while (!resolved && loops < 200) {
        resolved = 1; loops++;
        for (i = 1; i <= chip_count; i++) {
            u = chips[i]
            for (j = 1; j <= chip_count; j++) {
                v = chips[j]; if (u == v) continue

                if (snap_x[u] < snap_x[v] + chip_w[v] && snap_x[u] + chip_w[u] > snap_x[v] &&
                    snap_y[u] < snap_y[v] + chip_h[v] && snap_y[u] + chip_h[u] > snap_y[v]) {
                    
                    resolved = 0
                    target = (chip_anchor[u]) ? v : u
                    shifter = (chip_anchor[u]) ? u : v
                    
                    if (snap_x[shifter] <= snap_x[target]) snap_x[target] += 1 else snap_x[target] -= 1
                    if (snap_y[shifter] <= snap_y[target]) snap_y[target] += 1 else snap_y[target] -= 1
                    
                    if (snap_x[target] < 1) snap_x[target] = 1
                    if (snap_x[target] > (BOARD_W - chip_w[target])) snap_x[target] = BOARD_W - chip_w[target]



        if (snap_y[target] < 1) snap_y[target] = 1
        if (snap_y[target] > (BOARD_H - chip_h[target])) snap_y[target] = BOARD_H - chip_h[target]
        }

}


if (!chip_anchor[u]) {

	kz_hit = inside_keepout(snap_x[u], snap_y[u], chip_w[u], chip_h[u])
	
	if (kz_hit > 0) {
		resolved = 0
		if (snap_x[u] >= koz_x[kz_hit]) snap_x[u] += 2
		else snap_x[u] -= 2
		if (snap_y[u] >= koz_y[kz_hit]) snap_y[u] += 2
		else snap_y[u] -= 2
		if (snap_x[u] < 1) snap_x[u] = 1
		if (snap_x[u] > (BOARD_W - chip_w[u])) snap_x[u] = BOARD_W - chip_w[u]
		if (snap_y[u] < 1) snap_y[u] = 1
		if (snap_y[u] > (BOARD_H - chip_h[u])) snap_y[u] = BOARD_H - chip_h[u]}
		}
	}
}

# ---------------------------------------------------------
# 5. RELATÓRIO DE SAÍDA - PARTE 1: COMPONENTES
# ---------------------------------------------------------
print "\n[RELATÓRIO 1: DISPOSIÇÃO FINAL DOS COMPONENTES]"
printf "%-8s\t%-6s\t%-6s\t%-6s\t%-8s\t%s\n", "ID Chip", "Encaps.", "Grid_X", "Grid_Y", "Status", "Matriz (WxH)"
print "------------------------------------------------------------------"
for (i = 1; i <= chip_count; i++) {
	u = chips[i]status = (chip_anchor[u]) ? "ANCHOR" : "DYNAMIC"
	printf "%-8s\t%-6s\t%-6d\t%-6d\t%-8s\t%dx%d\n", u, chip_type[u], snap_x[u], snap_y[u], status, chip_w[u], chip_h[u]
	}

# ---------------------------------------------------------

# 6. RELATÓRIO DE SAÍDA - PARTE 2: LISTA DE CORTE E DECAPAGEM
# ---------------------------------------------------------
print "\n[RELATÓRIO 2: LISTA DE CORTE E DECAPAGEM (CUT & STRIP LIST)]"
print "Instruções: Utilize fio Kynar AWG 30. Use a cor indicada e decape as DUAS pontas na medida informada."
print "------------------------------------------------------------------------------------------------------------------------"
printf "%-8s\t%-14s\t%-14s\t%-8s\t%-12s\t%-12s\t%s\n", "Sinal", "Origem", "Destino", "Furos", "Decapar(x2)", "Compr. Total", "Cor do Fio"
print "------------------------------------------------------------------------------------------------------------------------"
for (w = 1; w <= wire_count; w++) {

	net = wire_net[w]net_root = wire_bus_root[w]
	u = wire_src_chip[w]; u_p = wire_src_pnum[w]
	v = wire_dst_chip[w]; v_p = wire_dst_pnum[w]
# Posições absolutas dos pinos
	u_p_ax = snap_x[u] + pin_x[u, u_p]; 
	u_p_ay = snap_y[u] + pin_y[u, u_p]
	v_p_ax = snap_x[v] + pin_x[v, v_p]; 
	v_p_ay = snap_y[v] + pin_y[v, v_p]
	dx = u_p_ax - v_p_ax; 
	if (dx < 0) dx = -dxdy = u_p_ay - v_p_ay; 
	if (dy < 0) dy = -dymanhattan_dist = dx + dy
# Acumula distância estrutural para análise posterior do barramentobus_total_dist[net_root] += manhattan_dist
# --- Cálculo Físico Real do Fio ---
# Comprimento linear ponto a ponto na placa universal em mmlinear_len_mm = manhattan_dist * GRID_PITCH_MM
# Comprimento total = (Distância Linear * Fator de Folga para Curvas) + (2 pontas de decapagem para as espiras)total_len_mm  = (linear_len_mm * ROUTING_SLACK) + (2 * STRIP_LEN_MM)src_alias = ((u, u_p) in pin_num_to_name) ? pin_num_to_name[u, u_p] : u_pdst_alias = ((v, v_p) in pin_num_to_name) ? pin_num_to_name[v, v_p] : v_pwire_color = (net_root in color_map) ? color_map[net_root] : color_fallback
printf "%-8s\t%s.%-10s\t%s.%-10s\t%-8d\t%.1f mm\t\t%.1f mm\t\t%s\n", net, (u "." src_alias), (v "." dst_alias), manhattan_dist, STRIP_LEN_MM, total_len_mm, wire_color}

# ---------------------------------------------------------
# 7. RELATÓRIO DE SAÍDA - PARTE 3: ANÁLISE DETALHADA DOS BARRAMENTOS
# ---------------------------------------------------------
print "\n[RELATÓRIO 3: ANÁLISE DE AGRUPAMENTO DE BARRAMENTOS (BUSSING)]"
printf "%-14s\t%-12s\t%-16s\t%s\n", "Barramento", "Num Fios", "Dist. Total (Furos)", "Dist. Média/Fio (Alvo: < 12)"
print "------------------------------------------------------------------------------------------------"
for (bus in bus_wires_count) {



if (bus == "VCC" || bus == "GND" || bus == "VSS") continue 
# Ignora barramentos de energia globais na análise de sinalavg_dist = bus_total_dist[bus] / bus_wires_count[bus]
printf "%-14s\t%-12d\t%-16d\t%.2f furos ", bus, bus_wires_count[bus], bus_total_dist[bus], avg_dist
if (avg_dist > 12.0) {


print "[ALERTA: Barramento muito disperso! Risco de trançado caótico e ruído]"}

else {


print "[MÉTRICA OTIMIZADA: Excelente para Wire Wrap em feixe paralelo]"}
}

# ---------------------------------------------------------
# 8. RELATÓRIO DE SAÍDA - PARTE 4: DIAGNÓSTICO DE ERROS
# ---------------------------------------------------------
print "\n[RELATÓRIO 4: DETECÇÃO DE PINOS CRÍTICOS FLUTUANTES]"warnings_found = 0
for (i = 1; i <= chip_count; i++) {

u = chips[i]

if (chip_type[u] == "DISC") continue
for (p = 1; p <= chip_pins[u]; p++) {



if (!pin_connected[u, p]) {

p_alias = ((u, p) in pin_num_to_name) ? pin_num_to_name[u, p] : ""

if (p_alias == "VCC" || p_alias == "GND" || p_alias == "VSS") {


printf "[CRÍTICO] Falha de Alimentação! Componente %s, Pino %d (%s) está sem fio.\n", u, p, p_aliaswarnings_found++}

else 

if (p_alias != "") {


printf "[AVISO] Pino de Sinal %s.%s nominal foi mapeado mas não está conectado no netlist.\n", u, p_aliaswarnings_found++}
}
}
}


if (warnings_found == 0) 
print "Sucesso: Nenhum erro estrutural detectado. Placa pronta para montagem física."}

