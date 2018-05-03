.data
	uncompressed_file: .ascii "uncompressed_file.txt\0"
	compacted_file: .ascii "arquivotexto.lzw\0"
	dictionary: 	.ascii "dictionary.txt\0"
	
	
	buffer1: .space 1	# Buffer that will store one byte
	buffer2: .ascii ""	# Buffer that will store a string to be written in the uncompressed_file
	
.text
	
Open_Files:
	
	# Open compressed file
	li $v0, 13		# Open file code
	la $a0, compacted_file	# Label	of the file
	li $a1, 0		# flag 0
	li $a2, 0		# Reading mode
	syscall			# Effectively open the file
	move $s0, $v0		# Save the file descriptor in $s0
	
	# Possible error during opening file verification
	beq $s0, -1, End
	
	# Open file where the uncompressed string will be written
	li $v0, 13			# Open file code
	la $a0, uncompressed_file	# Label of the file
	li $a1, 1			# Flag 1 to always create a new dictionary
	li $a2, 0			# Write only mode
	syscall				# Effectively open the file 
	move $s2, $v0			# Save the file descriptor in $s2
	
	# Possible error during opening file verification
	beq $s2, -1, End

Read_from_compressed:
	# Read 1 char from compressed file
	move $t3, $zero	# Used to convert char key to int key
reading_loop:
	li $v0, 14		 # Read file code
	move $a0, $s0		 # File descriptor
	la $a1, buffer1($zero)   # Where the char will be saved
	li $a2, 1		 # Number of chars to be read
	syscall
	
	beq $v0, $zero, End 	# If reached EOF finish
	
	lb $t0, 0($a1)		# Start verification if it is key or "-"
	beq $t0, 45, Finished_key
	
It_is_key:
	# This function works like ATOI until we haven't reachead "-" we are still on the dictonary key
	addi $t0, $t0, -48
	mul $t3, $t3, 10
	add $t3, $t3, $t0
	j reading_loop
Finished_key:		
	# Only enters here when it finished reading a key
	# Now it's needed to read witch char broke the sequence

	li $v0, 14		 # Read file code
	move $a0, $s0		 # File descriptor
	la $a1, buffer1($zero)   # Where the char will be saved
	li $a2, 1		 # Number of chars to be read
	syscall
	
	lb $t4, 0($a1)		# Registor where that char will be stored

Write_on_uncompressed_file:
	la $t5,  buffer2
	
	jal Search_in_dict 	# Search on dictionary file what are the value in key stored in $t3 and store it in 

	sb $t4, 0($t5)		# Concatenate what is stored in $t4
	addi $t5, $t5, 1
	la $t6, buffer2
	sub $t5, $t5, $t6 	# Length of the string to be written in the descompressed file	
	
	li $v0, 15		# Write on file code
	move $a1, $t6		# From where it will be written
	move $a0, $s2		# File descriptor
	move $a2, $t5		# Length of the string to be written
	syscall
	
	j Read_from_compressed		# Restart reading from compressed file loop


Search_in_dict:
	# This proceadure searchs in the dictionary the value for the key stored in $t3
	move $t0, $zero
	
	# It is necessary to open the dictionary file again
	li $v0, 13		# Open file code
	la $a0, dictionary	# Label	of the file
	li $a1, 0		# flag 0
	li $a2, 0		# Reading mode
	syscall			# Effectively open the file
	move $s1, $v0		# Save the file descriptor in $s1
	
	# Possible error during opening file verification
	beq $s1, -1, End	
	
	beqz $t3, Finished_chars_from_key	# If the key is equal 0 than it's uncessary to search
Reading_loop:
	li $v0, 14		 # Read file code
	move $a0, $s1		 # File descriptor
	la $a1, buffer1($0)# Where the char will be saved
	li $a2, 1		 # Number of chars to be read
	syscall
	
	lb $t1, 0($a1)
	beq $t1, 123, acabou_numero
	addi $t1, $t1, -48
	mul $t0, $t0, 10
	add $t0, $t0, $t1
	j Reading_loop

acabou_numero:
	beq $t3, $t0, After_found_key
	move $t0, $zero

Wrong_key:
	li $v0, 14		# Read file code
	move $a0, $s1		# File descriptor
	la $a1, buffer1($0)	# Where the char will be saved
	li $a2, 1		# Number of chars to be read
	syscall	
	
	lb $t1, 0($a1)
	beq $t1, 125, Reading_loop
	j Wrong_key
	
After_found_key:
	li $v0, 14		# Read file code
	move $a0, $s1		# File descriptor
	la $a1, buffer1($0)	# Where the char will be saved
	li $a2, 1		# Number of chars to be read
	syscall	
	
	lb $t3, 0($a1) 		# picked up the first value
	beq $t3, 125, Finished_chars_from_key	# If it read "}" form the dictionary, it means that the value for that key finished 
	sb $t3, 0($t5)
	addi $t5, $t5, 1
	j After_found_key
	
Finished_chars_from_key:
	# Close dictionary file ( for future search)
	li $v0, 16	# Close archive code
	move $a0, $s1	# Dictionay descriptor
	syscall	
	# Return to Write_on_uncompressed_file
	jr $ra
	
Close_archives:
	# Closes all archives used in the program
	li $v0, 16	# Close archive code
	move $a0, $s0	# Compressed file descriptor
	syscall
	move $a0, $s1	# Dictionay descriptor
	syscall
	move $a0, $s2	# Uncompressed file descriptor
	syscall
				
End: # Kills the program 
	
	li $v0, 10 # Syscall code to end program
	syscall
