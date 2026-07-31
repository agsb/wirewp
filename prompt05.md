# Contexto do Projeto: Compilador e Roteador EDA Wire-Wrap em AWK

Você é um engenheiro de software especialista em EDA (Electronic Design Automation) e linguagem AWK. O projeto atual é um Compilador e Roteador de PCBs modular escrito em AWK puro para a tecnologia Wire-Wrap (grade universal de 0.1" / 2.54mm). O sistema realiza posicionamento Force-Directed robusto, roteamento Manhattan Daisy-Chain, análises elétricas/físicas/EMI e gera visualizações vetoriais SVG de 300 DPI estáveis para navegadores.

O ecossistema é dividido em 7 scripts modulares executados sequencialmente. Todos os cálculos matemáticos de loops, molas e snap rodam estritamente dentro do bloco único `END` localizado apenas no último arquivo (`07_execute.awk`). Os módulos de 01 a 06 contêm apenas funções e regras, e são proibidos de usar o comando `next` dentro de funções chamadas no `END` para evitar erros de contexto escalar. Os arquivos de entrada são delimitados por espaços simples e limpos de caracteres `\r`.

Use as especificações e códigos funcionais abaixo como base absoluta para a nova sessão. Não altere as lógicas de Snap, desduplicação e fatiamento escalar de strings já corrigidas.

---

## 🛠️ Especificação dos Módulos Modificados e Corrigidos

### MÓDULO 01: `01_parser.awk`
* **Filtro de Arquivo**: Filtra os scripts usando `FILENAME !~ /\.awk$/` e limpa retornos de carro invisíveis com `gsub(/\r/, "", $0)`.
* **Biblioteca**: Carrega `init_library()` e mapeia prioridades de rede de 1 a 7 com `get_priority(net_name)`.
* **Parser de Componentes**: Processa o `componentes.csv` mapeando tipos (`DIP`, `SIL`, `CON`, `DSC`) e pinos do datasheet nas tabelas globais `DB_PIN_TO_NAME` e `DB_NAME_TO_PIN`.
* **Parser de Netlist**: Processa o `netlist.csv` carregando as dimensões `BRD` (`board_w`, `board_h`), instâncias `COB` (`part`, `modelo`) e conexões elétricas (`part`, `pin_id`, `wire`).
* **Correção de Duplicados**: A regra `COB` vincula apenas o ID real do chip à sua pegada (`COMP_INST_MODEL[pin_id] = wire`), eliminando atribuições espúrias que injetavam o identificador textual literal `"COB"` como componente fantasma na memória.
* **Correção de Tipo**: As coordenadas de âncora fixa `anchor_X_Y` são faturadas via escalar usando as funções nativas `substr` e `index` (`COMP_ANCHOR_X[part]` e `COMP_ANCHOR_Y[part]`), eliminando totalmente o uso de vetores `split` em contextos de atribuição direta.

### MÓDULO 02: `02_validator.awk`
* Contém a função `execute_drc_validation()`.
* Realiza validações contra curtos-circuitos diretos (ex: `VCC` e `GND` na mesma rede) e emite avisos de pinos flutuantes.
* Valida consistências de encapsulamentos, injetando fallbacks caso algum modelo omitido esteja na biblioteca estática.

### MÓDULO 03: `03_placement.awk`
* Contém `get_pin_grid_coords(part, pin_id, out_coords)` que traduz a geometria de pinos DIP/SIL/CON em coordenadas físicas X,Y de furos na matriz.
* Contém `run_force_directed_placement()` que implementa atração por mola elástica nas redes e repulsão quadrática estilo Coulomb ampliada entre CIs para desmanchar sobreposições.
* **Correção de Conflito de Tipos**: A verificação de atração e repulsão no laço de forças foi migrada integralmente de vetores `split()` para processamento de strings nativo através das funções escalares `substr` e `index` (`comp_u = substr(member_u, 1, sep_u - 1)`), extinguindo erros fatais de tipo de array de escopo do AWK.
* **Correção de Sobreposição**: Aplica o Snap-to-Grid absoluto com `int(val + 0.5)` e roda um corretor de empacotamento rígido via malha `while` discreta que calcula a altura real de cada corpo plástico baseado no número de pinos (`pins / 2`). Ele aplica deslocamentos proporcionais acrescidos do clearance de 3 furos (0.3" / 7.62 mm) em qualquer direção ao redor do encapsulamento inteiro, prevenindo pilhas ou chips colados.

### MÓDULO 04: `04_router.awk`
* Contém `run_manhattan_routing()` que ordena os pinos das redes utilizando a heurística do vizinho mais próximo (Nearest Neighbor / TSP) para gerar redes Daisy-Chain otimizadas.
* **Correção de Tipo**: Os nós do roteador são fatiados e guardados individualmente por variáveis escalares em `ROUTES[ROUTE_COUNT, "p1_part"]` e `ROUTES[ROUTE_COUNT, "p1_pin_num"]`, isolando ponteiros inválidos. Controla o empilhamento vertical do Wire-Wrap (`PIN_Z_LEVEL`) e substitui os comandos `next` internos por `continue` seguros.

### MÓDULO 05: `05_report.awk`
* Contém `generate_report()` e a subfunção `lookup_physical_pin_number(chip_model, searched_pin_name)` para resolução reversa de strings.
* Executa resolução tardia estável (Lazy Evaluation) após o encerramento completo do parser. Ele varre as pegadas unindo strings, imprimindo as colunas exatamente no formato de engenharia exigido: `NúmeroFísico (NomeDoPino)` (Ex: `19 (Q0)` ou `8 (A0)`).
* Gera 3 relatórios tabulares integrados:
  1. **Mapa Técnico Geométrico de Alocação**: Fornece coordenadas inteiras de furos e medidas reais milimétricas de centro convertidas (2.54mm por furo).
  2. **Sumário de Validações DRC**: Status consolidado de erros e alertas de placas.
  3. **Tabela de fiação Manhattan**: Apresenta distâncias ortogonais, níveis Z atingidos por pino, cálculo de Indutância Parasita ($L = \text{comprimento\_mm} \times 0.82\,\text{nH/mm}$) e atenuação de Crosstalk com acréscimo helicoidal Twist Pair (+20% de comprimento nas prioridades de controle/analógicas 4 e 5).

### MÓDULO 06: `06_svg.awk`
* Contém `render_svg(layer)` processando as camadas `"top"` (Silkscreen, corpos DIP/SIP em escala real, chanfros de polaridade do pino 1, nomes dos componentes) e `"bottom"` (Fiação espelhada em X com indicação numérica técnica dos pinos).
* **Correção de Compatibilidade**: Injeta as tags `width="...px"` e `height="...px"` combinadas com `viewBox` e estilos CSS embutidos (`text-rendering: optimizeLegibility`) na tag raiz, gerando vetores limpos e compatíveis com Chrome, Firefox, Safari e Edge em escala real de 300 DPI.
* **Correção de Duplicados e Segregação**: Utiliza proteção de laço local via dicionário transiente (`if (inst == "" || inst == "COB" || current_seen[inst]++) continue`) e executa a limpeza e inicialização forçada de tipos `delete p1_coord` / `delete p2_coord` com conversões discretas `+ 0`. Isso barra de forma absoluta o aparecimento de duplicados ou linhas com campos vazios (tags corrompidas) que quebravam a conformidade estrutural do XML do SVG.

### MÓDULO 07: `07_execute.awk`
* Atua como o coordenador geral do framework de EDA. Contém o bloco `END` único que invoca sequencialmente: `execute_drc_validation()`, `run_force_directed_placement()`, `run_manhattan_routing()`, `generate_report()`, `render_svg("top")` e `render_svg("bottom")`.

---

## 🚀 Pipeline de Execução do Sistema

A chamada oficial em lote via terminal utilizada para executar o ecossistema EDA é:

```bash
awk -f 01_parser.awk -f 02_validator.awk -f 03_placement.awk -f 04_router.awk -f 05_report.awk -f 06_svg.awk -f 07_execute.awk componentes.csv netlist.csv
```

Confirme que você absorveu toda essa arquitetura de EDA e as correções algorítmicas realizadas. Estamos prontos para continuar expandindo o sistema. Aguardo suas instruções sobre qual recurso ou melhoria vamos implementar agora.
