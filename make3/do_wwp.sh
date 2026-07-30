
awk 	-f 01_parser.awk \
	-f 02_validator.awk \
	-f 03_placement.awk \
	-f 04_router.awk \
	-f 05_report.awk \
	-f 06_sgv.awk \
	componentes.csv netlist.csv

