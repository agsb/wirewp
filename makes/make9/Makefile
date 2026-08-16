
# ==============================================================================
# AUTOMATED CONTROL PANEL - WIRE-WRAP EDA COMPILER PIPELINE
# ==============================================================================

# Executador e variáveis globais do sistema
AWK         = awk
ENV_FLAGS   = LC_NUMERIC=C

# Lista sequencial estrita dos 9 scripts lógicos do compilador EDA
MODULES     = 01_parser.awk \
              02_validator.awk \
              03_placement.awk \
              04_router.awk \
              05_report_placement.awk \
              06_report_wiring.awk \
              07_export.awk \
              08_svg.awk \
              09_execute.awk

# Arquivos de banco de dados de entrada fornecidos pelo usuário
INPUT_DB    = componentes.csv
INPUT_NET   = netlist.csv

# Arquivos físicos de saída gerados pelo compilador
OUTPUT_TXT  = board_routing_summary.txt
OUTPUT_TOP  = board_top.svg
OUTPUT_BTM  = board_bottom.svg
OUTPUT_ALL  = $(OUTPUT_TXT) $(OUTPUT_TOP) $(OUTPUT_BTM)

# Alvos virtuais (Phony Targets) que não geram arquivos físicos homônimos
.PHONY: all compile clean view-reports help check-files

# ------------------------------------------------------------------------------
# REGRA PADRÃO (Default Target)
# ------------------------------------------------------------------------------
all: check-files compile

# ------------------------------------------------------------------------------
# COMPILAÇÃO DO LAYOUT & PIPELINE EDA
# ------------------------------------------------------------------------------
compile: $(MODULES) $(INPUT_DB) $(INPUT_NET)
	@echo "========================================================================"
	@echo " [MAKE] Disparando Pipeline EDA Compilador Wire-Wrap..."
	@echo "========================================================================"
	$(ENV_FLAGS) $(AWK) $(foreach mod,$(MODULES),-f $(mod)) $(INPUT_DB) $(INPUT_NET)
	@echo "========================================================================"
	@echo " [SUCCESS] Compilação finalizada!"
	@echo " -> Relatório técnico gerado em console."
	@echo " -> Arquivo de manufatura salvo: $(OUTPUT_TXT)"
	@echo " -> Camadas vetoriais salvas   : $(OUTPUT_TOP) e $(OUTPUT_BTM)"
	@echo "========================================================================"

# ------------------------------------------------------------------------------
# AUDITORIA DE INTEGRIDADE DOS ARQUIVOS DE ENTRADA
# ------------------------------------------------------------------------------
check-files:
	@for file in $(MODULES) $(INPUT_DB) $(INPUT_NET); do \
		if [ ! -f $$file ]; then \
			echo " [ERRO CRÍTICO] Arquivo obrigatório ausente: $$file"; \
			exit 1; \
		fi \
	done

# ------------------------------------------------------------------------------
# LIMPEZA TÉCNICA DE PRODUTOS GERADOS (Reset do Workspace)
# ------------------------------------------------------------------------------
clean:
	@echo " [MAKE] Removendo relatórios e arquivos gráficos gerados..."
	rm -f $(OUTPUT_ALL)
	@echo " [SUCCESS] Workspace limpo com sucesso!"

# ------------------------------------------------------------------------------
# INSPEÇÃO RÁPIDA DE ARQUIVOS DE SAÍDA (Texto)
# ------------------------------------------------------------------------------
view-reports:
	@if [ -f $(OUTPUT_TXT) ]; then \
		cat $(OUTPUT_TXT); \
	else \
		echo " [AVISO] O sumário '$(OUTPUT_TXT)' ainda não foi gerado. Rode 'make'."; \
	fi

# ------------------------------------------------------------------------------
# MANUAL TÉCNICO DE USO (Help Panel)
# ------------------------------------------------------------------------------
help:
	@echo "========================================================================"
	@echo "           PAINEL DE CONTROLE MAKEFILE - WIRE-WRAP EDA"
	@echo "========================================================================"
	@echo " Comandos disponíveis na console:"
	@echo "   make              - Executa auditoria e roda a compilação completa"
	@echo "   make compile      - Força a execução imediata do pipeline AWK"
	@echo "   make view-reports - Exibe o arquivo 'board_routing_summary.txt' na tela"
	@echo "   make clean        - Apaga os arquivos SVG e TXT gerados no workspace"
	@echo "   make help         - Exibe este manual técnico explicativo"
	@echo "========================================================================"


