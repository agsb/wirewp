

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
