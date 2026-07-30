
cat << 'EOF' > gerar_pcb_300dpi.awk
#!/usr/bin/awk -f

# ==============================================================================
# RENDERIZADOR PCB SVG: TAMANHO NATURAL 300 DPI COM ENUMERAÇÃO E PINAGEM LOGICA
# Processamento Independente via Arquivos CSV (Separados por Vírgula)
# ==============================================================================

BEGIN {
    FS = ","; # Define a vírgula como delimitador do CSV de entrada
    
    # Configuração dinâmica das dimensões da PCB (Modificável via -v no terminal)
    if (!BOARD_W) BOARD_W = 45;
    if (!BOARD_H) BOARD_H = 20;

    # Densidade de pixels para escala 1:1 real
    # 300 DPI -> 300 pixels por polegada -> passo de 0.1" (furo) = 30 pixels exatos
    PIXELS_PER_HOLE = 30;

    # Dimensões físicas dos corpos dos pacotes (em furos de 0.1")
    pkg_w["DIP03"] = 4;   
    pkg_w["DIP06"] = 7;   
    pkg_w["SIL"]   = 1;   
    pkg_w["DISC"]  = 3;   

    SVG_OUTPUT = "placa_layout_300dpi.svg";
}

# ------------------------------------------------------------------------------
# 1. PARSER DOS DADOS DE COMPONENTES E PINAGENS
# ------------------------------------------------------------------------------

# FILTRO 1: Identifica o arquivo de componentes (4 ou 5 Colunas)
(NF == 4 || NF == 5) && $1 != "id" && $2 ~ /^(DIP03|DIP06|SIL|DISC)$/ {
    name = $1; 
    type = $2; 
    pins = $3; 
    status = $4; 
    pin_data = $5;
    
    chips[++chip_count] = name;
    chip_type[name] = type;
    chip_pins[name] = pins;
    
    # Calcula dimensões da carcaça do componente
    if (type == "DIP03" || type == "DIP06") {
        chip_h[name] = int(pins / 2); chip_w[name] = pkg_w[type];
    } else if (type == "SIL") {
        chip_h[name] = pins; chip_w[name] = pkg_w[type];
    } else { 
        chip_h[name] = 1; chip_w[name] = pkg_w["DISC"];
    };

    compute_pin_offsets(name, type, pins);

    # Extrai o mapeamento da pinagem lógica funcional (ex: 1:MOSI|2:MISO)
    if (pin_data != "") {
        split(pin_data, pairs, "|");
        for (p_idx in pairs) {
            split(pairs[p_idx], map, ":");
            p_num  = map[1];
            p_name = map[2];
            pin_num_to_name[name, p_num] = p_name;
        };
    };

    # Recupera a coordenada final calculada obtida pelo algoritmo anterior
    if (status ~ /^[0-9]+_[0-9]+$/) {
        split(status, pos_parts, "_");
        snap_x[name] = pos_parts[1];
        snap_y[name] = pos_parts[2];
    } else if (status ~ /^anchor_/) {
        split(status, anchor_parts, "_");
        snap_x[name] = anchor_parts[2];
        snap_y[name] = anchor_parts[3];
    } else {
        # Fallback de segurança se o componente estiver sem posição gravada
        snap_x[name] = 2 + (chip_count * 5) % (BOARD_W - 8);
        snap_y[name] = 4;
    };
    next;
}

# FILTRO 2: Ignora cabeçalhos ou linhas fora de escopo
{ next; }

# ------------------------------------------------------------------------------
# 2. FUNÇÕES AUXILIARES GEOMÉTRICAS
# ------------------------------------------------------------------------------

function compute_pin_offsets(c, type, pins,   half, i) {
    if (type == "DIP03" || type == "DIP06") {
        half = pins / 2;
        for (i = 1; i <= half; i++) { pin_x[c, i] = 0; pin_y[c, i] = i - 1; };
        for (i = half + 1; i <= pins; i++) { pin_x[c, i] = pkg_w[type] - 1; pin_y[c, i] = pins - i; };
    } else if (type == "SIL") {
        for (i = 1; i <= pins; i++) { pin_x[c, i] = 0; pin_y[c, i] = i - 1; };
    } else if (type == "DISC") {
        pin_x[c, 1] = 0; pin_y[c, 1] = 0; pin_x[c, 2] = pkg_w["DISC"] - 1; pin_y[c, 2] = 0;
    };
}

# ------------------------------------------------------------------------------
# 3. GERAÇÃO COMPLETA DO MODELO GRÁFICO VETORIAL SVG
# ------------------------------------------------------------------------------
END {
    if (chip_count == 0) {
        print "[ERRO] Nenhum dado de componente válido foi processado para renderizar o SVG.";
        exit 1;
    };

    # Adiciona margem de segurança periférica para as réguas numéricas exteriores
    svg_w_pixels = (BOARD_W + 2) * PIXELS_PER_HOLE;
    svg_h_pixels = (BOARD_H + 2) * PIXELS_PER_HOLE;

    # Inicializa a estrutura do arquivo de imagem vetorial
    print "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?>" > SVG_OUTPUT;
    printf "<svg width=\"%d\" height=\"%d\" viewBox=\"0 0 %d %d\" xmlns=\"http://w3.org\">\n", svg_w_pixels, svg_h_pixels, svg_w_pixels, svg_h_pixels >> SVG_OUTPUT;
    
    # Máscara de solda / Plano de fundo da PCB (Verde Escuro)
    printf "  <rect width=\"100%%\" height=\"100%%\" fill=\"#143a16\" />\n" >> SVG_OUTPUT;

    # --- DESENHO DAS RÉGUAS DE INDICAÇÃO COMERCIAL DE COLUNAS/LINHAS ---
    # Eixo X (Numeração das Colunas de furos)
    for (x = 1; x <= BOARD_W; x++) {
        pos_x = (x + 1) * PIXELS_PER_HOLE;
        printf "  <text x=\"%d\" y=\"20\" font-family=\"Arial, sans-serif\" font-size=\"11\" font-weight=\"bold\" fill=\"#ffffff\" text-anchor=\"middle\">%d</text>\n", pos_x, x >> SVG_OUTPUT;
        printf "  <text x=\"%d\" y=\"%d\" font-family=\"Arial, sans-serif\" font-size=\"11\" font-weight=\"bold\" fill=\"#ffffff\" text-anchor=\"middle\">%d</text>\n", pos_x, (svg_h_pixels - 10), x >> SVG_OUTPUT;
    }
    # Eixo Y (Numeração das Linhas de furos)
    for (y = 1; y <= BOARD_H; y++) {
        pos_y = (y + 1) * PIXELS_PER_HOLE + 4;
        printf "  <text x=\"15\" y=\"%d\" font-family=\"Arial, sans-serif\" font-size=\"11\" font-weight=\"bold\" fill=\"#ffffff\" text-anchor=\"middle\">%02d</text>\n", pos_y, y >> SVG_OUTPUT;
        printf "  <text x=\"%d\" y=\"%d\" font-family=\"Arial, sans-serif\" font-size=\"11\" font-weight=\"bold\" fill=\"#ffffff\" text-anchor=\"middle\">%02d</text>\n", (svg_w_pixels - 15), pos_y, y >> SVG_OUTPUT;
    }

    # --- DESENHO DO GRID DE ILHAS DE SOLDA DA PLACA PADRÃO 0.1\" ---
    for (y = 1; y <= BOARD_H; y++) {
        for (x = 1; x <= BOARD_W; x++) {
            px_x = (x + 1) * PIXELS_PER_HOLE;
            px_y = (y + 1) * PIXELS_PER_HOLE;
            # Cobre circular dourado exposto
            printf "  <circle cx=\"%d\" cy=\"%d\" r=\"5.5\" fill=\"#ccb35a\" opacity=\"0.5\" />\n", px_x, px_y >> SVG_OUTPUT;
            # Furo metalizado centralizado
            printf "  <circle cx=\"%d\" cy=\"%d\" r=\"1.8\" fill=\"#080808\" />\n", px_x, px_y >> SVG_OUTPUT;
        };
    };

    # --- DESENHO DOS CHIPS, NÚMEROS DE PINOS E PINAGEM LÓGICA ---
    for (i = 1; i <= chip_count; i++) {
        u = chips[i];
        
        # Converte as coordenadas absolutas para a escala de pixels 300 DPI
        rx = (snap_x[u] + 1) * PIXELS_PER_HOLE - (PIXELS_PER_HOLE / 2);
        ry = (snap_y[u] + 1) * PIXELS_PER_HOLE - (PIXELS_PER_HOLE / 2);
        rw = chip_w[u] * PIXELS_PER_HOLE;
        rh = chip_h[u] * PIXELS_PER_HOLE;

        printf "  <!-- Desenho Técnico do Chip: %s -->\n", u >> SVG_OUTPUT;
        # Corpo de resina plástica preta (Fosco Industrial)
        printf "  <rect x=\"%d\" y=\"%d\" width=\"%d\" height=\"%d\" fill=\"#1f1f1f\" rx=\"6\" stroke=\"#4e4e4d\" stroke-width=\"2\" />\n", rx, ry, rw, rh >> SVG_OUTPUT;
        
        # Inscrição do identificador (etiqueta) do Chip centralizado
        text_x = rx + (rw / 2); text_y = ry + (rh / 2) + 6;
        printf "  <text x=\"%d\" y=\"%d\" font-family=\"Arial, sans-serif\" font-size=\"14\" font-weight=\"bold\" fill=\"#ffffff\" text-anchor=\"middle\">%s</text>\n", text_x, text_y, u >> SVG_OUTPUT;

        # Varre os pinos físicos gerando as duas camadas de texto exigidas
        for (p = 1; p <= chip_pins[u]; p++) {
            px_abs = snap_x[u] + pin_x[u, p];
            py_abs = snap_y[u] + pin_y[u, p];
            
            circle_x = (px_abs + 1) * PIXELS_PER_HOLE;
            circle_y = (py_abs + 1) * PIXELS_PER_HOLE;

            # Desenha o pino quadrado prateado clássico de Wire Wrap de perfil alto
            printf "  <rect x=\"%d\" y=\"%d\" width=\"12\" height=\"12\" fill=\"#e4e4dc\" stroke=\"#8e8e8e\" stroke-width=\"1\" transform=\"translate(-6,-6) rotate(45 %d %d)\" />\n", circle_x, circle_y, circle_x, circle_y >> SVG_OUTPUT;

            # Identificação 1: Número Sequencial Físico Real do Pino
            # Identificação 2: Pinagem Geral / Nome Lógico do Sinal Mapeado
            p_logic = ((u, p) in pin_num_to_name) ? pin_num_to_name[u, p] : "--";

            # Regra Ortogonal: Empurra os textos para fora das laterais do chip DIP para legibilidade
            if (chip_type[u] == "DIP03" || chip_type[u] == "DIP06") {
                half_pins = chip_pins[u] / 2;
                if (p <= half_pins) { 
                    # Coluna da Esquerda: Textos nascem à direita do pino para fora do encapsulamento
                    text_anchor = "start"; 
                    num_x = circle_x + 14;
                    lbl_x = circle_x + 28;
                } else { 
                    # Coluna da Direita: Textos alinham pelo final à esquerda do pino para fora
                    text_anchor = "end"; 
                    num_x = circle_x - 14;
                    lbl_x = circle_x - 28;
                };
            } else {
                # Pacotes SIL / Discretos lineares por padrão jogam o texto à direita
                text_anchor = "start"; 
                num_x = circle_x + 14;
                lbl_x = circle_x + 28;
            };

            # Renderiza o número físico do pino em amarelo sutil para não sobrecarregar visualmente
            printf "  <text x=\"%d\" y=\"%d\" font-family=\"Courier New, monospace\" font-size=\"9\" font-weight=\"bold\" fill=\"#ffd700\" text-anchor=\"%s\">#%d</text>\n", num_x, (circle_y + 3), text_anchor, p >> SVG_OUTPUT;
            
            # Renderiza o nome lógico (etiqueta funcional) em verde brilhante
            if (p_logic != "--") {
                printf "  <text x="%d" y="%d" font-family="Consolas, Monaco, monospace" font-size="9" font-weight="bold" fill="#00ff00" text-anchor="%s">%s\n", lbl_x, (circle_y + 3), text_anchor, p_logic >> SVG_OUTPUT;
    };
    };
    }
print "" >> SVG_OUTPUT;
printf "[SUCESSO] Arquivo vetorial tamanho natural exportado em: '%s' (300 DPI)\n", SVG_OUTPUT;
}
