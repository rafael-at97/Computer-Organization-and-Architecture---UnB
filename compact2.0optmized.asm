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
	bufferITOA: .space 8			# This Buffer is necessary to convert integer to ascii
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
	li $a2, 20 	# n-1 chars will be read, the last one is reserved for '\0', remember to increase this size!!!
	la $a0, message
	syscall
	
	# Print a message in case the reading was not successful and exit, to do
	bne $a1, $zero, End
	
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
	sb $zero, textfile($t0)
	
continue:
######

Open_File:
	
	# File to be compressed
	li $v0, 13		# Open file code
	la $a0, textfile	# Label	of the file
	li $a1, 0		# flag 0
	li $a2, 0		# Reading mode
	syscall			# Effectively open the file
	move $s0, $v0		# Save the file descriptor in $s0
	
	# Possible error during opening file verification
	beq $s0, -1, End

	# The dictionary to store the pairs of keys and contents will be stored in the dynamic area, so, we will use $gp
	# The dictionary start will be $gp and the counter will be $s7
	move $s7, $zero
	add $t0, $zero, $zero	# Works like a counter to the buffer
Get_next: # Insert into buffer_comp the next char read
	li $v0, 14		 # Read file code
	move $a0, $s0		 # File descriptor
	la $a1, buffer_comp($t0) # Where the char will be saved
	li $a2, 1		 # Number of chars to be read
	syscall
	addi $t0, $t0, 1	 # Increment the index to get next position
	
	beq $v0, $zero, write_dictionary # If reached EOF, we must first save the string before leaving, to do
	
	# Compare the string starting in buffer_comp($zero) and ending into buffer_comp($t0) with the strings in the dictionary
	move $t1, $zero		# Iterator for the dictionary
	move $t2, $gp		# Declare iterator for the strings in the dictionary
	move $t3, $zero		# Declare iterator for the string in the buffer	 
Compare:
	beq $t1, $s7, add_dictionary	# No match found, insert into dictionary
	# Save the length of the next string in the dictionary
	lb $t6, 0($t2)
	bne $t6, $t0, reset_and_next_prep # If the length of the buffer and the length of the string in the dictionary are different, go ahead to next string
	addi $t2, $t2, 4  # If they are the same size, go comparing the string 
	j keep_cmp

add_dictionary:
	# $t2 will already be in the position to store
	addi $s7, $s7, 1 # The key for the new string to be inserted, start with a 1 because the 0 is assumed to be the empty string
	sw $t0, 0($t2)   # Store the size of the next string
	addi $t2, $t2, 4
	move $t3, $zero # Iterator for the buffer string
repeat:	# Write the string into the dictionary
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
	
	bne $t4, $t5, reset_and_next # If different, do not continue
	# If they are equals, just read next byte
	addi $t2, $t2, 1
	addi $t3, $t3, 1
	addi $t6, $t6, -1 	   # Decrease the size of the future jump to change indexes
	j keep_cmp
	
# Just go to the next position to insert the new pair
reset_and_next_prep:
	addi $t2, $t2, 4
reset_and_next:
	move $t3, $zero   # Reset buffer counter
	addi $t1, $t1, 1  # Increment 1 into the dictionary pair position
	addi $t6, $t6, 1  # Add 1 more due to the '\0'
	add $t2, $t2, $t6 # Jump to the end of the string
	sub $t9, $t2, $gp # Get relative distance from position to start of dictionary
	addi $t8, $zero, 4
	div $t9, $t8
	mfhi $t9	  # Get the remainder of the divison
	beq $t9, $zero, Compare # If we are already at a valid position, do not add 4 more extra
	sub $t9, $t8, $t9 # Bytes necessary to jump
	add $t2, $t2, $t9 # Go to next index
	j Compare
	
check_ending:
	# If the dictionary's current char is '\0', it is a match
	beq $t4, $zero, match
	j reset_and_next
match:
	# If there is a match, simply go back to reading another char for the buffer and store the dictionary position
	move $v1, $t1
	j Get_next

###
# Write the dictionary file.txt from gp area of data
write_dictionary:
	
	# $t2 = iterates in gp area of memory 							
	# $t6 = how many keys have we printed so far, it needs to be equal $s7 to finish	
	# $t1 = stores the address, and iterate in the buffer who will write in the archive	
	# $t5 = how many chars we will write per syscall					
	# $t4 = stores which content will be stored in the buffer per time 
	
	# Open file where the dictionary will be saved
	li $v0, 13		# Open file code
	la $a0, dictionary	# Label of the file
	li $a1, 1		# Flag 1 to always create a new dictionary
	li $a2, 0		# Write only mode
	syscall			# Effectively open the file 
	move $s1, $v0		# Save the file descriptor in $s1
	
	# Possible error during opening file verification
	beq $s1, -1, End
	
	# Initialize the variables
	move $t2, $gp 		# Start in the begining of the gp area 
	move $t6, $zero		# $t6 will count how many keys of the dictionary it have already printed

start_printing:	
	la $t1, buffer_comp 	# Buffer where the characters will be saved to print in the dictionary file	
	move $t5, $zero 	# $t5 stores how many characters it will print in the file, this is necessary for syscall
		
	lw $t0, 0($t2)		# Starts with the dictionary key 
	add $t6, $t6, 1
	jal int_to_ascii	# Convert integer key into equivalent ascii	
	
	addi $t4, $zero, 123 	# 123 is ascii label for "{"
	sb $t4, 0($t1)		
	addi $t1, $t1, 1	
	addi $t2, $t2, 4	# After the dictionary key we want it's content

	lb $t4, 0($t2)		# Pickup the first byte 
next_byte:
	addi $t5, $t5, 1 	# Add one in counter for characters to print
	sb $t4, 0($t1)		
	addi $t1, $t1, 1	
	addi $t2, $t2, 1	# Next content byte
	lb $t4, 0($t2)		
	bne $t4, $zero, next_byte # If the byte is \0, than we reached the end of this string	

	addi $t4, $zero, 125 	# 125 is ascii label for "}"
	sb $t4, 0($t1)	
	
	jal normalize
	
	
	add $t5, $t5, 2 	# In adition of all chacters we added to the buffer we have the key and "{ }"
	add $t5, $t5, $t7 	# $t7 stores how many chars was stored in the buffer for each key

	li $v0, 15			# Write on file code
	la $a1, buffer_comp 		# From where it will be written
	move $a0, $s1			# File descriptor
	move $a2, $t5			# Length of the string to be written
	syscall
	 
	bne $s7, $t6, start_printing	# If there are more keyes in the dictionary do it again
	j close_archives

int_to_ascii:
	# Function necessary because write file syscall only understands ascii
	la $t7, bufferITOA
	addi $t3, $t7, 8 # Save the end of the bufferITOA (This should be 7)
	move $t9, $0	 # What is this used for?
	move $t7, $0	 # What is this used for?
	
convert_int_ascii:
	# Function that effectively convert integer into ascii
	beq $t0, 0, write_converted_int	# If $t0, that holds the current index, is zero, meaning that there are no more divisions to be made, write the converted int
	div $t0, $t0, 10 		# Divide by 10 so we can get the remainder and get a single digit at a time
	mfhi $t8			# HI holds the remainder, saved now in $t8
	move $t4,$t8			# Save into $t4 the digit to be printed
	addi $t4, $t4, 48		# Add 48 so we go to the ascii table position equivalent of the digit
	sb $t4, 0($t3)			# Save the digit into the first byte of $t3, that is the end of the buffer to be printed
	addi $t3, $t3, -1		# Decrease $t3 to store now in another position
	addi $t9, $t9, 1		# Why?
	addi $t7, $t7, 1		# Why?
	j convert_int_ascii		# Go back
	
write_converted_int:
	# Write into buffer the converted integer
	addi $t3, $t3, 1		 # Increase $t3 back to the position of the first digit to be printed
	lb $t4, 0($t3)			 # Saves into $t4 the char to be printed
	sb $t4, 0($t1) 			 # Saves the char to be printed in the buffer
	addi $t1, $t1, 1		 # Increase the position of the buffer
	addi $t9, $t9, -1		 # Decrease $t9 for some reason
	bne $t9, 0 , write_converted_int # While $t9 is not zero, continue
	jr $ra				 # Goes back to the first function

normalize:
	
	sub $t9, $t2, $gp # Get relative distance from position to start of dictionary
	addi $t8, $zero, 4
	div $t9, $t8
	mfhi $t9	  # Get the remainder of the divison
	sub $t9, $t8, $t9 # Bytes necessary to jump
	add $t2, $t2, $t9 # Go to next index
	jr $ra

# Closes all archives used in the program
close_archives:
	li $v0, 16	# Close archive code
	move $a0, $s0	# Original file descriptor 
	syscall
	move $a0, $s1	# Dictionay descriptor
	syscall

End: # Kills the program
	
	li $v0, 10 # Syscall code to end program
	syscall
