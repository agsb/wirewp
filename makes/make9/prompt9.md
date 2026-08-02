# MASTER PROMPT V2: Modular Wire-Wrap EDA Compiler & Data-Driven Layout Pipeline

## 1. Context & Architecture
You are an expert EDA (Electronic Design Automation) and compiler engineer specializing in the AWK language (POSIX compliant with gawk, mawk, nawk). We are developing a modular PCB layout compiler and router specifically designed for universal proto-boards using manual Wire-Wrap technology (0.1" / 2.54mm grid).

The system is strictly split into 9 sequential logical files (01_parser.awk to 09_execute.awk). To prevent fatal scalar-context array errors inside the AWK interpreter, modules 01 to 08 must contain only function definitions and pattern matching rules. The main orchestration and control block runs solely and exclusively within the END block of the final coordinator script (09_execute.awk).

### Pipeline Execution Order:
LC_NUMERIC=C awk -f 01_parser.awk -f 02_validator.awk -f 03_placement.awk -f 04_router.awk -f 05_report_placement.awk -f 06_report_wiring.awk -f 07_export.awk -f 08_svg.awk -f 09_execute.awk componentes.csv netlist.csv

---

## 📐 2. Core Functional Requirements & Algorithmic Rules

### MÓDULO 01: 01_parser.awk (Input Ingestion & Tokenizer)
- No hardcoded device libraries (init_library) are allowed. All component packages, footprints, and datasheet pin maps are parsed dynamically from componentes.csv.
- Filters scripts via FILENAME !~ /\.awk$/ and sanitizes carriage returns with gsub(/\r/, "", $0).
- Fixed coordinate anchors (anchor_X_Y) are extracted via native scalar index/substr operations, prohibiting split() inside assignment contexts to prevent type clashes.

### MÓDULO 02: 02_validator.awk (DRC Audit)
- Detects VCC-to-GND shorts on identical netlists. Cross-references component footprint bounds and flags floating pins using guard syntax: if (inst == "" || inst == "COB" || inst ~ /^C_/) continue.

### MÓDULO 03: 03_placement.awk (Grid Matrix Blocking Placer)
- Eradicates overlapping and analytical drifting via a Grid Matrix Blocking algorithm. Loops assign positions sequentially by part-type starting at (4,4).
- Component structural package footprints and an obligatory 0.4" insulation zone (clearance_furos = 4) are written directly into a global boolean lookup matrix (GRID_RESERVED[X,Y] = 1). Subsequent dynamic placements are strictly blocked from settling on reserved coordinates, sliding rows/columns within BRD bounds.
- Quantizes every coordinate lifecycle parameter onto discrete board matrix indices using int(...).
- Automatically pairs virtual bypass 100nF decoupling capacitors (registered as CAPACITOR under a DSC footprint in componentes.csv) anchored 1 pin away from target DIP IC posts under a strict 0.2" matrix step (Terminal 1 on X-1, Terminal 2 on Y+2).

### MÓDULO 04: 04_router.awk (Manhattan Daisy-Chain Optimizer)
- Arranges electrical nodes using an orthogonal Manhattan Daisy-Chain script driven by a Traveling Salesperson (TSP) heuristic.
- Arrays split segments inside local isolated parameters (part1 = split_buffer_1[1]) to avert array context violations. Constrains horizontal/vertical wire stacking levels to a maximum of 2 wires per physical post (PIN_Z_LEVEL <= 2).

### MÓDULO 05: 05_report_placement.awk (Discrete Matrix Report)
- Generates Section 1 (Footprint allocation maps listing discrete grid positions for PINO_1, PINO_GND, and PINO_VCC in that specific column configuration), Section 2 (DRC logs), and Section 4 (Isolated decoupling capacitor terminal coordinate lists under a 0.2" package step layout).

### MÓDULO 06: 06_report_wiring.awk (Signal Path Analyzer)
- Emits Section 3 detailing logic networks, Z-stack parameters, and EMI loop inductances grouped strictly by net priority and wiring colors. Filters capacitor segments to protect console visibility.

### MÓDULO 07: 07_export.awk (Chronological Wire-Wrap Build Sheet)
- Formats token outputs into an explicit build sheet named board_routing_summary.txt structured dynamically by hierarchy priority classes (1 to 7).
- Ingests chronological step-by-step numbers into the build sheet. Every physical wire path is sequentially numbered in execution order starting exactly at 1 via an incrementing index column (PASSO).
- Ingests decoupling caps into Class 1 (POWER), mapping VCC lines to VERMELHO, GND lines to PRETO, and forcing their vertical wrap level to BAIXO (Z1) for decoupling mitigation at the post roots.
- Core 30 AWG metrology formula applies a hardware wrap coefficient of 4.544 cm per wire-cut segment (supplying 6 bare wraps and 2 insulated wrap-coils per pin) and snaps totals upwards using an absolute ceiling multiple rounder (round_to_ceil_cm) to print pristine purchasing lengths in meters.

### MÓDULO 08: 08_svg.awk (W3C Realtime Vector Renderer)
- Generates clean board_top.svg and board_bottom.svg layers.
- Web Browser Compliance: Always embeds the standard full XML namespace tag format: xmlns="http://w3.org".
- Implements a top-level <defs> wrapper housing style classes (.wire-trace, .pad-hole, .square-pad) and separates layout groups semantically using <g id="..."> selectors.
- String Quote Safeguard: Uses sprintf("%c", 34) to print outer container double quotes while inner visual attributes leverage clean single quotes (stroke='rgb(...)'). Renders opacities textually to shield parsing routines from local terminal comma traps.
- Bottom Layout Customization: Prior to rendering, a physical node pre-scan stores active post coordinates into PIN_HOLES[i, j] = 1. The grid loop builds a golden square pad (<rect width='12' height='12'>) over active component pins and regular circles over unused holes. Omits wire lines entirely on the bottom layer and boosts text annotations to a bold, visible 16px font anchored under each pad.

### MÓDULO 09: 09_execute.awk (Master Pipeline Orchestrator)
- Invocates sequential data processing pipelines cleanly inside the final file's END action block: execute_drc_validation(), run_force_directed_placement(), run_manhattan_routing(), generate_placement_report(), generate_wiring_report(), generate_routing_summary(), render_svg("top"), and render_svg("bottom").

