.data
	textfile: .space 20 			## Name of the file to be compressed, the last char is reserved to '\0', so
						## the name can be at most 19 chars long. Test if we can include the path
						## in the name of the file, because it is only found in the same folder as the
						## Mars.jar application 
	dictionary: .asciiz "dictionary.txt"	# Name of the file that contains the dictionary created during the compression
						# Dictionary style: [index(.word) -> string(.asciiz with the last one being '\0')]
	# Both the buffers will be dynamic, especial care must be taken to avoid overwriting other values
	buffer_aux: .asciiz ""			# Buffer that holds a single char read from the textfile
	buffer_comp: .asciiz ""			## Buffer that concatenates chars and compares the resulting string with the ones
						## in the dictionary
	message: .asciiz "Nome do arquivo a ser lido"	# Show message,okay to be overwritten
.text
	
	## Details of what the variables are used for ##
	# $s7 = used to store the size of the dictionary  	 			#
	# $s0 = used to store the descriptor of the file to be read  			#
	# $t0 = the counter of the buffer, we should change this to a saved register	#
	# $t1 = the auxiliar counter of the pairs in the dictionary			#
	# $t2 = Iterator for the strings in the dictionary				#
	# $t3 = Auxiliar counter for the buffer						#
	
Get_Input: # Open the necessary files
	
	# Another method of reading the textfile name
	li $v0, 54
	la $a1, textfile
	li $a2, 20 	# n-1 chars will be read, the last one is reserved for '\0'
	la $a0, message
	syscall
	
	# Print a message in case the reading was not successful, to do
	bne $a1, $zero, End
	
	# The dictionary to store the pairs of keys and contents will be stored in the dynamic area, so, we will use $gp
	# The dictionary start will be $gp and the counter will be $s7
	move $s7, $zero
	
###### 	
	move $t0, $zero
Filter_input:
	# Transform the first '\n' in the input to a '\0', to avoid problems when opening the file with the same name
	lbu $t1, textfile($t0) 	 # Loads the current char into $t1
	beq $t1, '\n', correct	 # Check if $t1 equals '\n'
	beq $t1, $zero, continue # Check if $t1 equals '\0'
	addi $t0, $t0, 1	 # Iterate index
	j Filter_input # Go back to get other char
	
correct:
	sw $zero, textfile($t0)
	
continue:
######

Open_Files:
	# I think the dictionary does not need to be open now, we could open it only in the end and write to it only once
	# Abertura do arquivo onde sera escrito o dicionario
	#li $v0, 13		# Código do open file
	#la $a0, dictionary	# Label do arquivo a ser escrito
	#li $a1, 9		# flag 9
	#li $a2, 0		# Modo de escrita e append
	#syscall			# Abre o arquivo texto do dicionario 
	#move $s1, $v0		# Guarda o descritor do arquivo
	
	# Fazer a verificacao de abertura correta
	#beq $s1, -1, End
	
	# File to be compressed
	li $v0, 13		# Open file code
	la $a0, textfile	# Label	of the file
	li $a1, 0		# flag 0
	li $a2, 0		# Reading mode
	syscall			# Effectively open the file
	move $s0, $v0		# Save the file descriptor in $s0
	
	# Possible error during opening file verification
	beq $s0, -1, End

	# la $t1, buffer_comp($zero) # Loads into $t1 the adress of buffer_comp, used to concatenate chars, it start with the empty string ''

######		
	add $t0, $zero, $zero	# Works like a counter to the buffer
Get_next: # Insert into buffer_comp the next char read
	li $v0, 14		 # Read file code
	move $a0, $s0		 # File descriptor
	la $a1, buffer_comp($t0) # Where the char will be saved
	li $a2, 1		 # Number of chars to be read
	syscall
	addi $t0, $t0, 1	 # Increment the index to get next position
	
	beq $v0, $zero, Fecha_Arquivos # If reached EOF, we must first save the string before leaving, to do
	
	# Compare the string starting in buffer_comp($zero) and ending into buffer_comp($t0) with the strings in the dictionary
	move $t1, $zero		# Iterator for the dictionary
	move $t2, $gp		# Declare iterator for the strings in the dictionary
	move $t3, $zero		# Declare iterator for the string in the buffer	 
Compare:
	beq $t1, $s7, add_dictionary	# No match found, insert into dictionary
	# Jump the index .word
	addi $t2, $t2, 4 
	j keep_cmp

add_dictionary:
	# $t2 will already be in the position to store
	addi $s7, $s7, 1 # The key for the new string to be inserted, start with a 1 because the 0 is assumed to be the empty string
	sw $s7, 0($t2)
	addi $t2, $t2, 4
	move $t3, $zero # Iterator for the buffer string
repeat:	
	lb $t4, buffer_comp($t3)
	sb $t4, 0($t2)
	addi $t3, $t3, 1
	addi $t2, $t2, 1
	bne $t3, $t0, repeat
	sb $zero, 0($t2) # End the string with a '\0'
	move $t0, $zero # Reset buffer
	j Get_next

keep_cmp:
	lb $t4, 0($t2)		   # Char from the dictionary
	lb $t5, buffer_comp($t3)   # Char from the buffer
	beq $t3, $t0, check_ending # Check for buffer end
	
	bne $t4, $t5, not_found	   # If different, do not continue
	# If they are equals, just read next byte
	addi $t2, $t2, 1
	addi $t3, $t3, 1
	j keep_cmp
	
# If it was not the end, just read dictionary until a '\0' is found and then go to next pair
not_found:
	beq $t4, $zero, reset_and_next
	addi $t2, $t2, 1
	lb $t4, 0($t2)
	j not_found
reset_and_next:
	move $t3, $zero   # Reset buffer counter
	addi $t1, $t1, 1  # Increment 1 into the dictionary pair position
	sub $t9, $t2, $gp # Get relative distance from position to start of dictionary
	addi $t8, $zero, 4
	div $t9, $t8
	mfhi $t9	  # Get the remainder of the divison
	sub $t9, $t8, $t9 # Bytes necessary to jump
	add $t2, $t2, $t9 # Go to next index
	j Compare
	
check_ending:
	# If the dictionary's current char is '\0', it is a match
	beq $t4, $zero, match
	j not_found
match:
	# If there is a match, simply go back to reading another char for the buffer and store the dictionary position
	move $v1, $t1
	j Get_next
######

Escreve_Arquivo: # Escreve no arquivo dicionário o que estiver no buffer_de_comparação

	li $v0, 15			# Código para escrita em arquivo
	move $a0, $s1			# Descritor do arquivo a ser escrito
	la $a1, buffer_comp		# Dado a ser escrito 
	li $a2, 42			# Esse valor tem q ser correspondente ao tamanho a ser escrito (42 era o exemplo que estava testando)
	syscall
	
Fecha_Arquivos: # Fecha os arquivos usados no programa DEVES-SE mover para $a0 TODOS os descritores de arquivos usados no programa

	li $v0, 16	# Código para fechar arquivo
	move $a0, $s0	# Descritor do arquivo que será fechado
	syscall
	move $a0, $s1	# Descritor do arquivo que será fechado
	syscall

End: # Kills the program
	
	li $v0, 10 # Syscall code to end program
	syscall
