# ==============================================================================
# MÓDULO 09: COORDENADOR DE EXECUÇÃO SEQUENCIAL (09_execute.awk)
# ==============================================================================

END {
    print "========================================================================" > "/dev/stderr"
    print "      INICIANDO PIPELINE EDA COMPILADOR WIRE-WRAP PCB v1.5.0"
    print "========================================================================" > "/dev/stderr"
    
    execute_drc_validation()
    run_force_directed_placement()
    run_manhattan_routing()
    
    generate_placement_report()
    generate_wiring_report()
    generate_routing_summary()
    
    render_svg("top")
    render_svg("bottom")
    
    print "[STATUS] Pipeline finalizado com sucesso. Arquivos gerados prontos para inspeção." > "/dev/stderr"
}

