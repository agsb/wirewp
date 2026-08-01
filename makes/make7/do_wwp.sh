
LC_NUMERIC=C awk  \
-f 01_parser.awk  \
-f 02_validator.awk  \
-f 03_placement.awk  \
-f 04_router.awk  \
-f 05_report_placement.awk  \
-f 06_report_wiring.awk  \
-f 07_export.awk  \
-f 08_svg.awk  \
-f 09_execute.awk componentes.csv netlist.csv

