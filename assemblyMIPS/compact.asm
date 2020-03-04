.data
	dictionary: .asciiz "dictionary.txt"	# Name of the file that contains the dictionary created during the compression
						# Dictionary style: [index{string}]
	textfile: .space 20 			## Name of the file to be compressed, the last char is reserved to '\0', so
						## the name can be at most 19 chars long. Test if we can include the path
						## in the name of the file, because it is only found in the same folder as the
						## Mars.jar application 
	bufferITOA: .asciiz "........-."	# This Buffer is necessary to convert integer to ascii
	error_msg: .asciiz "Erro ao abrir arquivo!" # Error message to be displayed.
	buffer: .asciiz "Nome do arquivo a ser compactado:" ## Buffer start with the message that will be displayed to the user,
							    ## then it will concatenate chars and compare the resulting string with
							    ## the ones in the dictionary
	buffer_space: .space 100		# Increase the buffer size possible to 133 bytes
	dict_mem: .word 0			# The start of the memory area of the dictionary, declared as a .word because it's
						# start needs to be aligned with a .word			    					    

.macro close_file %descriptor
	li $v0, 16		# Close file syscall code
	move $a0, %descriptor	# File descriptor
	syscall 		
.end_macro
							    							    					    							    
.text
	
	## 	Details of what the variables are used for in the 1st part	       ##
	# $s0 = used to store the descriptor of the file to be compresseds		#
	# $s1 = used to store the descriptor of the compressed file			#
	# $s2 = The main counter of the buffer						#
	# $s3 = Iterator for the strings in the dictionary				#
	# $s4 = Auxiliar counter for the buffer						#
	# $s5 = Saves the lenght of the string, used to jump to next pair		#
	# $s6 = the auxiliar counter of the pairs in the dictionary			#
	# $s7 = used to store the size of the dictionary  	 			#	
	
###### Part of the program that read the file name from the user
		
Get_Input: # Open the necessary files
	
	# Java method of reading the textfile name
	li $v0, 54
	la $a1, textfile
	li $a2, 20 	# n-1 chars will be read, the last one is reserved for '\0', remember to increase this size!!!
	la $a0, buffer 
	syscall
	
	# Print a message in case the reading was not successful and exit
	bne $a1, $zero, Print_error
	
###### Just Filter the user input to remove the '\n'
 	
	move $t0, $zero
Filter_input:
	# Transform the first '\n' in the input to a '\0', to avoid problems when opening the file
	lbu $t1, textfile($t0) 	 # Loads the current char into $t1
	beq $t1, '\n', correct	 # Check if $t1 equals '\n'
	beq $t1, $zero, continue # Check if $t1 equals '\0'
	addi $t0, $t0, 1	 # Iterate index
	j Filter_input # Go back to get other char
	
correct:
	sb $zero, textfile($t0)
	
continue:

###### Open the file to be compressed and the compressed file where data will be written

Open_Files:
	# File to be compressed
	li $v0, 13		# Open file code
	la $a0, textfile	# Label	of the file
	li $a1, 0		# flag 0, reading
	li $a2, 0		# Ignored mode
	syscall			# Effectively open the file
	move $s0, $v0		# Save the file descriptor in $s0
	
	# Possible error during opening file verification
	beq $s0, -1, Print_error

	### Change the .txt to a .lzw ($t0 still holds the ending of the filename)
	addi $t0, $t0, -1
	addi $t1, $zero, 'w'
	sb $t1, textfile($t0)
	addi $t0, $t0, -1
	addi $t1, $zero, 'z'
	sb $t1, textfile($t0)
	addi $t0, $t0, -1
	addi $t1, $zero, 'l'
	sb $t1, textfile($t0)		

	# Compressed File opening ($a0 and $a2 already have the correct values)
	li $v0, 13	# Open file syscall code
	li $a1, 1	# Reading mode
	syscall
	move $s1, $v0

	# Possible error during opening file verification
	beq $s1, -1, Print_error

###### Part where the program will continually read the file to be compressed and write the results in the compressed file

	# The dictionary to store the pairs of keys and contents will be stored starting in the 'dict_mem' section of .data
	# The dictionary start will be 'dict_mem' and the counter of how many pairs it have will be $s7
	move $s7, $zero	# Size of the dictionary initially zero
	move $s2, $zero	# Works like a counter to the buffer
	move $v1, $zero	# Start the index to be written in the compressed file as zero
		
Get_next: # Insert into buffer the next char read
	
	li $v0, 14		 # Read file code
	move $a0, $s0		 # File descriptor
	la $a1, buffer($s2) 	 # Where the char will be saved
	li $a2, 1		 # Number of chars to be read
	syscall
	
	addi $s2, $s2, 1	 # Increment the index to get next position ready to receive a char
	
	beq $v0, $zero, Check_last_string # If reached EOF, and $s2 is not zero, we must save the string that was last read
	
	# Compare the string starting in buffer_comp($zero) and ending into buffer_comp($s2) with the strings in the dictionary
	la $s3, dict_mem	# Declare iterator for the memory of the dictionary
	move $s4, $zero		# Declare iterator for the string in the buffer	 
	move $s6, $zero		# Iterator for the pairs in the dictionary
Compare:
	beq $s6, $s7, add_dictionary	  # No match found, insert into dictionary
	lb $s5, 0($s3)			  # Get the length of the next string in the dictionary
	bne $s5, $s2, reset_and_next_prep # If the length of the buffer and the length of the string in the dictionary are different, go ahead to next string
	addi $s3, $s3, 4  	# If they are the same size, jump the .word that represents the size and go comparing the string
	j keep_cmp

add_dictionary:
	## Every time we write something in the dictionary, it means there is a new string foud, so, we insert it into the compressed
	#  file
	jal write_compress
	# $s3 will already be in the position to store
	addi $s7, $s7, 1 # Increase the size of the dictionary in 1
	sw $s2, 0($s3)   # Store the size of the next string
	addi $s3, $s3, 4 # Jump the .word that indicates the size of the string
	
	move $t0, $zero  # Iterator for the buffer string
repeat:	# Write the string into the dictionary
	lb $t1, buffer($t0) # Loads into $t0 the byte of the buffer
	sb $t1, 0($s3)	    # Store the byte into the memory saved in $s3
	addi $t0, $t0, 1
	addi $s3, $s3, 1
	bne $t0, $s2, repeat # $s2 indicates how many chars the buffer have
	
	move $s2, $zero      # Reset buffer size
	j Get_next

keep_cmp:
	lb $t0, 0($s3)		     # Char from the dictionary
	lb $t1, buffer($s4)   	     # Char from the buffer
	beq $s4, $s2, check_ending   # If $s2 and $4 are equal, the buffer ended, check if the dictionary's current string ended too
	
	bne $t0, $t1, reset_and_next # If different, do not continue
	# If they are equals, just read next byte
	addi $s3, $s3, 1
	addi $s4, $s4, 1
	addi $s5, $s5, -1 	     # Decrease the size of a possible future jump to change indexes
	j keep_cmp
	
# Just go to the next position to compare with next pair
reset_and_next_prep: # Jump the string size when sizes are different
	addi $s3, $s3, 4
reset_and_next:
	move $s4, $zero   # Reset buffer counter
	addi $s6, $s6, 1  # Increment 1 into the dictionary pair position
	add $s3, $s3, $s5 # Jump to the address right after the end of the string
	
	### Routine necessary to go to the next pair
	move $a0, $s3
	jal normalize
	add $s3, $s3, $v0
	
	j Compare
	
check_ending:
	# If the dictionary's current string size indicator $s5 is 0, it is a match
	beq $s5, $zero, match
	j reset_and_next
match:
	# If there is a match, simply go back to reading another char for the buffer and store the dictionary index that caused the match
	add $v1, $s6, 1	# The dictionary index is increased by 1 because the dictionary start with 1 but the loop ($s6) start with 0
	j Get_next

######

write_compress:
	### First of all, save the $ra in the $stack
	addi $sp, $sp, -4
	sw $ra, 0($sp)
	# $v1 holds the index of the last string in the dictionary that matched with the buffer
	# buffer($s2-1) indicates the char that broke that match
	## First, we must turn the value $v1 into a string:
	# Move the value into a parameter
	move $a0, $v1
	jal int_to_ascii
	# After, $v0 will have the address of the strig to be printed and $v1 will have the number of chars to be written 
	# We must save the char that broke the string into the last position of bufferITOA
	la $t0, bufferITOA
	addi $t1, $s2, -1 	# Index of the char to be saved
	lb $t2, buffer($t1)	# Load the char into $t2
	sb $t2, 9($t0)		# Writes the char into the correct position
	
	addi $a2, $v1, 2	# Increase the number of bytes to be saved by 2 and save in the parameter
	move $a1, $v0		# Save the address to be printed
	move $a0, $s1		# Descriptor of the compressed file
	addi $v0, $zero, 15	# Write to file syscall code
	syscall
	
	### Restore $v1 to 0 and also restore $ra
	move $v1, $zero
	lw $ra, 0($sp)
	addi $sp, $sp, 4
	jr $ra
######

int_to_ascii:
	# Function necessary because write file syscall only understands ascii
	la $v0, bufferITOA
	addi $v0, $v0, 7 # Save the address of the last char representing the index in the bufferITOA
	move $t0, $a0	 # Move to $t0 which key will be converted to ascii	
	move $v1, $zero	 # Number of chars that will be written, start with zero
	beq $t0, $zero, back_zero # If the key is 0, just go to a special case to avoid the division
	
convert_int_ascii:
	# Function that effectively convert integer into ascii
	div $t0, $t0, 10 		# Divide by 10 so we can get the remainder and get a single digit at a time
	mfhi $t1			# HI holds the remainder, saved now in $t1
	addi $t1, $t1, 48		# Add 48 so we go to the ascii table position equivalent of the digit
	sb $t1, 0($v0)			# Save the digit into the 'last' byte of $v0, that is the end of the buffer to be printed
	addi $v0, $v0, -1		# Decrease $v0 to store now in another position
	addi $v1, $v1, 1		# At the end of this loop $v1 will store how many chars it needs to print to compose the key
	bne $t0, $zero, convert_int_ascii	# If $t0, that holds the current key, is zero, meaning that there are no more divisions to be made, exit the method
	
	addi $v0, $v0, 1 		# Return $v0 to the correct position, start of the bufferITOA that will be printed	
	jr $ra
back_zero:
	addi $t0, $zero, 48	# 48 is the ascii code for '0'
	sb $t0, 0($v0)		# Save this char into the correct position of the bufferITOA
	addi $v1, $v1, 1	# Indicates that there is onde char to be written	
	jr $ra			# Go back to callee

######

normalize:
	move $v0, $zero		  # Start $v0 with zero
	la $t2, dict_mem
	sub $t0, $a0, $t2 	  # Get relative distance from position to start of dictionary (Avoid extra divison on ULA?)
	addi $t1, $zero, 4
	div $t0, $t1
	mfhi $t0	 	  # Get the remainder of the divison
	beq $t0, $zero, jump_back # If we are already at a valid position of a .word, do not add 4 more extra
	sub $v0, $t1, $t0 	  # Return the bytes necessary to jump
jump_back:	
	jr $ra

######

# Check if we have to write the last string
Check_last_string:
	addi $t0, $zero, 1
	beq $s2, $t0, write_dictionary
	# If $s2 is not 1, we must prepare parameters and save the last string read
	# $v1 is already ok, 
	# We write a '\n' into the current position of $s2 and increase it by 1
	addi $t0, $zero, 8 # Writes a 'backspace' to erase last char
	sb $t0, buffer($s2)
	addi $s2, $s2, 1
	jal write_compress
	
	close_file $s0	# Close the file to be compressed
	close_file $s1	# Close the already compressed file

######

	## 	Details of what the variables are used for in the 2nd part	       ##
	# $s0 = used to store the descriptor of the dictionary				#
	# $s1 = Iterates through the dictionary (dict_mem area of memory)		#
	# $s2 = The main counter of the buffer						#
	# $s3 = How many chars we will write per syscall				#
	# $s4 = Auxiliar counter for the buffer						#
	# $s5 = Saves the lenght of the string, used to jump to next pair		#
	# $s6 = Stores how many keys we have already printed				#
	# $s7 = Still used to store the size of the dictionary 	 			#

# Write the dictionary dictionary.txt from dict_mem area of data
write_dictionary:										
	# $t4 = stores which content will be stored in the buffer per time 
	
	# Open file where the dictionary will be saved
	li $v0, 13		# Open file code
	la $a0, dictionary	# Label of the file
	li $a1, 1		# Flag 1 to always create a new dictionary
	li $a2, 0		# Write only mode
	syscall			# Effectively open the file 
	move $s0, $v0		# Save the file descriptor in $s1
	
	# Possible error during opening file verification
	beq $s0, -1, Print_error
	
	# Initialize the variables
	la $s1, dict_mem 		# Start in the begining of the dictionary memory area 
	move $s6, $zero		# $t6 will count how many keys of the dictionary it have already printed

start_printing:	
	la $s2, buffer	 	# Buffer where the characters will be saved to print in the dictionary file	
		
	lw $s3, 0($s1)		# The first value is the string length, necessary for the syscall
	add $s6, $s6, 1		# Increse the number of keys printed by one, necessary to print the right key
	
	move $a0, $s6 		# Prepare the parameter to call the method
	jal int_to_ascii	# Convert integer key into equivalent ascii,
	# After the method call, $v0 will hold the position of the first char that represents the key and $v1 will tell how many 
	# chars compose the key, so, we just need to call the method write_converted_in to move the chars to the right buffer
	move $a0, $v0		# Parameters for method
	move $a1, $v1		# Parameters for method
	jal write_converted_int # Start the buffer that will be written with the index of the pair
	
	addi $t0, $zero, 126 	# 126 is ascii label for "~"
	sb $t0, 0($s2)		
	addi $s2, $s2, 1	
	addi $s1, $s1, 4	# After the dictionary key we want it's content
 
 	move $t0, $s3
next_byte:
	lb $t1, 0($s1)		# Picks a char to copy
	sb $t1, 0($s2)		# Store byte in buffer		
	addi $s2, $s2, 1	# New position to store
	addi $s1, $s1, 1	# Next content byte
	addi $t0, $t0, -1	# Decrease counter of how many chars to copy		
	bne $t0, $zero, next_byte # If the counter is 0, than we reached the end of this string	

	addi $t0, $zero, 126 	# 126 is ascii label for "~"
	sb $t0, 0($s2)	

	add $s3, $s3, 2 	# In adition of all characters we added to the buffer we have the key and "{ }"
	add $s3, $s3, $v1 	# $v1 still stores how many chars was stored in the buffer for each key		
	
	# Jump $s1 to next valid position of .word
	move $a0, $s1
	jal normalize	  # Receives the address and returns how many bytes to jump
	add $s1, $s1, $v0

	li $v0, 15			# Write on file code
	la $a1, buffer	 		# From where it will be written
	move $a0, $s0			# File descriptor
	move $a2, $s3			# Length of the string to be written
	syscall
	 
	bne $s7, $s6, start_printing	# If there are more keys in the dictionary do it again
	j close_dictionary

write_converted_int:
	# Write into buffer the converted integer
	move $t0, $a0		# Address of chars to be copied
	move $t1, $a1		# How many chars to be copied
loop_wci:
	lb $t2, 0($t0)		# Loads into $t2 the char to be copied
	sb $t2, 0($s2) 		# Saves the char to be printed in the buffer
	addi $s2, $s2, 1	# Increase the position of the buffer
	addi $t1, $t1, -1	# Decrease counter of how many chars to copy
	addi $t0, $t0, 1	# To get next char
	bne $t1, 0 , loop_wci	# While counter is not zero, continue
	jr $ra			# Goes back to the callee

###### 

# Closes the dictionary file
close_dictionary:
	close_file $s0
	j End

Print_error:	# Print a message in case could not open a file
	li $v0, 55
	la $a0, error_msg
	add $a1, $zero, $zero
	syscall

End: # Kills the program
	li $v0, 10 # Syscall code to end program
	syscall
