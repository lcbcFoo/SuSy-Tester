###########################################################
# Created: 16/03/2013
#
# Author: Carla Negri Lintzmayer (carlanl@ic.unicamp.br)
#
# Revision: Zanoni Dias (21/03/2015)
#
# Updated: Lucas Castro (20/03/2018)
#	   - Check connection with SuSy
#	   - Work with python
# 	   - Work with generic amount of tests
###########################################################

#!/bin/bash

self="${0##*/}"

[ $# -eq 1 ] ||
{ echo "Uso: ./$self <laboratorio>"; exit 1; }

lab=$1

# Verificando se o comando curl está instalado:

hash curl 2>/dev/null ||
{ echo "Erro: este script necessita do programa curl instalado."; exit 1; }



# Caso o programa exija compilacao, por exemplo programas em c ou c++, descomente 
# as linhas seguintes e modifique conforme necessario para compilar corretamente
#
# Nao esqueca de alterar a linha de excucao do programa na secao que roda os testes!!

# Compilando o programa
# echo "Compilando o programa..."
#
# gcc -ansi -pedantic -Wall -Werror *.c -o $lab -lm
# if [ $? -ne 0 ] ; then
#     echo "Erro na compilação. Abortando testes."
#     exit
# fi

# Verifica se o repositorio de testes existe
accept="y"
if [ ! -d "testes" ]; then
    echo "Criando diretorio de testes..."
    mkdir -p testes
else
    echo "Diretorio de testes existe, baixar testes novamente? (y/n)"
    read accept
fi

cd testes

# Baixa os arquivos de teste
if [ "$accept" == "y" ]; then
    echo "Testando conexao"

    # Testa conexao, caso esteja off nao remove testes locais
    test=$(curl -sL -w "%{http_code}" "http://www.ic.unicamp.br/~susy/" -o /dev/null)
    if  (( $test != 200 )); then
        echo "Sem conexao, mantendo testes atuais"
    else
        echo "SuSy esta disponivel!"
        rm -rf *
        # Fazendo download dos arquivos de testes
        echo "Baixando os arquivos de testes..."
        i="1"
        string="<TITLE>Sistema SuSy</TITLE>"
        while [ true ]; do
            cur=$(printf "%02d" $i)

            # Entrada
            curl https://susy.ic.unicamp.br:9999/mc102qrst/$lab/dados/arq$cur.in --insecure -O -s -L

            # Resposta
            curl https://susy.ic.unicamp.br:9999/mc102qrst/$lab/dados/arq$cur.out --insecure -s -L -o arq$cur.res

            # Como a quantidade de testes nao eh fixa precisamos testar se o arquivo que baixamos
            # ainda eh um teste, se nao for apagamos ele e terminamos
            if grep -qF "$string" arq$cur.in; then
                rm -f arq$cur.in arq$cur.res
                break
            else
                ((i++))
            fi
        done
    fi
fi


# Execucao dos testes
echo "Executando os testes..."

# Verifica se existem testes
if [ ! -f "arq01.in" ]; then
    echo "Erro! Testes nao encontrados!"
    exit
fi

# Roda o programa para todas as entradas arqXX.in e coloca o resultado em arqXX*.out
for input in `ls -1 arq*in`; do
    output="${input%.in}.out"
    arq="arq$(printf '%02d' $i)"

    # Executa o programa. Atere caso esteja rodando diferentes programas, como progamas em 
    # c ou c++
    python3 ../lab$lab.py < $input > $output
done

# Compara os resultados
erros=0
for i in `ls -1 arq*in`; do
    arq=${i%.in}

    cmp=$(diff $arq.res $arq.out)

    if [ "$cmp" != "" ]; then
        echo
        echo "========================================="
        echo "Erro encontrado com a entrada '$arq.in':"
        echo
        echo ">>> Saida esperada (SuSy):"
        cat $arq.res
        echo ">>> Saida do seu programa:"
        cat $arq.out
        echo "========================================="
        rm $arq.out
        erros=$(($erros+1))
    fi
done

echo
echo "Total de erros encontrados: $erros"
cd ..
