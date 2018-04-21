.data
	
	# O nome do arquivo sera lido da linha de comando, esse arquivo em baixo servira apenas como teste
	arquivotexto: .space 15 # Nome do arquivo com o texto a ser compactado
	dicionario: .asciiz "dicionario.txt"	# Nome do arquivo com o dicionário
	# Ambos os buffers declarados abaixo serão dinâmicos, logo, sua declaração no .data deve tomar esse cuidado
	buffer_auxiliar: .asciiz ""		# Buffer para a leitura individual de cada caractere do arquivo a ser compactado
	buffer_de_comparação: .asciiz ""	# Buffer que vai concatenando os caracteres lidos e usado para comparar com os valores do dicionario
	message: .asciiz "Nome do arquivo a ser lido"	# Teste de mensagem display para o usuario passar parametros
.text
	
Abre_Arquivos: # Abre os arquivos textos que serão necessários no programa
	
	# Leitura do nome do arquivo que sera lido
	# li $v0, 8
	# la $a0, arquivotexto
	# li $a1, 15 # Serão lidos n-1 caracteres, reservando o ultimo para \0
	# syscall
	
	# Para evitar gastar muita memória, a string que será mostrada ao usuário será salva na pilha e depois retirada
	
	# Outro metodo de input do nome do arquivo, estou procurando um jeito da string "message" ser temporaria
	li $v0, 54
	la $a1, arquivotexto
	li $a2, 15
	la $a0, message
	syscall
	
	# Abertura do arquivo onde sera escrito o dicionario
	li $v0, 13		# Código do open file
	la $a0, dicionario	# Label do arquivo a ser escrito
	li $a1, 9		# flag 9
	li $a2, 0		# Modo de escrita e append
	syscall			# Abre o arquivo texto do dicionario 
	move $s1, $v0		# Guarda o descritor do arquivo
	
	# Fazer a verificacao de abertura correta
	beq $s1, -1, Fim
	
	# Abertura do arquivo que sera lido e compactado
	li $v0, 13		# Código do open file
	la $a0, arquivotexto	# Label do arquivo a ser lido
	li $a1, 0		# flag 0
	li $a2, 0		# Modo de leitura
	syscall			# Abre o arquivo texto a ser compactado
	move $s0, $v0		# Guarda o descritor do arquivo
	
	# Fazer a verificacao de abertura correta
	beq $s0, -1, Fim
	
	la $s2, buffer_de_comparação($zero) # Põe em $s2 o endereço do buffer_de_comparação, serve para concatenar os chars nele
	move $t0, $s2 	# Salva em $t0 a proxima posicao a ser escrita do buffer
	
Pega_proximo_concatenando: # Põe no buffer o proximo caractere a ser lido do arquivo original
	
	li $v0, 14		# Código do read file
	move $a0, $s0		# Descritor do arquivo a ser lido
	move $a1, $t0		# Onde o caractere lido será salvo
	li $a2, 1		# Número de caracteres a ser lido
	syscall
	addi $t0, $t0, 1
	bne $v0, $zero, Pega_proximo_concatenando	# Esse criterio de parada dever ser alterado, só deve-se pegar um valor novo
							# quando o valor no buffer já está presente no dicionario
							# Pra voltar pro inicio do buffer é só voltar $t0 para $s2
	 
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
