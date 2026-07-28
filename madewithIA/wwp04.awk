#!/usr/bin/awk -f
# vim: ft=awk ts=4 sw=4 sts=4 et :

# ==============================================================================
# COMPILADOR WIRE WRAP POR FORÇAS DIRECIONADAS COM ROTEAMENTO PRIORITÁRIO
# Matriz Universal de Furos de 0.1 Inch (2.54 mm) - Formato CSV (Vírgula)
# este script foi gerado com IA da Google em 28/07/2026
# revisado por agsb@2026
# ==============================================================================

BEGIN {
    FS = ","; # Define a vírgula como delimitador padrão do CSV
    
    if (!CSV_OUTPUT) CSV_OUTPUT = "lista_corte_prioritaria.csv";

    # SVG 0 = Visão Componentes | 1 = Visao Fios (X mirror)
    if (!MIRROR_X) MIRROR_X = 1; 

    # Dimensões dinâmicas da placa universal (Customizável via -v)
    if (!BOARD_W) BOARD_W = 45;
    if (!BOARD_H) BOARD_H = 20;

    # Parâmetros Físicos e Geométricos
    GRID_PITCH_MM = 2.54;   # Passo padrão de 0.1 polegada por furo
    STRIP_LEN_MM  = 25.0;   # Decapagem padrão por ponta para wrapping
    ROUTING_SLACK = 1.20;   # Fator de folga de 20% para feixes de fiação

    # Constantes da Física da Simulação (Algoritmo Force-Directed Placement)
    ITERATIONS = 150;
    K_ATTRACT  = 0.22;    
    K_REPULSE  = 50.0;    
    STEP_SIZE  = 0.4;
    DAMPING    = 0.94;
    LOOPS      = 120;

    # Pegadas/Footprints de largura padrão de componentes (em furos de 0.1")
    pkg_w["DIP03"] = 4;     # DIP Estreito (0.3" entre linhas de pinos)  
    pkg_w["DIP06"] = 7;     # DIP Largo (0.6" entre linhas de pinos)  
    pkg_w["SIL"]   = 1;     # Single In-Line  
    pkg_w["DISC"]  = 3;     # Componentes Discretos Axiais (Resistores/Diodos)  

    # Pesos de Atração Física para o Algoritmo (Packamento mais denso de redes críticas)
    net_weight["VCC"]     = 5.0; 
    net_weight["GND"]     = 5.0; 
    net_weight["VSS"]     = 5.0;
    net_weight["data"]    = 3.5; 
    net_weight["address"] = 3.5; 
    net_weight["control"] = 2.5;

    # Tabela Industrial de Cores AWG 30 Kynar para fiação ordenada
    color_map["VCC"] = "VERMELHO"; 
    color_map["GND"] = "PRETO"; 
    color_map["VSS"] = "PRETO";
    color_map["data"] = "AZUL"; 
    color_map["address"] = "VERDE"; 
    color_map["control"] = "AMARELO";
    color_fallback = "BRANCO";

    # Definição Estrita de Níveis de Prioridade para Montagem Segura
    # prio_map == 5 reservado para extensoes

    LESS_PRIO = 6;

    prio_map["VCC"]     = 1; 
    prio_map["GND"]     = 1; 
    prio_map["VSS"]     = 1;
    prio_map["data"]    = 2;
    prio_map["address"] = 3;
    prio_map["control"] = 4;



    print "==================================================================";
    print "     COMPILADOR WIRE WRAP PRO: ENGINE DE POSICIONAMENTO E ROTEAMENTO";
    printf "     GRID DE 0.1\": %d x %d Furos (%.1fmm x %.1fmm)\n", BOARD_W, BOARD_H, (BOARD_W * GRID_PITCH_MM), (BOARD_H * GRID_PITCH_MM);
    print "==================================================================\n";
}

# ------------------------------------------------------------------------------
# 1. PARSER DOS ARQUIVOS CSV DE ENTRADA
# ------------------------------------------------------------------------------

# FILTRO 1: Arquivo de Componentes com Pinout Separado por Barra Vertical
(NF == 4 || NF == 5) && $1 != "id" && $2 ~ /^(DIP03|DIP06|SIL|DISC)$/ {
    name = $1; 
    type = $2; 
    pins = $3; 
    status = $4; 
    pin_data = $5;
    
    chips[++chip_count] = name;
    chip_type[name] = type;
    chip_pins[name] = pins;
    
    if (type == "DIP03" || type == "DIP06") {
        chip_h[name] = int(pins / 2); 
        chip_w[name] = pkg_w[type];
    } else if (type == "SIL") {
        chip_h[name] = pins; 
        chip_w[name] = pkg_w[type];
    } else { 
        chip_h[name] = 1; 
        chip_w[name] = pkg_w["DISC"];
        };

    compute_pin_offsets(name, type, pins);

    if (pin_data != "") {
        split(pin_data, pairs, "|");
        for (p_idx in pairs) {
            split(pairs[p_idx], map, ":");
            p_num  = map[1]; p_name = map[2];
            pin_num_to_name[name, p_num] = p_name;
            pin_name_to_num[name, p_name] = p_num;
            };
        };

    if (status ~ /^anchor_/) {
        chip_anchor[name] = 1;
        split(status, anchor_parts, "_");
        cx[name] = anchor_parts[2]; cy[name] = anchor_parts[3];
    } else {
        chip_anchor[name] = 0;
        cx[name] = (BOARD_W / 2) + (rand() - 0.5) * 8;
        cy[name] = (BOARD_H / 2) + (rand() - 0.5) * 8;
        };
    next;
}

# FILTRO 2: Arquivo de Netlist Inteligente (Formato: chip,pin,wire)
NF == 3 && $1 != "chip" && $3 != "" {
    ch = $1; 
    raw_p = $2; 
    net_name = $3;

    delayed_wires_count++;
    delayed_chip[delayed_wires_count] = ch;
    delayed_raw_p[delayed_wires_count] = raw_p;
    delayed_wire_net[delayed_wires_count] = net_name;
    next;
}

# ------------------------------------------------------------------------------
# 2. FUNÇÕES GEOMÉTRICAS E UTENSÍLIOS AUXILIARES
# ------------------------------------------------------------------------------

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
    } else if (type == "SIL") {
        for (i = 1; i <= pins; i++) { 
            pin_x[c, i] = 0; 
            pin_y[c, i] = i - 1; 
            };
    } else if (type == "DISC") {
        pin_x[c, 1] = 0; 
        pin_y[c, 1] = 0; 
        pin_x[c, 2] = pkg_w["DISC"] - 1; 
        pin_y[c, 2] = 0;
        };
}

function resolve_pin_number(c, raw_val) {
    if ((c, raw_val) in pin_name_to_num) return pin_name_to_num[c, raw_val];
    return raw_val;
}

function has_node_registered(net, chip, pin,   i) {
    for (i = 1; i <= net_nodes_count[net]; i++) {
        if (net_nodes[net, i, "chip"] == chip && net_nodes[net, i, "pin"] == pin) return 1;
    };
    return 0;
}

# ------------------------------------------------------------------------------
# 3. BLOCO DE PROCESSAMENTO (END) - EXECUÇÃO COMPLETA
# ------------------------------------------------------------------------------
END {

if (chip_count == 0) {
    print "[ERRO] Nenhum componente carregado. Verifique os delimitadores do CSV.";
    exit 1;
};

# Resolução de mapeamento lógicos do netlist
for (w = 1; w <= delayed_wires_count; w++) {
    ch = delayed_chip[w];
    p_num = resolve_pin_number(ch, delayed_raw_p[w]);
    net = delayed_wire_net[w];

    if (!has_node_registered(net, ch, p_num)) {
        idx = ++net_nodes_count[net];
        net_nodes[net, idx, "chip"] = ch; 
        net_nodes[net, idx, "pin"] = p_num;
        };
    pin_connected[ch, p_num] = 1;

    pin_to_net_mapped[ch, p_num] = net;

    if (!net_registered[net]) {
        net_list[++distinct_nets_count] = net; net_registered[net] = 1;
        };

    if (net ~ /[0-9]+$/) {
        match(net, /[A-Za-z_]+/); 
        net_bus_root[net] = substr(net, RSTART, RLENGTH);
    } else {
        net_bus_root[net] = net;
        };
    }

# --- EXECUÇÃO DO ALGORITMO DE FORÇAS DIRECIONADAS (POSICIONAMENTO OTIMIZADO) ---
for (step = 1; step <= ITERATIONS; step++) {

    # Inicia os valores
    for (i = 1; i <= chip_count; i++) { 
        u = chips[i]; 
        fx[u] = 0; 
        fy[u] = 0; 
        };

    # Componente vs Componente (Força Repulsiva de Overlap)
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
                if (!chip_anchor[u]) { fx[u] += (dx / dist) * f_rep; fy[u] += (dy / dist) * f_rep; };
                if (!chip_anchor[v]) { fx[v] -= (dx / dist) * f_rep; fy[v] -= (dy / dist) * f_rep; };
                };
            };
        };

    # Atração de Malhas (Força de Mola Estabilizadora)
    for (n = 1; n <= distinct_nets_count; n++) {
        net = net_list[n]; 
        net_root = net_bus_root[net];
        u = net_nodes[net, 1, "chip"]; 
        u_p = net_nodes[net, 1, "pin"];
        
        for (idx = 2; idx <= net_nodes_count[net]; idx++) {
            v = net_nodes[net, idx, "chip"]; 
            v_p = net_nodes[net, idx, "pin"];
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
                fy[v] += (dy / dist) * f_att; 
                };
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

# Bloqueio das coordenadas finais no Grid discreto
for (i = 1; i <= chip_count; i++) { 
    u = chips[i]; 
    snap_x[u] = int(cx[u] + 0.5); 
    snap_y[u] = int(cy[u] + 0.5); 
    };

# Processamento refinado anticolisão pós-arredondamento
resolved = 0; 
loops = 0;
while (!resolved && loops < LOOPS) {
    resolved = 1; 
    loops++;
    for (i = 1; i <= chip_count; i++) {
        u = chips[i];
        for (j = 1; j <= chip_count; j++) {
            v = chips[j]; 
            if (u == v) continue;
            if (snap_x[u] < snap_x[v] + chip_w[v] && 
                snap_x[u] + chip_w[u] > snap_x[v] && 
                snap_y[u] < snap_y[v] + chip_h[v] && 
                snap_y[u] + chip_h[u] > snap_y[v]) {
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
                if (snap_y[target] > (BOARD_H - chip_h[target])) snap_y[target] = BOARD_H - chip_h[target];}};
            };
        };

# ------------------------------------------------------------------------------
# 4. EXIBIÇÃO DO LAYOUT ASCII COMPLETO DA PCB COM IDENTIFICAÇÃO E POSIÇÃO
# ------------------------------------------------------------------------------
print "----------------------------------------------------------------------------------";
print "[RELATÓRIO 1: DIAGRAMA ASCII DE POSICIONAMENTO REAL DE COMPONENTES]";
print "----------------------------------------------------------------------------------";
# Inicializa o grid com furos vazios
for (y = 1; y <= BOARD_H; y++) {
    for (x = 1; x <= BOARD_W; x++) {
        grid_art[x, y] = "."; 
        };
    };

# Desenha o preenchimento dos chips na matriz
for (i = 1; i <= chip_count; i++) {
    u = chips[i];
    char_id = substr(u, length(u), 1); 

# Pega o caractere numérico do chip (ex: U1 -> 1, R2 -> 2)
    if (char_id !~ /[0-9]/) char_id = substr(u, 1, 1);
    for (y = snap_y[u]; y < snap_y[u] + chip_h[u]; y++) {
        for (x = snap_x[u]; x < snap_x[u] + chip_w[u]; x++) {
            if (x >= 1 && x <= BOARD_W && y >= 1 && y <= BOARD_H) grid_art[x, y] = char_id;
            };
        };

# Aplica a marcação exata das ilhas dos pinos ativos periféricos
    for (p = 1; p <= chip_pins[u]; p++) {
        px = snap_x[u] + pin_x[u, p]; 
        py = snap_y[u] + pin_y[u, p];
        if (px >= 1 && px <= BOARD_W && py >= 1 && py <= BOARD_H) {
# escolhe o simbolo conforme a net
            p_net = pin_to_net_mapped[u,v];
            if (p_net == "VCC") {
                grid_art[px,py] = "+"; 
            } else if (p_net == "GND") {
                grid_art[px,py] = "-";
            } else if (p_net == "VSS") {
                grid_art[px,py] = "~";
            } else {    
                grid_art[px, py] = "o";
                }
        };
    }

# Escreve as réguas superiores e mapa
printf "    "; 

for (x = 1; x <= BOARD_W; x++) printf "%d", x % 10; 
print "";

for (y = 1; y <= BOARD_H; y++) {
    printf "%02d ", y; 
    for (x = 1; x <= BOARD_W; x++) printf "%s", grid_art[x, y]; 
    print "";
    };

print "Legenda: . = Furo | Número/Letra = Pino Ocupado | + = VCC | - = GND | ~ = VSS | o = Pino Ativo";
print "\n-> MAPA COORDENADO DE REFERÊNCIA:";
for (i = 1; i <= chip_count; i++) {
    u = chips[i];
    printf "   Componente %-4s [%-6s] -> Origem (Top-Left) Furo X: %02d, Y: %02d (Tamanho: %dx%d Furos)\n", 
        u, chip_type[u], snap_x[u], snap_y[u], chip_w[u], chip_h[u];
    }

# ------------------------------------------------------------------------------
# 5. CÁLCULO DAISY-CHAIN E SISTEMA DE FILTRAGEM PRIORITÁRIA DE REDES
# ------------------------------------------------------------------------------
# Prepara o arquivo de saída CSV industrial
print "Classe_Prioridade,Rede_Wire,Origem,Destino,Dist_Furos,Compr_Total_mm,Cor_Fio" > CSV_OUTPUT;
# Executa o cálculo Daisy-Chain para todas as redes e joga nas partições de prioridade

for (n = 1; n <= distinct_nets_count; n++) {
    net = net_list[n]; 
    net_root = net_bus_root[net]; 
    total_nodes = net_nodes_count[net];
    wire_color = (net_root in color_map) ? color_map[net_root] : color_fallback;
    if (total_nodes < 2) continue;
# Determina a classe de prioridade da rede
    if (net_root in prio_map) {
        class_idx = prio_map[net_root]; 
# 1 para Power, 2 para Data, 3 para Address, 4 para Control, 5 reserved
    } else {
# 6 para Extras/Gerais
        class_idx = LESS_PRIO; 
        };

    for (i = 1; i <= total_nodes; i++) visited_node[i] = 0;

    curr_node = 1; 
    visited_node[curr_node] = 1;
    for (step_chain = 1; step_chain < total_nodes; step_chain++) {
        u = net_nodes[net, curr_node, "chip"]; 
        u_p = net_nodes[net, curr_node, "pin"];
        u_p_ax = snap_x[u] + pin_x[u, u_p]; 
        u_p_ay = snap_y[u] + pin_y[u, u_p];
        min_d = 999999; 
        next_node = -1;
    
        for (j = 1; j <= total_nodes; j++) {
            if (!visited_node[j]) {
                v = net_nodes[net, j, "chip"]; 
                v_p = net_nodes[net, j, "pin"];
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
        v_p = net_nodes[net, next_node, "pin"];
        lbl_u = ((u, u_p) in pin_num_to_name) ? pin_num_to_name[u, u_p] : u_p;
        lbl_v = ((v, v_p) in pin_num_to_name) ? pin_num_to_name[v, v_p] : v_p;
        src_str = u "." lbl_u; 
        dst_str = v "." lbl_v;
        linear_len_mm = min_d * GRID_PITCH_MM;
        total_len_mm  = (linear_len_mm * ROUTING_SLACK) + (2 * STRIP_LEN_MM);
# Encapitula a linha pronta para ordenação prioritária na tabela correspondente
        line_str = sprintf("%-12s\t%-18s\t%-18s\t%-6d\t%.1f mm\t\t%s", net, src_str, dst_str, min_d, total_len_mm, wire_color);
        csv_str  = sprintf("%d,%s,%s,%s,%d,%.1f,%s", class_idx, net, src_str, dst_str, min_d, total_len_mm, wire_color);
        p_cnt[class_idx]++;
        p_pool[class_idx, p_cnt[class_idx]] = line_str;
        p_csv_pool[class_idx, p_cnt[class_idx]] = csv_str;
        visited_node[next_node] = 1; 
        curr_node = next_node;
        };
    };

print "\n"
# --- IMPRESSÃO DA LISTA DE CONEXÕES EM ORDEM PRIORITÁRIA DE MONTAGEM ---
print "[RELATÓRIO 2: LISTA DE EXECUÇÃO PRIORITÁRIA DE ENROLAMENTO (BANCADA DE TRABALHO)]";
print "Instruções: Execute rigorosamente os Níveis de 1 a 4 sequencialmente para evitar cruzamento caótico de fios.";
print "------------------------------------------------------------------------------------------------------------------------";
# Nível 1: Power & Ground (Alimentação Primária)
print ">>> NÍVEL 1: REDES DE ALIMENTAÇÃO PRINCIPAIS (VCC / GND / VSS) [Fio rente à placa]";
print_priority_class(1);
# Nível 2: Linhas de Dados (Data Bus)
print "\n>>> NÍVEL 2: BARRAMENTOS DE DADOS (data)";
print_priority_class(2);
# Nível 3: Linhas de Endereços (Address Bus)
print "\n>>> NÍVEL 3: BARRAMENTOS DE ENDEREÇOS (address)";
print_priority_class(3);
# Nível 4: Linhas de Controle (Control Bus / Clocks)
print "\n>>> NÍVEL 4: LINHAS DE CONTROLE (control)";
print_priority_class(4);
# Nível 5: Reservado;
# Nível 6: Conexões Extras (Sinais Gerais e Linhas Discretas)
print "\n>>> NÍVEL 6: SINAIS ADICIONAIS / EXTRAS";
print_priority_class(LESS_PRIO);

# ------------------------------------------------------------------------------
# 6. RELATÓRIO DE NÃO CONECTADOS E DIAGNÓSTICO DE PINOS FLUTUANTES
# ------------------------------------------------------------------------------
print "\n==================================================================";
print "       NÍVEL 5: DIAGNÓSTICO DE PINOS NÃO CONECTADOS (FLOATING LOG)";
print "==================================================================";
warnings = 0; 
info_logs = 0;
for (i = 1; i <= chip_count; i++) {
    u = chips[i]; 
    if (chip_type[u] == "DISC") continue;
    for (p = 1; p <= chip_pins[u]; p++) {
        if (!pin_connected[u, p]) {
            lbl = ((u, p) in pin_num_to_name) ? pin_num_to_name[u, p] : p;
            if (lbl == "VCC" || lbl == "GND" || lbl == "VSS") {
                printf "   [ALERTA CRÍTICO: ALIMENTAÇÃO AUSENTE!] -> Componente %s, Pino %d (%s) está sem wire.\n", u, p, lbl;
                warnings++;
            } else {
                printf "   [INFO: Pino Desconectado] Componente %s, Pino %d (%s) deixado livre.\n", u, p, lbl;
                info_logs++;
                };
            };
        };
    }

if (warnings == 0) print "   -> Verificação Concluída: Linhas elétricas vitais de energia 100% integradas.";

printf "\nPlanilha prioritária industrial CSV salva com sucesso: '%s'\n", CSV_OUTPUT;

# ------------------------------------------------------------------------------
# 6. RENDERIZAÇÃO GRÁFICA VETORIAL SVG COM CORES DIFERENCIAIS DE ALIMENTAÇÃO
# ------------------------------------------------------------------------------
svg_w_pixels = (BOARD_W + 2) * PIXELS_PER_HOLE;
svg_h_pixels = (BOARD_H + 2) * PIXELS_PER_HOLE;
print "" > SVG_OUTPUT;
printf "<svg width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\" xmlns=\"w3.org\">\n", 
	svg_w_pixels, svg_h_pixels, svg_w_pixels, svg_h_pixels >> SVG_OUTPUT;
printf "  <rect width=\"100%%\" height=\"100%%\" fill=\"#1e4620\" />\n" >> SVG_OUTPUT;

for (x = 1; x <= BOARD_W; x++) {
	pos_x = (x + 1) * PIXELS_PER_HOLE;
        display_x = MIRROR_X ? (BOARD_W - x + 1) : x ; # inverte a regua
	printf "  <text x=\"%d\" y=\"22\" font-family=\"Arial, sans-serif\" font-size=\"12\" font-weight=\"bold\" fill=\"#ffffff\" text-anchor=\"middle\">%d\n", pos_x, display_x >> SVG_OUTPUT;
	printf "  <text x=\"%d\" y=\"%d\" font-family=\"Arial, sans-serif\" font-size=\"12\" font-weight=\"bold\" fill=\"#ffffff\" text-anchor=\"middle\">%d\n", pos_x, (svg_h_pixels - 10), display_x >> SVG_OUTPUT;
	}

for (y = 1; y <= BOARD_H; y++) {
	pos_y = (y + 1) * PIXELS_PER_HOLE + 4;
	printf "  <text x=\"15\" y=\"%d\" font-family=\"Arial, sans-serif\" font-size=\"12\" font-weight=\"bold\" fill=\"#ffffff\" text-anchor=\"middle\">%02d\n", pos_y, y >> SVG_OUTPUT;
	printf "  <text x=\"%d\" y=\"%d\" font-family=\"Arial, sans-serif\" font-size=\"12\" font-weight=\"bold\" fill=\"#ffffff\" text-anchor=\"middle\">%02d\n", (svg_w_pixels - 15), pos_y, y >> SVG_OUTPUT; 
        }

# Grid de Ilhas de Solda
for (y = 1; y <= BOARD_H; y++) {
	for (x = 1; x <= BOARD_W; x++) {
		px_x = (x + 1) * PIXELS_PER_HOLE;
 		px_y = (y + 1) * PIXELS_PER_HOLE;
		printf "  <circle cx=\"%d\" cy=\"%d\" r=\"5\" fill=\"#ccb254\" opacity=\"0.6\" />\n", 
			px_x, px_y >> SVG_OUTPUT;
		printf "  <circle cx=\"%d\" cy=\"%d\" r=\"1.8\" fill=\"#0b0b0b\" />\n", 
			px_x, px_y >> SVG_OUTPUT;
		};
	};

# Desenho dos Componentes com Ilhas de Cor Estrutural
for (i = 1; i <= chip_count; i++) {
        u = chips[i];
        m_cx = mirror_grid_x(snap_x[u], chip_w[u]);

        rx = (m_cx + 1) * PIXELS_PER_HOLE - (PIXELS_PER_HOLE / 2);
        ry = (snap_y[u] + 1) * PIXELS_PER_HOLE - (PIXELS_PER_HOLE / 2);
        rw = chip_w[u] * PIXELS_PER_HOLE;
        rh = chip_h[u] * PIXELS_PER_HOLE;

        printf "  \n", u >> SVG_OUTPUT;
        printf "  <rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" fill=\"#1c1c1c\" rx=\"6\" stroke=\"#555554\" stroke-width=\"2\" />\n", 
                rx, ry, rw, rh >> SVG_OUTPUT;
        printf "  <text x=\"%d\" y=\"%d\" font-family=\"Arial, sans-serif\" font-size=\"15\" font-weight=\"bold\" fill=\"#ffffff\" text-anchor=\"middle\">%s%s\n", 
                (rx + rw / 2), (ry + rh / 2 + 6), u, (MIRROR_X ? " (BOTTOM)" : "") >> SVG_OUTPUT;

for (p = 1; p <= chip_pins[u]; p++) {
        px_abs = snap_x[u] + pin_x[u, p];
        py_abs = snap_y[u] + pin_y[u, p];
        m_px = mirror_pin_x(px_abs);

        circle_x = (px_abs + 1) * PIXELS_PER_HOLE;
        circle_y = (py_abs + 1) * PIXELS_PER_HOLE;

# Seleciona a cor do pino baseado na rede (wire) atribuídap_net = pin_to_net_mapped[u, p];
        if (p_net == "VCC") {
# Vermelho Vibrante para VCC
                ring_color = "#ff3333";
        } else if (p_net == "GND") {
# Azul para Referência / Terra
                ring_color = "#3366ff";
        } else if (p_net == "VSS") {
# Azul para Referência / VSS
                ring_color = "#3366ff";
        } else {
# Prateado / Cinza para Sinais Comuns};
                ring_color = " #dddddd";

# Desenha a base metalizada colorida sob o pino quadrado de wrap
        printf "  <circle cx=\"%d\" cy=\"%d\" r=\"8\" fill=\"%s\" fill-opacity=\"0.8\" />\n", 
                circle_x, circle_y, ring_color >> SVG_OUTPUT;
        printf "  <rect x=\"%d\" y=\"%d\" width=\"12\" height=\"12\" fill=\"#fcfcfc\" stroke=\"#666666\" stroke-width=\"1\" transform=\"translate(-6,-6) rotate(45 %d %d)\" />\n", 
                circle_x, circle_y, circle_x, circle_y >> SVG_OUTPUT; 
        p_alias = ((u, p) in pin_num_to_name) ? pin_num_to_name[u, p] : p;

        if (chip_type[u] == "DIP03" || chip_type[u] == "DIP06") {
                half_pins = chip_pins[u] / 2;
                if (p <= half_pins) { 
                        text_anchor = "start";
                        font_x = circle_x + 14;
                } else { 
                        text_anchor = "end";
                        font_x = circle_x - 14;
                        };
        } else { 
                text_anchor = "start";
                font_x = circle_x + 14;
                };

        printf "  <text x=\"%d\" y=\"%d\" font-family=\"Consolas, Monaco, monospace\" font-size=\"10\" font-weight=\"bold\" fill=\"#1aff1a\" text-anchor=\"%s\">%s\n", 
                font_x, (circle_y + 4), text_anchor, p_alias >> SVG_OUTPUT;
        };
        
}

print "" >> SVG_OUTPUT;

printf "\nPlanilha prioritária industrial CSV salva com sucesso: '%s'\n", CSV_OUTPUT;

printf "Layout vetorial em escala real 300 DPI gerado com sucesso: '%s'\n", SVG_OUTPUT;

}

function print_priority_class(cls_idx, i) {
        if (p_cnt[cls_idx] == 0) { 
                print "   (Nenhuma linha registrada para esta categoria nesta malha de netlist)";
        } else {
                printf "%-12s\t%-18s\t%-18s\t%-6s\t%-14s\t%s\n", "Rede_Wire", "Origem", "Destino", "Furos", "Comprimento", "Cor do Fio Kynar";
                print "   ------------------------------------------------------------------------------------------------------------------";
                for (i = 1; i <= p_cnt[cls_idx]; i++) { 
                        print "   " p_pool[cls_idx, i];
                        print p_csv_pool[cls_idx, i] >> CSV_OUTPUT;
                        };
        };

}

function print_priority_class(cls_idx, i) {
    if (p_cnt[cls_idx] == 0) {
        print "   (Nenhuma linha registrada para esta categoria nesta malha de netlist)";
        } else {
            printf "%-12s\t%-18s\t%-18s\t%-6s\t%-14s\t%s\n", "Rede_Wire", "Origem", "Destino", "Furos", "Comprimento", "Cor do Fio Kynar";
            print "   ------------------------------------------------------------------------------------------------------------------";
            for (i = 1; i <= p_cnt[cls_idx]; i++) {
                print "   " p_pool[cls_idx, i];
                print p_csv_pool[cls_idx, i] >> CSV_OUTPUT; 
# Salva no arquivo CSV
                };
            };
        }



