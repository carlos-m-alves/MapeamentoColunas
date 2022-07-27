#Lista todas as tabelas que não são voláteis
Function SQL1 {
    $sql =
    "SEL OReplace(Trim(Substring(TABELA From 1 FOR Position('.' IN TABELA))),'.','') AS TABELA
    FROM CRM_HUB.A000_COMANDOS_TABELAS_PROCESSOS
    GROUP BY 1
    ORDER BY 1"
    return $sql
}

#Traz a data de alteração registrada do arquivo especificado
Function SQL2 { param([string]$arquivo)
    $sql =
    "SEL DISTINCT CAMINHO || '\' || ARQUIVO AS ARQ, DT_ULT_ALTERACAO
    FROM CRM_HUB.A000_MAPEAMENTO_COLUNAS
    WHERE ARQ = '$arquivo';"
    return $sql
}

#Deleta arquivo especificado
Function SQL3 { param([string]$arquivo)
    $sql = "DEL FROM CRM_HUB.A000_MAPEAMENTO_COLUNAS WHERE CAMINHO || '\' ||ARQUIVO = '$arquivo';"
    return $sql
}

#Deleta arquivo especificado
Function SQL4 { param([string]$banco, [string]$tabela)
    $sql = "SEL columnname || ' ' AS ColumnName FROM DBC.Columnsv WHERE DatabaseName = '$database' AND TableName = '$tabela'"
    return $sql
}

#Coleta estatísticas nas colunas CAMINHO e ARQUIVO
Function SQL5 {
    $sql =
    "COLLECT STATISTICS COLUMN (CAMINHO, ARQUIVO) ON CRM_HUB.A000_MAPEAMENTO_COLUNAS;"
    return $sql
}

#Lista todos os arquivos registrados
Function SQL6 {
    $sql =
    "SEL DISTINCT CAMINHO || '\' ||ARQUIVO AS ARQUIVO
    FROM CRM_HUB.A000_MAPEAMENTO_COLUNAS
    WHERE IND_ATIVO = 1;"
    return $sql
}

#Marca como inativo o arquivo especificado
Function SQL7 { param([string]$arquivo)
    $sql =
    "UPDATE CRM_HUB.A000_MAPEAMENTO_COLUNAS SET IND_ATIVO = 0 WHERE CAMINHO || '\' ||ARQUIVO = '$arquivo';"
    return $sql
}

#Insere na tabela de controle de execução
Function SQL8 { param([string]$tipo, [string]$dataInicio)
    $sql =  "INSERT INTO CRM_HUB.A000_PROCESSAMENTOS_AUTOMATICOS ('', 19, Current_Date, $dataInicio, Current_Timestamp(0), '$tipo');"
    return $sql
}

#Função para executar SQL
Function Roda-SQL { param([string]$SQL)
    $cmd   = New-Object System.Data.Odbc.OdbcCommand($SQL, $conn)
    $cmd.CommandTimeout = 900000
    $da    = New-Object System.Data.Odbc.OdbcDataAdapter($cmd)
    $dados = New-Object System.Data.Datatable
    $null = $da.fill($dados)
    return $dados
}

#Funcão genérica de envio de e-mail
Function Envia-Email { param([string]$emails, [string]$assunto, [string]$texto)
    $assinatura = 
        "<br/>
        <br/>Att
        <br/>"
    $Outlook = New-Object -ComObject Outlook.Application
    $Mail = $Outlook.CreateItem(0)
    $Mail.To = $emails
    $Mail.Subject = $assunto
    $mail.HTMLBody = "<font face = Calibri>" + $texto + $assinatura
    $Mail.Send()
}

Function Limpa-String { param([string]$tabela)
    $tabela = $tabela.Trim()
    if($tabela.IndexOf("	") -gt 0) {
        $tabela = $tabela.Split("	")[0].trim()
    }
    $tabela = $tabela.Trim()
    $tabela = $tabela.Replace(")"," ")
    $tabela = $tabela.Replace("("," ")
    $tabela = $tabela.Replace(";"," ")
    $tabela = $tabela.Replace(" AS"," ")
    $tabela = $tabela.Replace(","," ")
    $tabela = $tabela.Replace("*/"," ") 
    $tabela = $tabela.Replace("*\"," ")
    $tabela = $tabela.Replace("/"," ")
    $tabela = $tabela.Replace("\"," ")
    $tabela = $tabela.Replace("|"," ")
    $tabela = $tabela.Replace("'"," ")
    $tabela = $tabela.Replace(""""," ")
    $tabela = $tabela.Replace("-"," ")
    $tabela = $tabela.Replace(">="," ")
    $tabela = $tabela.Replace("<="," ")
    $tabela = $tabela.Replace("<>"," ")
    $tabela = $tabela.Replace("!="," ")
    $tabela = $tabela.Replace(">"," ")
    $tabela = $tabela.Replace("<"," ")
    $tabela = $tabela.Replace("="," ")
    return $tabela
}

Function Lista-Operadores-Teradata{
    $listaOperadores = @(
        "SELECT","SEL","MLOAD","CREATE","REPLACE","CT","DROP","DELETE","DEL","INS","INSERT","MERGE","UPDATE","COLLECT"
        ,"LOCKING","LOCK","INNER","LEFT","RIGHT","FULL","OUTER","CROSS","JOIN","FROM","ON","WHERE","CREATE","REPLACE","GROUP","ORDER","BY","NOT"
    )
    return $listaOperadores
}

##
## FUNCAO INICIA AQUI
##
## TIPO DO ARQUIVO: FileInfo
## variavel $processo não é utilizada
Function Lista-Atributos {param([System.IO.FileSystemInfo]$arquivo, [string]$processo, [Object[]]$listaDatabases, [Object[]]$listaOperadores)

    #$caminhoSaida = $processo + "SAIDA\lista_atributos.txt"

    ### 1. PEGA O CONTEÚDO DO ARQUIVO
    $conteudoArquivo = (Get-Content $arquivo.FullName)     
    ### 2. REMOVE TRECHOS DE CODIGO QUE ESTAO DENTRO DE '' (ASPAS SIMPLES)
    $contArqSemAspa = $conteudoArquivo -replace '((('')+?[\w\W]+?('')+))', ''  
    ### 3a. TRANSFORMA A VARIÁVEL EM UMA STRING
    $conteudoString = ""    
    for($linha=0; $linha -lt $contArqSemAspa.Count; $linha++ ){
        $conteudoString += $contArqSemAspa[$linha] + "¬¬"  #indicador de quebra de linha
    }
    ### 3b. RETIRA TRECHOS DE CODIGO QUE ESTAO COMENTADOS POR /* */
    $regex='(((/\*)+?[\w\W]+?(\*/)+))'
    $contArqSemComen = $conteudoString -replace $regex, ''    
    ### 4. SPLITA A STRING POR ¬¬
    $conteudo = $contArqSemComen.Split("¬¬")
    ### 5. REMOVE COMENTÁRIOS DE LINHA --
    $contArqSemComenLinha = ($conteudo -replace "(?<=--).*").replace("--", "")     
    ### 6. REMOVE LINHAS QUE INICIAM COM PONTO '.'. EX: .RUNFILE, .IF, .LABEL
    $conteudo = ""
    for( $linha=0; $linha -lt $contArqSemComenLinha.Count; $linha++ ){
        if($contArqSemComenLinha[$linha]){
            if( !($contArqSemComenLinha[$linha][0] -like ".")  ){
                $conteudo += $contArqSemComenLinha[$linha] + " "
            }
        }
    }      
    ### 7. SPLITA AS CONSULTAS           
    $cont = $conteudo.Split(";")
    ### 8. REMOVE 'CONSULTAS' COM MENOS DE 1 CARACTER
    $conteudo = @()
    for( $linha=0; $linha -lt $cont.Count; $linha++ ){
        if( !($cont[$linha].Length -le 1) ){
            $conteudo += $cont[$linha]
        }
    }

    $idCons = 1
    ### 9. ITERA SOBRE AS CONSULTAS --- pesquisar tabelas
    $listaColunas = ""
    #$consulta = $conteudo[6]
    forEach($consulta in $conteudo){        
        #-Write-Host "idConsulta: "+$idCons        
        $idCons++
        ### 10. SPLITA AS PALAVRAS DA CONSULTA
        $elementos = $consulta.Split("	").Split(" ").Split("¬¬").Split('',[System.StringSplitOptions]::RemoveEmptyEntries)

        $vet = @()
        foreach ($e in $elementos){
            if( ($e -ne "ON") -and ($e.length -ge 2) -and ($e -ne "WITH") -and
                ($e -ne "DATA") -and ($e -ne "PRIMARY") -and ($e -ne "INDEX") -and ($e -ne "COMMIT") -and ($e -ne "PRESERVE") -and 
                ($e -ne "ROWS") -and ($e -ne "WHERE") -and ($e -ne "SELECT") -and ($e -ne "DISTINCT") -and ($e -ne "CREATE") -and 
                ($e -ne "FROM") -and ($e -ne "VOLATILE") -and ($e -ne "TABLE") -and ($e -ne "SEL")-and ($e -ne "CT") ){
                $vet += $e
            }
        }
        $elementos = $vet
        ### 11. ITERA NA CONSULTA PARA BUSCAR O ÍNDICE QUE OCORRE A REFERÊNCIA A UM DATABASE
        #$ii=149
        for($ii=0; $ii -lt $elementos.Count; $ii++ ){
            #-Write-Host "idElementoNaConsulta: "+$ii
            if( $ii -eq 71 ){
                $a
            }
            if( $e -like "AS" ){
                continue
            }
            
            $encontrouDatabase = $false
            ### 12. PESQUISA SE EXISTE UM DATABASE 
            #$jj=4
            for($jj=0; $jj -lt $listaDatabases.Count; $jj++ ){
                $palavra = ([regex]::escape($elementos[$ii]))                
                if( ($encontrouDatabase -eq $false) -and ($palavra.Contains(".") -eq $true) -and ($palavra -ne "") ){                                                
                    $database = Limpa-String -tabela $listaDatabases[$jj].TABELA.toUpper()
                    #$database = $listaDatabases[$jj].DatabaseName.toUpper()
                    $p = Limpa-String -tabela $elementos[$ii].Trim().ToUpper()
                    #if( $listaDatabases[$jj].DatabaseName.ToString().Trim().ToUpper() -match $palavra.ToUpper() ){
                    if( ($p.Split(".")[0]).Contains($database) ){
                        $encontrouDatabase = $true
                        $tabela = $p #.Split(".")[0]
                        $indiceTabela = $ii
                        break
                    }                    
                }
            }

            ### 13. SE ENCONTROU DATABASE ENTÃO PROCURA A SUBQUERY EM QUE ESTÁ INSERIDO
            if( $encontrouDatabase ){
                $apelidoTabela = ""
                $encontrouOperador = $false
                $achouAlias = $false

                #for( $el=$indiceTabela; $el -lt $elementos.count; $el++ ){               
                for( $el=$indiceTabela; $el -lt $indiceTabela+3; $el++ ){               
                    ### 14. PROCURA ALIAS
                    if( $elementos[$el] -like $null ){
                        continue
                    }
                    if( $elementos[$el][($elementos[$el].length-1)] -like ")" ){
                        #continue
                        break
                    }
                    if( $elementos[$el] -like ")" ){
                        #continue
                        break
                    }
                    if( $achouAlias ){
                        $apelidoTabela = $elementos[$el].Split("¬¬")
                        #procura se o proximo item é o nome de uma tabela $listaDatabases
                        #-Write-Host "apelido tabela: " $apelidoTabela
                        break
                    }
                    if( $elementos[$el] -match "AS" ){
                        #Write-Host "achou alias"
                        $achouAlias = $true
                        continue
                        $apelidoTabela = $elementos[$el+1].toUpper()
                        #o proximo é o alias
                        #setar e dar um break aki
                        break
                    }                                       
                    
                    #verifica se a próxima palavra é uma palavra reservada do TERADATA
                    forEach($op in $listaOperadores){
                        if("$op" -match [regex]::Escape($elementos[$el])){
                            ### TRATAR POIS DEVE SER EXATAMENTE IGUAL 
                            ### :LIMPAR $elementos[$el] ANTES DE COMPARAR NOVAMENTE
                            $palavraLimpa = Limpa-String -tabela  $elementos[$el].toUpper()
                            if( $palavraLimpa -like $op.toUpper()  ) {
                                #Write-Host "encontrou" $op
                                $encontrouOperador = $true
                                #entao nao tem um alias, está implícito
                                break                                
                            }
                        }
                    }
                    if( ($elementos[$el] -notmatch "AS") -and ($el -eq $indiceTabela+1) ){
                        $apelidoTabela = $elementos[$el].toUpper()
                        break
                    } 
                    if( $encontrouOperador ){
                        $apelidoTabela = $elementos[$el]
                        break
                    }
                }

                ### 15. ITERA NA CONSULTA PARA a partir do nome da tabela..volta até encontrar o inicio da sub consulta
                $abreParenteses = 0
                $fechaParenteses = 0
                $acc = 0
                $co = ""
                $consulta = ($consulta -replace '\s+', ' ')

                ### 15a. PESQUISA O ÍNDICE DA TABELA
                $indiceParaComecarPesquisarParenteses = $consulta.ToUpper().IndexOf($tabela.ToUpper())
                $vetorPosicoes = @{}
                $acc=0
                ### 16b. PESQUISA O ÍNDICE QUE A QUERY OU A SUB-QUERY INICIA
                ### VERIFICANDO O POSIÇÃO DOS PARÊNTESES NA CONSULTA
                for( $ij=$indiceParaComecarPesquisarParenteses-2; $ij -gt 0; $ij-- ){
                    if( $consulta[$ij] -match "\)" ){
                        $fechaParenteses++                            
                        $vetorPosicoes[$acc] = ($ij, ')')
                        $acc++
                    }
                    if( $consulta[$ij] -match "\(" ){  
                        $abreParenteses++
                        $vetorPosicoes[$acc] = ($ij, '(')
                        $acc++
                    }
                    if( ((-join $consulta[($ij-2)..($ij)] -match "SEL") -or (-join $consulta[($ij-5)..($ij)] -match "SELECT")) -and ($fechaParenteses -eq $abreParenteses) ){
                        break
                    }                       
                }
                ### 16c. REMOVE PARTE DA STRING E DEIXA APENAS A CONSULTA A SER ANALISADA
                if ($ij -ge 0) {
                    $cons = ($consulta.SubString($ij+1)).ToUpper()
                } else {
                    $cons = $consulta.ToUpper()
                }
                $cons = Limpa-String -tabela  $cons
                $listaColunasTabela = Roda-SQL -sql (SQL4 -banco $database -tabela $tabela.Split(".")[1])
                
                forEach($atr in $listaColunasTabela){
                   
                    if($atr.ColumnName){

                        $cons = $cons.ToUpper()
                        $coluna   = $atr.ColumnName.ToUpper()   
                        
                        if($cons.Contains($coluna)){

                            #verifica se o atributo está com alias
                            #inserir uma verificacao de alias para colunas: " AS " + $apelido... 
                            if($cons.Contains($apelidoTabela.ToUpper()+"."+$coluna) -or (($cons.Contains($coluna)) -and (!$cons.Contains("."+$coluna)))){

                                #Trata colunas para o INSERT
                                $caminho  = $arquivo.DirectoryName
                                $arquivoC = $arquivo.BaseName + $arquivo.Extension
                                $tabela   = $tabela.ToUpper().Trim()
                                $coluna   = $coluna.Trim()
                                $edicao   = $arquivo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")

                                $listaColunas += "INSERT INTO CRM_HUB.A000_MAPEAMENTO_COLUNAS ('$caminho', '$arquivoC', 1, '$tabela', '$coluna', Current_Date, '$edicao');`n"
                            }         
                        }
                    }
                }
            }
        }        
    }

    $listaColunas = $listaColunas.Trim()
    if($listaColunas) {
        Write-Host (Get-Date).ToString("HH:mm:ss") "$arquivo - Inserindo" -ForegroundColor Green
        ### 5. REMOVE DUPLICATAS
        $listaColunas = (($listaColunas -split "`n" | Select -Unique)  -join "`n")
        Roda-SQL -SQL $listaColunas
    } else {
        Write-Host (Get-Date).ToString("HH:mm:ss") "$arquivo - Arquivo sem colunas" -ForegroundColor Yellow
    }
    #fim funcao Lista Atributos
}

#Execução
try {

    $hoje = (Get-Date).ToString("dd/MM/yyyy")
    $dataInicio = "'" + (Get-Date).ToString("yyyy-MM-dd HH:mm:ss") + "'"
    Write-Host (Get-Date).ToString("HH:mm:ss") "Definindo parâmetros iniciais"
    $dirMapear = "C:\Users\usuario\Downloads\"#diretorio para mapear
    $dirProcesso ="$dirMapear"
    $listaOperadores = Lista-Operadores-Teradata
    $erro = 0
    $arquivoNome = ""

    Write-Host (Get-Date).ToString("HH:mm:ss") "Conectando ao Teradata"
    $conn = New-Object System.Data.Odbc.OdbcConnection("DSN=Teradata")
    $conn.open()

    Write-Host (Get-Date).ToString("HH:mm:ss") "Listando bases"
    $listaDatabases = Roda-SQL -SQL (SQL1)

    Write-Host (Get-Date).ToString("HH:mm:ss") "Recuperando arquivos"
    $arquivosTotal = Get-ChildItem $dirMapear -Recurse -File | Sort-Object LastWriteTime -Descending | Where-Object {
        $_.LastWriteTime -ge ([datetime]::today).AddDays(-14) -and
        $_.Extension -in ".sql", ".ps1", ".psm1", ".btq" -and #, ".fld"
        $_.DirectoryName.ToUpper() -notmatch "OLD" -and
        $_.DirectoryName.ToUpper() -notmatch "BKP" -and
        $_.DirectoryName.ToUpper() -notmatch "HIST" -and
        $_.DirectoryName.ToUpper() -notmatch "BACKUP" -and
        $_.FullName.ToUpper() -notmatch "OLD" -and
        $_.FullName.ToUpper() -notmatch "BKP" -and
        $_.FullName.ToUpper() -notmatch "HIST" -and
        $_.FullName.ToUpper() -notmatch "BACKUP" -and
        $_.FullName.ToUpper() -notmatch "SQL_Rollout_Fabrica" #mapear scripts da fabrica?
    }

    Write-Host (Get-Date).ToString("HH:mm:ss") "Filtrando arquivos editados nos últimos 4 dias"
    $arquivos = @()
    forEach($arquivo in $arquivosTotal) {
        #if ($arquivo.LastWriteTime -ge ([datetime]::today).AddDays(-4)) {
            $arquivos += $arquivo
        #}
    }
    
    $it = 0
    forEach ($arquivo in $arquivos) {
        Write-Host (Get-Date).ToString("HH:mm:ss") "$arquivo - Verificando" ($it+1) "/" $arquivos.count

        if(!$arquivo){
            continue
        }

        $insereArquivo = ""
        $arquivoNome = $arquivo.FullName
        $sql = SQL2 -arquivo $arquivoNome
        $tabelas = Roda-SQL -SQL $sql

        if($tabelas) {
            #Ignora arquivos que não tiveram alteração
            if ($tabelas[1] -eq $arquivo.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")) {
                Write-Host (Get-Date).ToString("HH:mm:ss") "$arquivo - Ignorando"
                continue
            }
            #Remove da tabela arquivos que tiveram alteração
            else {
                Write-Host (Get-Date).ToString("HH:mm:ss") "$arquivo - Limpando" -ForegroundColor Yellow
                $sql = SQL3 -arquivo $arquivoNome
                Roda-SQL -SQL $sql
            }
        }

        #Mapeia arquivos novos ou editados
        Write-Host (Get-Date).ToString("HH:mm:ss") "$arquivo - Mapeando"
        Lista-Atributos -arquivo $arquivo -processo $dirProcesso -listaDatabases $listaDatabases -listaOperadores $listaOperadores

        $it++
    }

    Write-Host (Get-Date).ToString("HH:mm:ss") "Coletando estatísticas"
    Roda-SQL -SQL (SQL5)

    Write-Host (Get-Date).ToString("HH:mm:ss") "Inativando arquivos inativos"
    $arquivosTabela = Roda-SQL -SQL (SQL6)
    $arquivosTotal = $arquivosTotal | Sort-Object FullName
	foreach($arquivoTabela in $arquivosTabela){
        $arquivoNome = [string]$arquivoTabela[0]
        $ind = 0
        $superior = $arquivosTotal.length-1
        $inferior = 0
        while($inferior -le $superior) {
            [int]$pivo = ($superior + $inferior) / 2
            $nomePivo = $arquivosTotal[$pivo].FullName
            if($arquivoNome -eq $nomePivo){
                $ind = 1
                break
            }
            if($arquivoNome -lt $nomePivo) {
                $superior = $pivo-1
            } else {
                $inferior = $pivo+1
            }
        }
        if($ind -eq 0){
            Roda-SQL -SQL (SQL7 -arquivo $arquivoNome)
        }
    }

    $texto = "Prezado,<br/><br/>Mapeamento de Colunas concluído."
    #Envia-Email -emails "enriqq3d@gmail.com" -assunto "[E-mail Automático] 19 - Êxito - Mapeamento de Colunas - $hoje" -texto $texto
    #Roda-SQL -SQL (SQL8 -tipo "Êxito" -data $dataInicio)
    Write-Host (Get-Date).ToString("HH:mm:ss") "Processamento finalizado com sucesso." -ForegroundColor Green

} catch {
    #Se houve erro no processamento, envia e-mail com o log de erro
    $erro = 1
    Write-Host (Get-Date).ToString("HH:mm:ss") "Erro no processamento. Enviando email com log."
    $log = $dirProcesso + "Log\Mapeamento_Colunas_" + (GET-DATE -format "yyyy-MM-dd_HH-mm").toString() + ".log"
    Write-Host (Get-Date).ToString("HH:mm:ss") $_.InvocationInfo.PositionMessage -ForegroundColor Red
    Write-Host (Get-Date).ToString("HH:mm:ss") $_.Exception.GetType().FullName -ForegroundColor Red
    Write-Host (Get-Date).ToString("HH:mm:ss") $_.Exception.Message -ForegroundColor Red
    $_.InvocationInfo.PositionMessage > $log
    $_.Exception.GetType().FullName >> $log
    $_.Exception.Message >> $log
    $arquivoNome >> $log
    $texto = "Prezado,<br/><br/>Erro no processamento.<br/>Verifique o arquivo de log: $log"
    #Envia-Email -emails "enriqq3d@gmail.com" -assunto "[E-mail Automático] 19 - Erro - Mapeamento de Colunas - $hoje" -texto $texto
    #Roda-SQL -SQL (SQL8 -tipo "Erro" -data $dataInicio)
}
finally{
    $conn.close()
}
