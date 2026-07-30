
#!/usr/bin/awk -f

BEGIN {
    indent_size = 4  # Quantidade de espaços por nível
    indent_level = 0
}

{
    line = $0

    # 1. Quebra linha APÓS '{'
    gsub(/\{[ \t]*/, "{\n", line)

    # 2. Quebra linha ANTES de '}'
    gsub(/[ \t]*\}/, "\n}", line)

    # 3. Quebra linha ANTES de '#' (somente se houver código antes dele)
    if (line ~ /[^ \t]+.*#/) {
        gsub(/[ \t]*#/, "\n#", line)
    }

    # 4. Quebra linha ANTES de 'print ' (se não for o início da linha)
    if (line ~ /[^ \t]+.*print[ \t]+/) {
        gsub(/[ \t]*print[ \t]+/, "\nprint ", line)
    }

    # 5. Quebra linha ANTES de 'for ' ou 'for(' (se não for o início da linha)
    if (line ~ /[^ \t]+.*for[ \t\(]/) {
        gsub(/[ \t]*for[ \t\(]/, "\nfor(", line)
    }

    # Divide a linha em sub-linhas com base nas quebras inseridas
    n = split(line, lines, "\n")

    for (j = 1; j <= n; j++) {
        sub_line = lines[j]

        # Remove espaços desnecessários do início e fim
        gsub(/^[ \t]+|[ \t]+$/, "", sub_line)

        # Ignores sub-linhas vazias
        if (length(sub_line) == 0) {
            continue
        }

        # Separa a parte de código do comentário para contar chaves
        comment_idx = index(sub_line, "#")
        if (comment_idx > 0) {
            code_part = substr(sub_line, 1, comment_idx - 1)
        } else {
            code_part = sub_line
        }

        opens = gsub(/\{/, "{", code_part)
        closes = gsub(/\}/, "}", code_part)

        # Se a linha começa com '}', reduz a indentação ANTES de imprimir
        if (code_part ~ /^\}/) {
            indent_level--
            if (indent_level < 0) indent_level = 0
        }

        # Monta os espaços de recuo
        pad = ""
        for (i = 0; i < indent_level * indent_size; i++) {
            pad = pad " "
        }

        # Imprime a linha devidamente indentada
        print pad sub_line

        # Atualiza a indentação para a próxima linha
        if (code_part ~ /^\}/) {
            indent_level += (opens - (closes - 1))
        } else {
            indent_level += (opens - closes)
        }

        if (indent_level < 0) indent_level = 0
    }
}
