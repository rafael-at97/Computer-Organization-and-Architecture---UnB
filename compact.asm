.data
	
	# O nome do arquivo sera lido da linha de comando, esse arquivo em baixo servira apenas como teste
	arquivotexto: .asciiz "arquivotexto.txt"# Nome do arquivo com o texto a ser compactado
	dicionario: .asciiz "dicionario.txt"	# Nome do arquivo com o dicionário
	# Ambos os buffers declarados abaixo serão dinâmicos, logo, sua declaração no .data deve tomar esse cuidado
	buffer_auxiliar: .asciiz ""		# Buffer para a leitura individual de cada caractere do arquivo a ser compactado
	buffer_de_comparação: .asciiz ""	# Buffer que vai concatenando os caracteres lidos e usado para comparar com os valores do dicionario
	
.text
	
Abre_Arquivos: # Abre os arquivos textos que serão necessários no programa
	
	# Abertura do arquivo onde sera escrito o dicionario
	li $v0, 13		# Código do open file
	la $a0, dicionario	# Label do arquivo a ser escrito
	li $a1, 9		# flag 9
	li $a2, 0		# Modo de escrita e append
	syscall			# Abre o arquivo texto do dicionario 
	move $s1, $v0		# Guarda o descritor do arquivo
	
	# Fazer a verificacao de abertura correta
	
	# Abertura do arquivo que sera lido e compactado
	li $v0, 13		# Código do open file
	la $a0, arquivotexto	# Label do arquivo a ser lido
	li $a1, 0		# flag 0
	li $a2, 0		# Modo de leitura
	syscall			# Abre o arquivo texto a ser compactado
	move $s0, $v0		# Guarda o descritor do arquivo
	
	# Fazer a verificacao de abertura correta
	
	la $t1, buffer_de_comparação($zero) # Põe em $t1 o endereço do buffer_de_comparação, serve para concatenar os chars nele
	
Pega_proximo: # Põe em buffer_auxiliar o proximo caractere a ser lido do arquivo original
	
	li $v0, 14		# Código do read file
	move $a0, $s0		# Descritor do arquivo a ser lido
	la $a1, buffer_auxiliar	# Onde o caractere lido será salvo
	li $a2, 1		# Número de caracteres a ser lido
	syscall
	
Concatena: # Concatena o caractere lido do arquivo texto no buffer de comparação
	
	lb $t2, 0($a1)			# Põe em $t2 o caractere atual do buffer auxiliar 
	sb $t2, 0($t1)			# salva o caractere de $t2 no buffer de comparação
	addi $t1, $t1, 1		# Seta o ponteiro axiliar $t1 para uma posição na memória a frente (para não sobre-escrever)
	bne $v0, $zero, Pega_proximo	# Se a leitura do arquivo texto não for EOF leia mais um
	
	############### aqui deve ser um branch diferente. Coloquei esse pois era um jeito fácil para ver se o resto estava funcionando
	############### deve-se comparar o que se tem no buffer de comparação com nossos valores do dicionário e fazer o fluxo do algoritmo
	############### 
	
#Checa_dicionario: que tal abrir um outro arquivo para leitura de dicionário para realizar a checagem das chaves e valores?
		 # acho que o dicionario deve ser salvo na pilha de gp ou sp enquanto é realizada a compactação do arquivo e só
		 # depois deve ser salvo no arquivo, assim a gente pode checar as chaves mais facilmente

Escreve_Arquivo: # Escreve no arquivo dicionário o que estiver no buffer_de_comparação

	li $v0, 15			# Código para escrita em arquivo
	move $a0, $s1			# Descritor do arquivo a ser escrito
	la $a1, buffer_de_comparação	# Dado a ser escrito 
	li $a2, 42			# Esse valor tem q ser correspondente ao tamanho a ser escrito (42 era o exemplo que estava testando)
	syscall
	
Fecha_Arquivos: # Fecha os arquivos usados no programa DEVES-SE mover para $a0 TODOS os descritores de arquivos usados no programa

	li $v0, 16	# Código para fechar arquivo
	move $a0, $s0	# Descritor do arquivo que será fechado
	syscall
	# Quando se chama o syscall acho que ele tambem altera $v0, verificar isso
	move $a0, $s1	# Descritor do arquivo que será fechado
	syscall

Fim: # Finaliza o programa
	
	li $v0, 16 # Código para finalizar o programa
	syscall
