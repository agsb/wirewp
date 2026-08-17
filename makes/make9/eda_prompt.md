# Contexto do Projeto: Compilador e Roteador EDA Wire-Wrap Modular em AWK

Você é um engenheiro de software especialista em EDA (Electronic Design Automation) e linguagem AWK. O projeto atual é um Compilador e Roteador de PCBs modular escrito em AWK puro (POSIX compatível com gawk, mawk e nawk) projetado especificamente para a tecnologia de fiação Wire-Wrap (grade universal de 0.1" / 2.54mm). O sistema realiza posicionamento Force-Directed robusto, roteamento Manhattan Daisy-Chain, análises elétricas/físicas/EMI e gera visualizações vetoriais SVG estáveis.

O ecossistema é dividido em 8 arquivos lógicos sequenciais. Todos os cálculos matemáticos de loops, molas, snap e roteamento rodam estritamente dentro do bloco único `END` localizado apenas no último arquivo (`08_execute.awk`). Os módulos de 01 a 07 contêm apenas funções e regras de registros, e são proibidos de usar o comando `next` dentro de funções chamadas no `END` para evitar erros de contexto escalar. Os arquivos de entrada são delimitados por espaços simples e limpos de caracteres `\r`.

---

## 📐 1. Diretrizes Algorítmicas e Regras de Engenharia

### MÓDULO 01: `01_parser.awk`
- Filtra arquivos usando `FILENAME !~ /\.awk$/` e limpa retornos de carro invisíveis com `gsub(/\r/, "", $0)`.
- Mapeia prioridades de rede de 1 a 7 com `get_priority(net_name)`.
- Processa o `componentes.csv` mapeando pegadas e pinos do datasheet nas tabelas globais `DB_PIN_TO_NAME` e `DB_NAME_TO_PIN`.
- Processa o `netlist.csv` carregando as dimensões `BRD`, instâncias `COB` (desduplicadas e vinculando apenas IDs reais de chips) e conexões elétricas.
- As coordenadas de âncora fixa `anchor_X_Y` são faturadas via escalar usando as funções nativas `substr` e `index`, eliminando totalmente o uso de vetores `split` em contextos de atribuição direta.

### MÓDULO 02: `02_validator.awk`
- Realiza validações de DRC elétrico contra curtos-circuitos diretos (ex: VCC e GND na mesma rede) e emite avisos de pinos flutuantes.
- Varre todos os pinos físicos de cada componente com base no tamanho real de sua pegada e emite um aviso detalhado caso algum pino de CI não esteja ligado a nenhum barramento do netlist.

### MÓDULO 03: `03_placement.awk`
- Traduz a geometria de pinos DIP/SIL/CON em coordenadas físicas X,Y de furos na matriz.
- Implementa atração por mola elástica nas redes e repulsão quadrática estilo Coulomb ($F = 45.0 / dist^2$) com Jitter inicial LCG para desmanchar sobreposições e singularidades.
- A verificação de forças nos laços foi migrada integralmente de vetores `split()` para processamento de strings nativo através das funções escalares `substr` e `index` para extinguir erros fatais de tipo de array de escopo do AWK.
- Aplica o Snap-to-Grid absoluto com `int(val + 0.5)` e roda um corretor de empacotamento rígido via malha `while` discreta que calcula a altura real de cada corpo plástico baseado no número de pinos ($pins / 2$) e aplica deslocamentos proporcionais acrescidos do clearance de no mínimo 3 furos (0.3" / 7.62 mm) ao redor do componente inteiro, prevenindo pilhas.
- Injeta automaticamente capacitores cerâmicos Virtuais de 100nF (ID `C_U*`, tipo `DSC`) alocados exatamente 1 furo (0.1") à esquerda do pino 1 de chips `DIP` e conecta-os de forma transparente nas redes de VCC e GND.

### MÓDULO 04: `04_router.awk`
- Ordena os pinos das redes utilizando a heurística do vizinho mais próximo (Nearest Neighbor / TSP) para gerar redes Daisy-Chain otimizadas.
- Os nós do roteador são fatiados e guardados individualmente por variáveis escalares mapeadas em buffers locais isolados (`split_buffer_1` e `split_buffer_2`) antes de qualquer operação, anulando erros fatais de contexto escalar de array.
- Controla o empilhamento vertical do Wire-Wrap (`PIN_Z_LEVEL`) limitando rigidamente a fiação a **no máximo 2 fios por pino**. Se uma terceira conexão surgir, o sistema bloqueia e emite um erro crítico de DRC (`[OVERWRAP: MAIS DE 2 FIOS NO PINO]`). Substitui os comandos `next` internos por `continue` seguros.

### MÓDULO 05: `05_report.awk`
- Gera relatórios tabulares em tela: 1) Mapa Técnico Geométrico de Alocação de Componentes com coordenadas de furos e medidas convertidas para milímetros reais; 2) Sumário de Validações DRC; 3) Tabela de fiação Manhattan detalhada com distâncias elétricas, níveis Z atingidos por pino, cálculo de Indutância Parasita ($L = \text{comprimento\_mm} \times 0.82\,\text{nH/mm}$) e atenuação de Crosstalk com acréscimo helicoidal Twist Pair (+20% de fiação nas prioridades 4 e 5).

### MÓDULO 06: `06_export.awk`
- Executa resolução tardia estável (Lazy Evaluation) após o encerramento completo de toda a leitura de arquivos, varrendo o dicionário para converter os nomes lidos para o formato numérico exato exigido: `NúmeroFísico (NomeDoPino)`.
- Exporta de forma limpa o arquivo físico de texto **`board_routing_summary.txt`** organizando sequencialmente as conexões por **ordem estrita de prioridade (Classes de 1 a 7)**, separando as alimentações em blocos idênticos (GND recebe cor de isolamento `PRETO` e VCC recebe cor `VERMELHO`), seguidas de Dados (`AZUL`), Endereço (`VERDE`), Controle/Clock (`AMARELO`), Analógico (`MAGENTA`) e Gerais (`BRANCO`).
- Converte os índices do Z-Stacking em strings explícitas de orientação para o montador: `BAIXO` para o primeiro fio (Z1) e `CIMA` para o segundo (Z2).
- Aplica o filtro de desduplicação `if (part1 ~ /^C_/ || part2 ~ /^C_/) continue` para que a fiação de bypass dos capacitores automáticos não polua o guia prático do montador.
- Metrologia industrial 30 AWG: Inclui uma constante física absoluta fixa de **4.544 cm por segmento** para suprir a decapagem e o enrolamento estrito de **6 voltas nuas e 2 voltas isoladas** em cada extremidade do pino quadrado de 0.025". Todos os comprimentos sofrem arredondamento superior (*Ceil*) emulador para o próximo múltiplo exato de 1 cm.
- Acumula os totais discretos arredondados na memória e imprime direto no console um sumário absoluto de compra em carretéis/metros de fios para desperdício zero.

### MÓDULO 07: `07_svg.awk`
- Processa as camadas "top" (Silkscreen, contornos de encapsulamento DIP/SIP, círculos `DSC` de capacitores virtuais) e "bottom" (fiação ortogonal Manhattan espelhada em X).
- Injeta as tags `width="...px"` e `height="...px"` com `viewBox` na raiz do XML para garantir compatibilidade real de escala de 300 DPI no Chrome, Firefox, Safari e Edge.
- **Conformidade W3C Absoluta**: Utiliza cores no formato funcional `rgb(R,G,B)` e define as opacidades como strings textuais estáticas, neutralizando erros fatais de parsers gerados em terminais com localidade decimal de vírgula (ex: `opacity='0,9'`). Todos os atributos XML usam **aspas simples** (`cx='...'`), eliminando por completo os caracteres de escape de aspas duplas (`\"`) e garantindo que os arquivos SVG abram sem falhas em navegadores.

### MÓDULO 08: `08_execute.awk`
- Orquestrador geral do pipeline EDA, invocando sequencialmente as rotinas do bloco `END`: `execute_drc_validation()`, `run_force_directed_placement()`, `run_manhattan_routing()`, `generate_report()`, `generate_routing_summary()`, `render_svg("top")` e `render_svg("bottom")`.

---

## 🚀 2. Estado Atual e Execução

O sistema está estável, livre de vazamentos de escopo de loop ou estouros de tipo escalar. A chamada unificada oficial do compilador no terminal exige a diretiva internacional de ponto numérico:

```bash
LC_NUMERIC=C awk -f 01_parser.awk -f 02_validator.awk -f 03_placement.awk -f 04_router.awk -f 05_report.awk -f 06_export.awk -f 07_svg.awk -f 08_execute.awk componentes.csv netlist.csv
```

Confirme que você absorveu todas as especificações algorítmicas, restrições e mecânicas de EDA descritas acima para darmos continuidade ao desenvolvimento do projeto exatamente deste ponto.

