# MASTER PROMPT: Modular Wire-Wrap EDA Compiler & Router Pipeline in AWK

## 1. Context & Architecture
You are an expert EDA (Electronic Design Automation) and compiler engineer specializing in the AWK language (POSIX compliant with gawk, mawk, nawk). We are developing a modular PCB layout compiler and router specifically designed for universal proto-boards using manual **Wire-Wrap technology (0.1" / 2.54mm grid)**.

The system is strictly split into **9 sequential logical files (`01_parser.awk` to `09_execute.awk`)**. To prevent fatal scalar-context array errors inside the AWK interpreter, modules 01 to 08 must contain **only function definitions and pattern matching rules**. The main orchestration and control block runs **solely and exclusively** within the `END` block of the final coordinator script (`09_execute.awk`).

### Pipeline Execution Order:
```bash
LC_NUMERIC=C awk -f 01_parser.awk -f 02_validator.awk -f 03_placement.awk -f 04_router.awk -f 05_report_placement.awk -f 06_report_wiring.awk -f 07_export.awk -f 08_svg.awk -f 09_execute.awk componentes.csv netlist.csv
```
*Note: `LC_NUMERIC=C` is mandatory to force a dot (`.`) decimal separator, preventing web browser XML parser failures when running on host systems with a comma (`,`) locale.*

---

## 📐 2. Core Functional Requirements & Algorithmic Rules

### MÓDULO 01: `01_parser.awk` (Input Ingestion & Tokenizer)
- **Strict Data-Driven Rule**: **No hardcoded device libraries (`init_library`) are allowed.** All component packages, pin footprints, and pin signal maps must be parsed dynamically from the input `componentes.csv` database.
- Filters scripts via `FILENAME !~ /\.awk$/` and sanitizes Windows carriage returns using `gsub(/\r/, "", $0)`.
- Categorizes wire priorities (1 to 7) based on net string matching (`get_priority`).
- Parses component footprints (`DIP`, `CON`, `SIL`, `DSC`) and datasheet pin declarations into global hash arrays (`DB_PIN_TO_NAME`, `DB_NAME_TO_PIN`, `RAW_PIN_DB`).
- Parses `netlist.csv` to capture board boundaries (`BRD`), component instances (`COB`), fixed anchor positions, and logical nets. Fixed coordinate anchors (`anchor_X_Y`) must be extracted using scalar string functions `substr` and `index`, strictly prohibiting `split()` in assignment contexts to prevent type collisions.

### MÓDULO 02: `02_validator.awk` (Electrical DRC Auditor)
- Detects global VCC-to-GND shorts on identical nets and raises critical errors.
- Cross-references every active component instance pin against the parsed package footprint size. Flags a detailed warning if any physical pin on a chip is left floating/unconnected in the netlist. Uses strict guard syntax: `if (inst == "" || inst == "COB" || inst ~ /^C_/) continue`.

### MÓDULO 03: `03_placement.awk` (High-Density Bounding Box Placer)
- Resolves chip footprint types (`DIP`, `SIL`, `CON`, `DSC`) onto discrete integer matrix grid hole coordinates `(X,Y)`.
- **Force-Directed Packing Vector**: Implements network wire mela-spring attraction and a quadratic Coulomb-style component repulsion force ($F = 35.0 / dist^2$) using an LCG random seed generator to eliminate overlapping parts.
- **Area Minimization (Gravity Vector)**: Applies an automated centripetal attraction pulling all components toward a top-left origin coordinate (`X=4, Y=4`).
- **Overlapping Buffer Rule**: Component clearance buffers (the 0.4" insulation zone around each part) **are allowed to overlap** in space to share routing channels. However, physical component body collisions are strictly blocked. The collision engine must evaluate only the exact structural bounding dimensions (`row_w` and `body_h`).
- **Strict Grid Quantization**: To eradicate floating-point scaling drift, every single coordinate update, vector step, and collision adjustment must be strictly wrapped inside integer constraints using `int(...)`.
- **Transparent Capacitor Injection**: Automatically synthesizes virtual 100nF decoupling bypass capacitors (`C_U*`) for all `DIP` chips. The capacitor must match a dynamic `CAPACITOR` package entry defined in `componentes.csv`. It anchors terminal 1 (`VCC`) 1 hole to the left of the target IC's Pin 1, and pushes terminal 2 (`GND`) exactly 2 holes down (`Y+2`) on the same X axis, establishing a standard **0.2 inch prototyping step**.
- **Dynamic Board Windowing**: Tracks the absolute outermost coordinate occupied by any part, appends a strict 3-hole structural border, and overrides `BOARD_MAX_W` and `BOARD_MAX_H` to compress the final PCB canvas size exactly around the compacted layout cluster.

### MÓDULO 04: `04_router.awk` (Manhattan Daisy-Chain Optimizer)
- Groups net nodes using a Nearest Neighbor / Traveling Salesperson Problem (TSP) heuristic to form efficient orthogonal Manhattan daisy-chains.
- Sub-components are extracted into local scalar variables through safe, isolated index calls (`part1 = split_buffer_1[1]`) to circumvent fatal array context context-clashes. 
- **Post Wire Limit**: Tracks the vertical stacking layer count per wire-wrap pin (`PIN_Z_LEVEL`). Constrains connections to a **maximum of 2 wires per physical wrap post**. A third connection triggers a fatal DRC block. All loops use safe `continue` deselect commands instead of `next`.

### MÓDULO 05: `05_report_placement.awk` (Spatial Allocator Report)
- Outputs terminal Section 1: Discrete integer grid footprint allocation tables showing exactly the `X` and `Y` hole numbers for **`PINO_1`**, **`PINO_GND`**, and **`PINO_VCC`** in that exact column sequence, strictly hiding fractional dimensions.
- Outputs Section 2: Validation summaries for Curto/DRC logs.
- Outputs Section 4: A dedicated bypass capacitor table displaying the precise `(X,Y)` grid intersections for **both terminals** (Terminal 1 and Terminal 2) under the 0.2" spacing format.

### MÓDULO 06: `06_report_wiring.awk` (Terminal Signal Analytics)
- Outputs terminal Section 3: Orthogonal segment logs detailing logical net definitions, Z-stacking states, parasitic loop inductances ($L = \text{length\_mm} \times 0.82\,\text{nH/mm}$), and crosstalk dampening metrics.
- Groups segments strictly by net wiring priority and insulation colors. Hides the short internal bypass capacitor segments to preserve a clean terminal overview.

### MÓDULO 07: `07_export.awk` (Hierarchical Wire-Cut List Sheet)
- Executes post-compile Lazy Evaluation to format string identifiers into a standard `PhysicalPin (SignalName)` token scheme.
- Generates the physical build sheet file **`board_routing_summary.txt`** ordered sequentially by barramento hierarchy priority classes (1 to 7).
- **Capacitor Summary Ingestion**: Decoupling capacitors must be included inside **Classe 1 (POWER)**. Terminal connections hitting ground nets get assigned a **`PRETO`** insulation color flag, while VCC connections get flagged as **`VERMELHO`**. Their vertical wrap level is locked to **`BAIXO` (Z1)** to keep decoupling paths closest to the board substrate layer.
- Assigns specific industrial AWS colors to signal groups: Data (`AZUL`), Address (`VERDE`), Control/Clock (`AMARELO`), Analog (`MAGENTA`), General (`BRANCO`). Maps vertical wrapping positions textually to `BAIXO` or `CIMA`.
- **30 AWG Mechanical Metrology Formula**: Adds a fixed constant of **4.544 cm per wire segment** to satisfy the wire allowance for **6 bare wraps and 2 insulated wrap-coils** at each terminal extremity of the 0.025" post. Converts final calculations through a ceiling emulation algorithm (`round_to_ceil_cm`) to snap wire lengths to the **next higher 1 cm integer multiple**, producing an absolute bill-of-materials summary in meters at the console.

### MÓDULO 08: `08_svg.awk` (W3C Realtime Vector Renderer)
- Generates independent high-fidelity graphics layers: `board_top.svg` and `board_bottom.svg`.
- **W3C SVG 1.1 Compliance**: Always embeds the standard XML namespace string exactly as **`xmlns="http://w3.org"`** in the parent container.
- Structured Architecture: Creates a top-level `<defs>` container encapsulating global CSS classes (`.wire-trace`, `.pad-hole`). Encloses layout nodes within distinct semantic groups (`<g id="...">` for `pcb-substrate`, `universal-grid-matrix`, `silkscreen-top-layer`, `routing-bottom-layer`).
- Injecting native double-quotes using an ASCII char variable code (`q = sprintf("%c", 34)`) shields metadata headers and root `<svg>` viewport elements from encoding syntax mismatches. All inner visual element attributes use clean single quotes (`cx='...'`) to suppress escape string garbage.
- Translates hardware color codes to functional `rgb(R,G,B)` structures. Renders opacidades purely as hardcoded textual strings to bypass locale parsing breaks.

### MÓDULO 09: `09_execute.awk` (Orchestration Pipeline Core)
- Acts as the master compilation coordinator. Executes the entire pipeline inside the single file `END` block using orderly routine calls: `execute_drc_validation()`, `run_force_directed_placement()`, `run_manhattan_routing()`, `generate_placement_report()`, `generate_wiring_report()`, `generate_routing_summary()`, `render_svg("top")`, and `render_svg("bottom")`.

---

## 🚀 3. Current Project State
The compiler pipeline is stable, mathematically synchronized, and fully audited. The high-density center-of-mass gravity engine packs footprints inside overlapping routing channels while preserving integer grid quantization, and the vector graphics layers load flawlessly without layout drift. 

Acknowledge that you have fully absorbed this structural architectural mapping. Regenerate these 9 fully-compliant scripts from scratch using this exact data model scheme.

