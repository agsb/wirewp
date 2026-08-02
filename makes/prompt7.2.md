# Contexto do Projeto: Compilador e Roteador EDA Wire-Wrap Modular em AWK

Você é um engenheiro de software especialista em EDA (Electronic Design Automation) e linguagem AWK. O projeto consiste em um Compilador e Roteador de PCBs modular escrito em AWK puro (POSIX compatível com gawk, mawk e nawk), projetado especificamente para a tecnologia de fiação Wire-Wrap (grade universal de 0.1" / 2.54mm). O sistema realiza posicionamento Force-Directed robusto, roteamento Manhattan Daisy-Chain, análises elétricas/físicas/EMI e gera visualizações vetoriais SVG estáveis.

O ecossistema é estruturado em 9 arquivos lógicos sequenciais (01_parser.awk a 09_execute.awk). Todos os cálculos matemáticos de loops, molas, snap e roteamento rodam estritamente dentro do bloco único END localizado apenas no último arquivo (09_execute.awk). Os módulos de 01 a 08 contêm apenas funções e regras de registros, sendo proibidos de usar o comando next dentro de funções chamadas no END para evitar erros de contexto escalar. Os arquivos de entrada são delimitados por espaços simples e limpos de caracteres \r.

---

## 📐 1. Diretrizes Algorítmicas, Regras de Negócio e Funcionalidades

### MÓDULO 01: `01_parser.awk`
- Filtra arquivos usando `FILENAME !~ /\.awk$/` e limpa retornos de carro invisíveis com `gsub(/\r/, "", $0)`.
- Mapeia prioridades de rede de 1 a 7 com `get_priority(net_name)`.
- Processa o `componentes.csv` mapeando pegadas e pinos do datasheet nas tabelas globais `DB_PIN_TO_NAME` e `DB_NAME_TO_PIN`.
- Processa o `netlist.csv` carregando as dimensões `BRD`, instâncias `COB` (desduplicadas e vinculando apenas IDs reais de chips) e conexões elétricas.
- As coordenadas de âncora fixa `anchor_X_Y` são faturadas via escalar usando as funções nativas `substr` e `index`, eliminando totalmente o uso de vetores `split` em contextos de atribuição direta.

### MÓDULO 02: `02_validator.awk`
- Realiza validações de DRC elétrico contra curtos-circuitos diretos (ex: VCC e GND na mesma rede) e emite avisos de pinos flutuantes.
- Varre todos os pino físicos de cada componente com base no tamanho real de sua pegada e emite um aviso detalhado caso algum pino de CI não esteja ligado a nenhum barramento do netlist (com proteção sintática estrita `if (inst == "" || inst == "COB" || inst ~ /^C_/) continue`).

### MÓDULO 03: `03_placement.awk`
- Traduz a geometria de pinos DIP/SIL/CON/DSC em coordenadas físicas X,Y de furos na matriz. Mapeia CIs e componentes passivos (DSC).
- Implementa atração por mola elástica nas redes e repulsão quadrática estilo Coulomb ($F = 45.0 / dist^2$) com Jitter inicial LCG para desmanchar sobreposições e singularidades.
- A verificação de forças nos laços foi migrada de vetores `split()` para processamento de strings nativo através das funções escalares `substr` e `index` para extinguir erros fatais de tipo de array de escopo do AWK.
- Aplica o Snap-to-Grid absoluto com `int(val + 0.5)` e roda um corretor de empacotamento rígido via malha `while` discreta que calcula a altura real de cada corpo plástico baseado no número de pinos ($pins / 2$) e aplica deslocamentos adicionais acrescidos do clearance de no mínimo 3 furos (0.3" / 7.62 mm) ao redor do componente inteiro, prevenindo pilhas.
- Injeta automaticamente capacitores cerâmicos Virtuais de 100nF (ID `C_U*`, pegada DSC de tamanho padrão 0.2 inch), alocando seu pino 1 exatamente 1 furo (0.1") à esquerda do pino 1 do chip DIP alvo (Eixo X) e seu pino 2 alocado exatamente 2 furos abaixo (Y + 2) no mesmo eixo X, conectando-os de forma transparente nas redes de VCC (pino 1) e GND (pino 2).

### MÓDULO 04: `04_router.awk`
- Ordena os pinos das redes utilizando a heurística do vizinho mais próximo (Nearest Neighbor / TSP) para gerar redes Daisy-Chain otimizadas.
- Os nós do roteador são fatiados e guardados individualmente por variáveis escalares mapeadas em buffers locais isolados (`split_buffer_1` e `split_buffer_2`) antes de qualquer operação, anulando erros fatais de contexto escalar de array.
- Controla o empilhamento vertical do Wire-Wrap (`PIN_Z_LEVEL`) limitando rigidamente a fiação a no máximo 2 fios por pino. Se uma terceira conexão surgir, o sistema bloqueia e emite um erro crítico de DRC (`[OVERWRAP: MAIS DE 2 FIOS NO PINO]`). Substitui os comandos `next` internos por `continue` seguros.

### MÓDULO 05: `05_report_placement.awk`
- Gera a primeira parte dos relatórios em terminal: Seção 1 (Mapa Técnico Geométrico de Alocação de Componentes focando estritamente nas posições inteiras dos furos da grade para os pinos críticos ordenados em: PINO_1, PINO_GND e PINO_VCC, sem dimensões em milímetros ou centímetros), Seção 2 (Sumário de Validações DRC) e Seção 4 (Listagem exclusiva de capacitores de desacoplamento bypass com as posições inteiras X e Y de ambas as pontas do capacitor usando o passo de 0.2 inch).

### MÓDULO 06: `06_report_wiring.awk`
- Gera a segunda parte dos relatórios em terminal: Seção 3 (Tabela de roteamento Manhattan detalhada com distâncias elétricas, níveis Z atingidos por pino, cálculo de Indutância Parasita e atenuação de Crosstalk com acréscimo helicoidal Twist Pair de +20% nas prioridades 4 e 5), agrupando estritamente os segmentos por prioridade de enrolamento e cores de isolamento (Classes de 1 a 7), com ocultação das conexões internas de bypass dos capacitores automáticos para não poluir o log elétrico principal.

### MÓDULO 07: `07_export.awk`
- Executa resolução tardia estável (Lazy Evaluation) após o encerramento completo de toda a leitura de arquivos, varrendo o dicionário para converter os nomes lidos para o formato numérico exato exigido: `NúmeroFísico (NomeDoPino)`.
- Exporta de forma limpa o arquivo físico de texto `board_routing_summary.txt` organizando sequencialmente as conexões por ordem estrita de prioridade (Classes de 1 a 7).
- Os capacitores automáticos de acoplamento/bypass (`C_U*`) são explicitamente listados no grupo da **Classe 1 (POWER)**. Seus pinos recebem tratamento cromático diferenciado: conexões à rede GND recebem a cor `PRETO`, e conexões a redes como VCC recebem a cor `VERMELHO`. O nível Z dessas conexões é fixado em `BAIXO` para melhor filtragem EMI na base do poste.
- Separa as alimentações em blocos idênticos para CIs reais (GND recebe cor de isolamento `PRETO` e VCC recebe cor `VERMELHO`), seguidas de Dados (`AZUL`), Endereço (`VERDE`), Controle/Clock (`AMARELO`), Analógico (`MAGENTA`) e Sinais Gerais (`BRANCO`).
- Converte os índices do Z-Stacking em strings explícitas de orientação para o montador: `BAIXO` para o primeiro fio (Z1) e `CIMA` para o segundo (Z2).
- Metrologia industrial 30 AWG: Inclui uma constante física absoluta fixa de **4.544 cm por segmento** para suprir a decapagem e o enrolamento estrito de **6 voltas nuas e 2 voltas isoladas** em cada extremidade do pino quadrado de 0.025". Todos os comprimentos sofrem arredondamento superior (Ceil) emulador para o próximo múltiplo exato de 1 cm.
- Acumula os totais discretos arredondados na memória e imprime direto no console um sumário absoluto de comprimento total de fio em metros necessário para a fiação, garantindo desperdício zero.

### MÓDULO 08: `08_svg.awk`
- Processa as camadas "top" (Silkscreen, contornos de encapsulamento DIP/SIP, círculos DSC de capacitores virtuais) e "bottom" (fiação ortogonal Manhattan espelhada em X com indicação dos pinos).
- **Conformidade W3C SVG 1.1 Absoluta**: Introduz um bloco formal `<defs>` que encapsula uma tag `<style>` com classes CSS do tipo `.wire-trace` e `.pad-hole`. Organiza todos os elementos visuais em grupos semânticos `<g>` (id: `pcb-substrate`, `universal-grid-matrix`, `silkscreen-top-layer`, `routing-bottom-layer`).
- Usa a declaração estrita e universal de namespace exigida pelos navegadores: `xmlns="http://w3.org"`.
- Usa injeção dinâmica de aspas duplas reais via tabela ASCII (`sprintf("%c", 34)`) para blindar as tags de metadados iniciais XML e as dimensões e namespaces da raiz `<svg>` contra falhas de parse de navegadores modernos.
- Atributos internos usam aspas simples (`cx='...'`) eliminando completamente caracteres de escape de strings e garantindo que o arquivo renderize visualmente instantaneamente.
- Utiliza cores puras no formato funcional `rgb(R,G,B)` e define as opacidades como strings textuais estáticas para neutralizar erros gerados em terminais com localidade decimal de vírgula (ex: `opacity='0.9'`).

### MÓDULO 09: `09_execute.awk`
- Orquestrador geral do pipeline EDA, invocando sequencialmente as rotinas do bloco END: `execute_drc_validation()`, `run_force_directed_placement()`, `run_manhattan_routing()`, `generate_placement_report()`, `generate_wiring_report()`, `generate_routing_summary()`, `render_svg("top")` e `render_svg("bottom")`.

---

## 🚀 2. Estado Atual e Execução

O sistema está estável, livre de vazamentos de escopo de loop ou estouros de tipo escalar. A chamada unificada oficial do compilador no terminal exige a diretiva internacional de ponto numérico para blindar a matemática interna contra o Locale local:

```bash
LC_NUMERIC=C awk -f 01_parser.awk -f 02_validator.awk -f 03_placement.awk -f 04_router.awk -f 05_report_placement.awk -f 06_report_wiring.awk -f 07_export.awk -f 08_svg.awk -f 09_execute.awk componentes.csv netlist.csv
```

Confirme que você absorveu todas as especificações algorítmicas, restrições e mecânicas de EDA descritas acima para darmos continuidade ao desenvolvimento do projeto criando exatamente estes mesmos scripts e seguindo a numeração atualizada.

