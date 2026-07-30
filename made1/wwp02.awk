#!/usr/bin/awk -f

# use with -v BOARD_W=60 -v BOARD_H=40 -v CSV_FILE=file_name

# ---------------------------------------------------------
# 1. INICIALIZAÇÃO & CONFIGURAÇÕES GLOBAIS
# ---------------------------------------------------------
BEGIN {

    if (!CSV_FILE) CSV_FILE = "wwp_list.csv";

# Tamanho padrão caso o usuário não informe via parâmetro '-v'
# Ajustado para visualização confortável no terminal

    if (!BOARD_W) BOARD_W = 40;
    if (!BOARD_H) BOARD_H = 20;

    ITERATIONS = 150;
    K_ATTRACT  = 0.22;    
    K_REPULSE  = 50.0;    
    STEP_SIZE  = 0.4;
    DAMPING    = 0.94;
    MAX_LOOPS  = 200;

    pkg_w["DIP03"] = 4;   
    pkg_w["DIP06"] = 7;   
    pkg_w["SIL"]   = 1;   
    pkg_w["DISC"]  = 3;   

    net_weight["VCC"]     = 5.0; 
    net_weight["GND"]     = 5.0; 
    net_weight["VSS"]     = 5.0;
    net_weight["data"]    = 3.5; 
    net_weight["address"] = 3.5; 
    net_weight["control"] = 2.5;

    color_map["VCC"] = "VERMELHO"; 
    color_map["GND"] = "PRETO"; 
    color_map["data"] = "AZUL";
    color_map["address"] = "VERDE"; 
    color_map["control"] = "AMARELO"; 
    color_fallback = "BRANCO";

    GRID_PITCH_MM = 2.54; 
    STRIP_LEN_MM = 25.0; 
    ROUTING_SLACK = 1.20;

    print "==================================================================";
    print "    COMPILADOR WIRE WRAP SUPREMO: RENDERIZADOR GRÁFICO ATIVADO";
    print "==================================================================";
}

{

# ---------------------------------------------------------
# 2. PARSING DOS COMANDOS DE ENTRADA
# ---------------------------------------------------------
$1 == "chip" {
    name = $2; 
    type = $3; 
    pins = $4; 
    is_anchor = ($5 == "anchor") ? 1 : 0;

    if (!(name in chip_exists)) {
        chips[++chip_count] = name; 
        chip_exists[name] = 1;
        chip_type[name] = type; 
        chip_pins[name] = pins; 
        chip_anchor[name] = is_anchor;
        
        if (type == "DIP03" || type == "DIP06") {
            chip_h[name] = int(pins / 2); 
            chip_w[name] = pkg_w[type];
            } 
        else if (type == "SIL") {
            chip_h[name] = pins; 
            chip_w[name] = pkg_w[type];
            }
        else { 
            chip_h[name] = 1; 
            chip_w[name] = pkg_w["DISC"];
            };

        compute_pin_offsets(name, type, pins);
        srand();
        cx[name] = (BOARD_W / 2) + (rand() - 0.5) * 6;
        cy[name] = (BOARD_H / 2) + (rand() - 0.5) * 6;
        };
    next;
    }

$1 == "pinname" {
    pin_num_to_name[$2, $3] = $4; pin_name_to_num[$2, $4] = $3; next;
    }

$1 == "anchor" {
    name = $2; chip_anchor[name] = 1; cx[name] = $3; cy[name] = $4; next;
    }

$1 == "wire" {
    net = $2;
    if (net ~ /[0-9]+$/) { match(net, /[A-Za-z_]+/); root = substr(net, RSTART, RLENGTH); } else { root = net; };
    net_nodes_count[net]++;
    net_nodes[net, net_nodes_count[net], "chip"] = $3;
    net_nodes[net, net_nodes_count[net], "raw_pin"] = $4;
    net_bus_root[net] = root;
    if (!net_registered[net]) { 
        net_list[++distinct_nets_count] = net; 
        net_registered[net] = 1; 
        };
    next;
    }

$1 == "keepout" {
    koz_count++; koz_x[koz_count] = $2; koz_y[koz_count] = $3; koz_w[koz_count] = $4; koz_h[koz_count] = $5; next;
    }
}

function compute_pin_offsets(c, type, pins, half, i) {
    if (type == "DIP03" || type == "DIP06") {
        half = pins / 2;
        for (i = 1; i <= half; i++) { 
            pin_x[c, i] = 0; 
            pin_y[c, i] = i - 1; 
            };
        for (i = half + 1; i <= pins; i++) { 
            pin_x[c, i] = pkg_w[type] - 1; 
            pin_y[c, i] = pins - i; 
            };
        } 
    else if (type == "SIL") {
        for (i = 1; i <= pins; i++) { 
            pin_x[c, i] = 0; 
            pin_y[c, i] = i - 1; 
            };
        } 
    else if (type == "DISC") {
        pin_x[c, 1] = 0; 
        pin_y[c, 1] = 0; 
        pin_x[c, 2] = pkg_w["DISC"]-1; 
        pin_y[c, 2] = 0;
        };
    }

function resolve_pin_number(c, raw_val) {
    if ((c, raw_val) in pin_name_to_num) return pin_name_to_num[c, raw_val]; 
    return raw_val;
    }

function inside_keepout(x, y, w, h, k) {
    for (k = 1; k <= koz_count; k++) {
        if (x < koz_x[k] + koz_w[k] && x + w > koz_x[k] && y < koz_y[k] + koz_h[k] && y + h > koz_y[k]) return k;
        }; 
    return 0;
    }

# ---------------------------------------------------------
# 3. MAPEAMENTO DE FORÇAS DIRECIONADAS E ALGORITMO DE SNAP
# ---------------------------------------------------------
END {

    for (n = 1; n <= distinct_nets_count; n++) {
        net = net_list[n];
        for (idx = 1; idx <= net_nodes_count[net]; idx++) {
            ch = net_nodes[net, idx, "chip"]; 
            r_p = net_nodes[net, idx, "raw_pin"];
            p_num = resolve_pin_number(ch, r_p); 
            net_nodes[net, idx, "pnum"] = p_num;
            pin_connected[ch, p_num] = 1;
            };
        };

    for (step = 1; step <= ITERATIONS; step++) {
        for (i = 1; i <= chip_count; i++) {
            u = chips[i]; 
            fx[u] = 0; 
            fy[u] = 0; 
            };
        for (i = 1; i < chip_count; i++) {
            u = chips[i];
            for (j = i + 1; j <= chip_count; j++) {
                v = chips[j]; 
                dx = cx[u] - cx[v]; 
                dy = cy[u] - cy[v];
                if (dx == 0 && dy == 0) { 
                    dx = 0.5; 
                    dy = 0.5; 
                    };
                dist = sqrt((dx * dx) + (dy * dy));
                min_dist = (chip_w[u] + chip_w[v] + chip_h[u] + chip_h[v]) / 4;
                if (dist < min_dist) {
                    f_rep = (K_REPULSE * min_dist) / (dist * dist);
                    if (!chip_anchor[u]) { 
                        fx[u] += (dx / dist) * f_rep; 
                        fy[u] += (dy / dist) * f_rep; 
                        };
                    if (!chip_anchor[v]) { 
                        fx[v] -= (dx / dist) * f_rep; 
                        fy[v] -= (dy / dist) * f_rep; 
                        };
                    };
                };
            };

        for (i = 1; i <= chip_count; i++) {
            u = chips[i]; if (chip_anchor[u]) continue;
            for (k = 1; k <= koz_count; k++) {
                if (cx[u] < koz_x[k] + koz_w[k] && cx[u] + chip_w[u] > koz_x[k] && cy[u] < koz_y[k] + koz_h[k] && cy[u] + chip_h[u] > koz_y[k]) {
                    dx = (cx[u] + chip_w[u]/2) - (koz_x[k] + koz_w[k]/2); 
                    dy = (cy[u] + chip_h[u]/2) - (koz_y[k] + koz_h[k]/2);
                    if (dx == 0 && dy == 0) { 
                        dx = 0.5; 
                        dy = 0.5; 
                        }; 
                    dist = sqrt((dx * dx) + (dy * dy));
                    fx[u] += (dx / dist) * K_REPULSE; 
                    fy[u] += (dy / dist) * K_REPULSE;
                    };
                };
            };

        for (n = 1; n <= distinct_nets_count; n++) {
            net = net_list[n]; 
            net_root = net_bus_root[net]; 
            u = net_nodes[net, 1, "chip"]; 
            u_p = net_nodes[net, 1, "pnum"];
            for (idx = 2; idx <= net_nodes_count[net]; idx++) {
                v = net_nodes[net, idx, "chip"]; 
                v_p = net_nodes[net, idx, "pnum"];
                u_px = cx[u] + pin_x[u, u_p]; 
                u_py = cy[u] + pin_y[u, u_p];
                v_px = cx[v] + pin_x[v, v_p]; 
                v_py = cy[v] + pin_y[v, v_p];
                dx = u_px - v_px; 
                dy = u_py - v_py; 
                dist = sqrt((dx * dx) + (dy * dy));
                if (dist < 0.5) continue;
                weight = (net_root in net_weight) ? net_weight[net_root] : 1.0;
                f_att = K_ATTRACT * dist * weight;
                if (!chip_anchor[u]) { 
                    fx[u] -= (dx / dist) * f_att; 
                    fy[u] -= (dy / dist) * f_att; 
                    };
                if (!chip_anchor[v]) { 
                    fx[v] += (dx / dist) * f_att; 
                    fy[v] += (dy / dist) * f_att; };
                };
            };

        for (i = 1; i <= chip_count; i++) {
            u = chips[i]; if (chip_anchor[u]) continue;
            cx[u] += fx[u] * STEP_SIZE; 
            cy[u] += fy[u] * STEP_SIZE;
            if (cx[u] < 1) cx[u] = 1; 
            if (cx[u] > (BOARD_W - chip_w[u])) cx[u] = BOARD_W - chip_w[u];
            if (cy[u] < 1) cy[u] = 1; 
            if (cy[u] > (BOARD_H - chip_h[u])) cy[u] = BOARD_H - chip_h[u];
            };

        STEP_SIZE *= DAMPING;
        }

    for (i = 1; i <= chip_count; i++) { 
        u = chips[i]; 
        snap_x[u] = int(cx[u] + 0.5); 
        snap_y[u] = int(cy[u] + 0.5); 
        };

    resolved = 0; 
    loops = 0;
    
    while (!resolved && loops < MAX_LOOPS) {
        resolved = 1; 
        loops++;
        for (i = 1; i <= chip_count; i++) {
            u = chips[i];
            for (j = 1; j <= chip_count; j++) {
                v = chips[j]; 
                if (u == v) continue;
                if (snap_x[u] < snap_x[v] + chip_w[v] && snap_x[u] + chip_w[u] > snap_x[v] && snap_y[u] < snap_y[v] + chip_h[v] && snap_y[u] + chip_h[u] > snap_y[v]) {
                    resolved = 0; 
                    target = (chip_anchor[u]) ? v : u; 
                    shifter = (chip_anchor[u]) ? u : v;
                    if (snap_x[shifter] <= snap_x[target]) snap_x[target] += 1; 
                    else snap_x[target] -= 1;
                    if (snap_y[shifter] <= snap_y[target]) snap_y[target] += 1; 
                    else snap_y[target] -= 1;
                    if (snap_x[target] < 1) snap_x[target] = 1; 
                    if (snap_x[target] > (BOARD_W - chip_w[target])) snap_x[target] = BOARD_W - chip_w[target];
                    if (snap_y[target] < 1) snap_y[target] = 1; 
                    if (snap_y[target] > (BOARD_H - chip_h[target])) snap_y[target] = BOARD_H - chip_h[target];
                    };
                };

            if (!chip_anchor[u]) {
                kz_hit = inside_keepout(snap_x[u], snap_y[u], chip_w[u], chip_h[u]);
                if (kz_hit > 0) {
                    resolved = 0;
                    if (snap_x[u] >= koz_x[kz_hit]) snap_x[u] += 2; 
                    else snap_x[u] -= 2;
                    if (snap_y[u] >= koz_y[kz_hit]) snap_y[u] += 2; 
                    else snap_y[u] -= 2;
                    if (snap_x[u] < 1) snap_x[u] = 1; 
                    if (snap_x[u] > (BOARD_W - chip_w[u])) snap_x[u] = BOARD_W - chip_w[u];
                    if (snap_y[u] < 1) snap_y[u] = 1; 
                    if (snap_y[u] > (BOARD_H - chip_h[u])) snap_y[u] = BOARD_H - chip_h[u];
                    }
                };
            };
        }
    print "\n";

# ---------------------------------------------------------
# 4. MOTOR DE RENDERIZAÇÃO DA MATRIZ GRÁFICA ASCII
# ---------------------------------------------------------
    print "==================================================================";
    print "           VISUALIZAÇÃO DA MATRIZ DA PLACA UNIVERSAL (ASCII ART)";
    print "==================================================================";
    
# Inicializa a matriz vazia da placa com pontos de furos (•)
    for (y = 1; y <= BOARD_H; y++) {
        for (x = 1; x <= BOARD_W; x++) {
            grid_art[x, y] = ".";
            };
        };

# Estampa as Zonas de Exclusão (Keep-Out) com o caractere 'X'
    for (k = 1; k <= koz_count; k++) {
		for (y = koz_y[k]; y < koz_y[k] + koz_h[k]; y++) {
			for (x = koz_x[k]; x < koz_x[k] + koz_w[k]; x++) {
				if (x >= 1 && x <= BOARD_W && y >= 1 && y <= BOARD_H) {
					grid_art[x, y] = "X";
					};
				};
			};
		};

# Desenha o contorno do corpo e as marcações de pinos de cada componente
    for (i = 1; i <= chip_count; i++) {
        u = chips[i];
        cx_u = snap_x[u];
        cy_u = snap_y[u];
        cw_u = chip_w[u];
        ch_u = chip_h[u];

# Preenche a área do corpo do componente na placa universal
        for (y = cy_u; y < cy_u + ch_u; y++) {
            for (x = cx_u; x < cx_u + cw_u; x++) {
                if (x >= 1 && x <= BOARD_W && y >= 1 && y <= BOARD_H) {
                    grid_art[x, y] = "#"; # Representa o encapsulamento plástico
                    };
                };
            };

# Coloca a primeira letra do ID do chip no centro dele para identificação
	    mid_x = int(cx_u + cw_u / 2);
	    mid_y = int(cy_u + ch_u / 2);
	    if (mid_x >= 1 && mid_x <= BOARD_W && mid_y >= 1 && mid_y <= BOARD_H) {
		    grid_art[mid_x, mid_y] = substr(u, 1, 1);
		    };

# Marca os pinos físicos ativos periféricos com 'o' na tela
        for (p = 1; p <= chip_pins[u]; p++) {
	        px_abs = cx_u + pin_x[u, p];
	        py_abs = cy_u + pin_y[u, p];
	        if (px_abs >= 1 && px_abs <= BOARD_W && py_abs >= 1 && py_abs <= BOARD_H) {
		        grid_art[px_abs, py_abs] = "o";
		    };
	    };
    };

# Imprime a matriz completa renderizada com numeração de borda do grid
    printf "   ";
    for (x = 1; x <= BOARD_W; x++) printf "%d", x % 10;
    print "";

    for (y = 1; y <= BOARD_H; y++) {
	    printf "%02d ", y;

	    for (x = 1; x <= BOARD_W; x++) {
		    printf "%s", grid_art[x, y];
		    };
	    print "";
	    };

    print "Legenda: . = Furo Livre | X = Keepout | # = Corpo Componente | o = Pino Ativo | Letra = Centro do Componente";

# ---------------------------------------------------------
# 5. INSTRUÇÕES DE CORTE DAISY-CHAIN & GERAÇÃO DO CSV
# ---------------------------------------------------------
    print "Sinal; Origem; Destino; Furos; Comprimento_Decapagem_mm; Comprimento_Total_mm; Cor_Fio_Kynar" > CSV_FILE;
    print "\n"
    print "==================================================================";
    print "                 LISTA DE CORTE E DECAPAGEM DAISY-CHAIN";
    print "==================================================================";
    printf "%-8s\t%-14s\t%-14s\t%-8s\t%-12s\t%-12s\t%s\n", "Sinal", "Origem", "Destino", "Furos", "Decapar(x2)", "Compr. Total", "Cor do Fio";
    print "" "------------------------------------------------------------------------------------------------------------------------";

    for (n = 1; n <= distinct_nets_count; n++) {
	    net = net_list[n];
 	    net_root = net_bus_root[net];
 	    total_nodes = net_nodes_count[net];
	    wire_color = (net_root in color_map) ? color_map[net_root] : color_fallback;
	    if (total_nodes < 2) continue;

	    for (i = 1; i <= total_nodes; i++) {
		    visited_node[i] = 0;
 		    };

	    curr_node = 1;
 	    visited_node[curr_node] = 1;

	    for (step_chain = 1; step_chain < total_nodes; step_chain++) {
		    u = net_nodes[net, curr_node, "chip"];
 		    u_p = net_nodes[net, curr_node, "pnum"];
		    u_p_ax = snap_x[u] + pin_x[u, u_p];
 		    u_p_ay = snap_y[u] + pin_y[u, u_p];
		    min_d = 999999;
 		    next_node = -1;

		    for (j = 1; j <= total_nodes; j++) {
			    if (!visited_node[j]) {
				    v = net_nodes[net, j, "chip"];
				    v_p = net_nodes[net, j, "pnum"];
				    dx = u_p_ax - (snap_x[v] + pin_x[v, v_p]);
 				    if (dx < 0) dx = -dx;
				    dy = u_p_ay - (snap_y[v] + pin_y[v, v_p]);
 				    if (dy < 0) dy = -dy;
				    curr_d = dx + dy;
				    if (curr_d < min_d) {
					    min_d = curr_d;
 					    next_node = j;
 					    };
				    };
			    };

		    v = net_nodes[net, next_node, "chip"];
 		    v_p = net_nodes[net, next_node, "pnum"];
		    bus_total_dist[net_root] += min_d;
		    bus_wires_calculated_count[net_root]++;
		    linear_len_mm = min_d * GRID_PITCH_MM;
		    total_len_mm  = (linear_len_mm * ROUTING_SLACK) + (2 * STRIP_LEN_MM);
		    src_alias = ((u, u_p) in pin_num_to_name) ? pin_num_to_name[u, u_p] : u_p;
		    dst_alias = ((v, v_p) in pin_num_to_name) ? pin_num_to_name[v, v_p] : v_p;
		    src_str = u "." src_alias;
		    dst_str = v "." dst_alias;
		    printf "%-8s\t%-14s\t%-14s\t%-8d\t%.1f mm\t\t%.1f mm\t\t%s\n", net, src_str, dst_str, min_d, STRIP_LEN_MM, total_len_mm, wire_color;
		    printf "%s; %s; %s; %d; %.1f; %.1f; %s\n", net, src_str, dst_str, min_d, STRIP_LEN_MM, total_len_mm, wire_color >> CSV_FILE;
		    visited_node[next_node] = 1;
 		    curr_node = next_node;
		    };
	    };

    print "\n"

print "==================================================================";
print "                 ANÁLISE DE BUSSING & ERROS DE CONEXÃO";
print "==================================================================";

for (bus in bus_wires_count) {
	if (bus == "VCC" || bus == "GND") continue;
	w_num = bus_wires_calculated_count[bus];
 	if (w_num == 0) w_num = 1;
	avg_dist = bus_total_dist[bus] / w_num;
	printf "Barramento '%s' -> Fios: %d | Dist. Média: %.2f furos -> %s\n", bus, bus_wires_count[bus], avg_dist, (avg_dist > 12.0 ? "[ALERTA: Longo]" : "[OK: Otimizado]");
	};
}


# prompt

# https://www.google.com/search?client=ubuntu-sn&channel=fs&q=with+a+list+of+chips+pins+and+wires+connected+to+pins+which+best+strategy+for+place+the+chips+in+a+pcb+universal+board+using+the+force-direct+approach+in+a+script+awk&udm=50&aep=10&ntc=1&mstk=AUtExfDSeql8vHdvK75UZB0AqIld04LFBaWSMOeinuAJjxabnFvjZFNr9d8JmDV2EHVDBzm0yVgptQigu4hI08wYxV5I2Vj05edI8vXNFEDtS2lbZZc97kBeCdVNS50e-iZ6tCt2DdyvdHTT4IKbr-Mnq-uKyhoRBusoa4279TdgCUl8wzZOoNTyf82oZRy4NzIE8N557uC1AWVv2OLAh7IXe_1quXBh3HMRPyOTsZYtZTU7fTmA9eZO3JRJax4&aioh=3&csuir=1&mtid=brFoauTZH_Lc5OUPqILf0Qc

