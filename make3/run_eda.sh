
#!/usr/bin/env bash

# ==============================================================================
# SCRIPT DE EXECUÇÃO DO COMPILADOR E ROTEADOR EDA WIRE-WRAP
# ==============================================================================

# Encerra a execução em caso de erro não tratado
set -e

# Configuração dos arquivos
COMP_FILE=${1:-"componentes.csv"}
NET_FILE=${2:-"netlist.csv"}

# Lista dos módulos AWK em ordem rigorosa de execução
MODULES=(
    "01_parser.awk"
    "02_validator.awk"
    "03_placement.awk"
    "04_router.awk"
    "05_report.awk"
    "06_svg.awk"
)

# --- VERIFICAÇÕES DE PRÉ-REQUISITOS ---
echo "⚙️  Verificando ambiente e arquivos..."

if ! command -v awk &> /dev/null; then
    echo "❌ Erro: O utilitário 'awk' não está instalado." >&2
    exit 1
fi

for mod in "${MODULES[@]}"; do
    if [ ! -f "$mod" ]; then
        echo "❌ Erro: Módulo '$mod' não encontrado." >&2
        exit 1
    fi
done

if [ ! -f "$COMP_FILE" ] || [ ! -f "$NET_FILE" ]; then
    echo "❌ Erro: Arquivos de entrada '$COMP_FILE' ou '$NET_FILE' não foram encontrados." >&2
    echo "Uso: ./run_eda.sh [componentes.csv] [netlist.csv]" >&2
    exit 1
fi

# --- EXECUÇÃO DO PIPELINE ---
echo "🚀 Executando Compilador e Roteador EDA..."
echo "--------------------------------------------------------------------------------"

awk -f 01_parser.awk \
    -f 02_validator.awk \
    -f 03_placement.awk \
    -f 04_router.awk \
    -f 05_report.awk \
    -f 06_svg.awk \
    "$COMP_FILE" "$NET_FILE"

echo "--------------------------------------------------------------------------------"
echo "✅ Processo concluído!"
echo "📄 Relatório técnico exibido acima."
echo "🖼️  Arquivos SVG gerados: 'pcb_top.svg' e 'pcb_bottom.svg'."


