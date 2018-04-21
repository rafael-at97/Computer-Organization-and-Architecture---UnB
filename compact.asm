.data
	textfile: .space 20 			## Name of the file to be compressed, the last char is reserved to '\0', so
						## the name can be at most 19 chars long. Test if we can include the path
						## in the name of the file, because it is only found in the same folder as the
						## Mars.jar application 
	dictionary: .asciiz "dictionary.txt"	# Name of the file that contains the dictionary created during the compression
						# Dictionary style: [index(.word) -> string(.asciiz with the last one being '\0')]
	# Both the buffers will be dynamic, especial care must be taken to avoid overwriting other values
	buffer_aux: .asciiz ""			# Buffer that holds a single char read from the textfile
	buffer_de_comp: .asciiz ""		## Buffer that concatenates chars and compares the resulting string with the ones
						## in the dictionary
	message: .asciiz "Nome do arquivo a ser lido"	# Test message
.text
	
Abre_Arquivos: # Open the necessary files
	
	# Reading of the textfile name
	# li $v0, 8
	# la $a0, textfile
	# li $a1, 15 # n-1 chars will be read, the last one is reserved for '\0'
	# syscall
	
	# We must look for a way that the string "message" is only temporary, avoiding extra memory usage
	
	# Another method of reading the textfile name
	li $v0, 54
	la $a1, textfile
	li $a2, 20 	# n-1 chars will be read, the last one is reserved for '\0'
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
	move $a0, $s1	# Descritor do arquivo que será fechado
	syscall

Fim: # Finaliza o programa
	
	li $v0, 10 # Código para finalizar o programa
	syscall
