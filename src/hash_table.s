.global new_hash_table
.global delete_hash_table
.global hash_table_resize
.global hash_table_insert
.global hash_table_find
.global SIZE_OF_HASH_TABLE_STRUCT

/*
	hash_table_struct:
		8byte number of entries (multiple of HASH_TABLE_GROUP_SIZE)
		8byte size of entry
		[vector] (
			NOTE: The table allocation includes the metadata in the first number_of_entries bytes.
			8byte table allocation size in bytes
			8byte pointer to table allocation                                        
		)
*/
SIZE_OF_HASH_TABLE_STRUCT = 32

/*
	hash_table_entry_metadata:
		1bit entry status
		7bit low 7 bits of hash
*/


HASH_TABLE_GROUP_SIZE = 16


.text
	# rdi: wanted number of entries; rsi: size of entry; rdx: hash_table_struct pointer -- rax: 0 = OK / -1 = ERROR
	new_hash_table:
		push %rbp
		movq %rsp, %rbp
		subq $8, %rsp
		movq %rdx, -8(%rbp)
		
		# Find the nearest power of two (and multiple of HASH_TABLE_GROUP_SIZE) to number_of_entries
		shrq $4, %rdi	
		xorq %rcx, %rcx # clear destination
		bsrq %rdi, %rcx # index of the most significant set (1) bit. Nice instruction!
		movq $(HASH_TABLE_GROUP_SIZE), %rdi   
		shlq %rcx, %rdi

		# Store sizes in hash_table_struct
		movq %rdi,  (%rdx)
		movq %rsi, 8(%rdx)

		# (number_of_entries * size_of_entry)
		movq %rdi, %rax
		mulq %rsi
		andq %rax, %rax
		jz new_hash_table_size_error
		
		# Add size of metadata, which is just the number of entries
		movq -8(%rbp), %rdx
		addq (%rdx), %rax

		# Allocate new vector
		movq %rax, %rdi
		call new_vector
		movq -8(%rbp), %rcx
		
		# Store result in hash_table_struct
		movq %rax, 16(%rcx)	
		movq %rbx, 24(%rcx)	
		
		# initialize metadata to empty
		movq (%rcx), %rcx  # metadata size
		movq $0x80, %rax   # empty
		movq %rbx, %rdi    # address
		cld
		rep stosb

		movq $0, %rax
		jmp new_hash_table_exit
	
		new_hash_table_size_error:
			movq $-1, %rax
		
		new_hash_table_exit:
		movq -8(%rbp), %rdx
		movq %rbp, %rsp
		pop %rbp
		ret

# rdi: hash_table_struct pointer
delete_hash_table:
	movq 24(%rdi), %rsi
	movq 16(%rdi), %rdi
	call vector_free

	ret


# rdi: hash_table_struct pointer; rsi: index; rdx: output buffer -- rax: reference to table entry / 0 if error
hash_table_at:
	push %rbx
	cmpq (%rdi), %rsi
	jge hash_table_at_invalid_index

	movq %rsi, %rax

	mulq  8(%rdi)		# index * size of entry
	addq 24(%rdi), %rax	# ... + start of table in memory
	addq   (%rdi), %rax	# ... + size of metadata in table

	jmp hash_table_at_exit
	hash_table_at_invalid_index:
		xorq %rax, %rax
		
	hash_table_at_exit:
	pop %rbx
	ret
	

# rdi: hash_table_struct pointer; rsi: new wanted number of entries -- rax: 0 = OK / -1 = ERROR
hash_table_resize:
	push %rbp
	movq %rsp, %rbp
	subq $24, %rsp
	movq %rdi, -8(%rbp)
	movq (%rdi), %rdi
	movq %rdi, -16(%rbp) # old number of entries
	
	subq $SIZE_OF_HASH_TABLE_STRUCT, %rsp
	
	movq %rsi, %rdi    # number of entries
	movq -8(%rbp), %rdx
	movq 8(%rdx), %rsi # size of entry (unchanged)
	movq %rsp, %rdx	   # pointer to struct in the stack
	call new_hash_table

	cmpq $0, %rax
	jl hash_table_resize_error
	
	xorq %rbx, %rbx # index
	hash_table_resize_copy:
	    # group number
		movq %rbx, %rsi
		shrq $4, %rsi
		# pointer
		movq -8(%rbp), %rdi
	
		call hash_table_group_status

		# group index = bl & 0xF
		movb %bl, %cl
		andb $0xF, %cl
		# ax = status
		hash_table_resize_copy_cells:
			movq %rax, %r15

			# if we are at the end of the group go to next group
			cmpb $HASH_TABLE_GROUP_SIZE, %cl
			jge hash_table_resize_copy_cells_exit
			

			# check status
			shrw %cl, %ax
			andw $1, %ax
			jnz hash_table_resize_copy_cells_continue # skip if emtpy
			

			movq -8(%rbp), %rdi
			movq %rbx, %rsi
			call hash_table_at
			
			movq %rax, %rsi
			movq %rsp, %rdx
			movq 8(%rsp), %rdi
			push %rcx
			call hash_table_insert			
			pop %rcx

			cmpq $0, %rax
			jl 0
			
			jmp hash_table_resize_copy_cells_continue


			hash_table_resize_copy_cells_continue:
			incb %cl # bump index
			incq %rbx # bump index

			movq %r15, %rax
			
			jmp hash_table_resize_copy_cells
		hash_table_resize_copy_cells_exit:
		cmpq -16(%rbp), %rbx
		jge hash_table_resize_copy_exit # end of table

		jmp hash_table_resize_copy
	hash_table_resize_copy_exit:

	# delete old table
	movq -8(%rbp), %rdi
	call delete_hash_table
	
	# update struct
	movq -8(%rbp), %rdi
	#	number of entries
	movq (%rsp), %rax
	movq %rax, (%rdi)
	#	size of entry
	movq 8(%rsp), %rax
	movq %rax, 8(%rdi)
	#	table allocation size
	movq 16(%rsp), %rax
	movq %rax, 16(%rdi)
	#	table allocation address
	movq 24(%rsp), %rax
	movq %rax, 24(%rdi)

	jmp hash_table_resize_exit
	hash_table_resize_error:
		movq $-1, %rax

	hash_table_resize_exit:	
	movq %rbp, %rsp
	pop %rbp
	ret
	

# rdi: hash_table_struct pointer; rsi: group number; rdx: H2 key (lower 7 bits) -- rax: 16-bit equality mask
hash_table_group_match:
	push %rdi
	push %rsi
	# get group 
	
	movq 24(%rdi),  %rcx
	shlq $4, %rsi # rsi * HASH_TABLE_GROUP_SIZE
	addq %rsi, %rcx

	# broadcast H2 key to all bytes of xmm1
	movd %edx, %xmm1	
	pxor %xmm0, %xmm0
	pshufb %xmm0, %xmm1	

	# compare xmm1 with group
	pcmpeqb (%rcx), %xmm1

	# generate equality bit-mask
	pmovmskb %xmm1, %rax

	pop %rsi
	pop %rdi
	ret

# rdi: hash_table_struct pointer; rsi: group number -- rax: 16-bit bit mask (0 = full, 1 = empty)
hash_table_group_status:
	# get group 
	
	movq 24(%rdi),  %rcx
	shlq $4, %rsi # rsi * HASH_TABLE_GROUP_SIZE
	addq %rsi, %rcx

	# I don't know if this fast
	movlps  (%rcx), %xmm1
	movhps 8(%rcx), %xmm1
	
	# generate bit-mask
	pmovmskb %xmm1, %rax

	ret

# rdi, rsi: key; rdx: hash_table_struct pointer -- rax: index of new entry / 0 if error
hash_table_insert:
	push %rbp
	push %rbx
	push %r12
	push %r13
	push %r14
	push %r15
	movq %rsp, %rbp
	
	# check the size of the key.
	cmpq %rdi, 8(%rdx)
	jne hash_table_insert_type_error

	movq %rdx, %r8 # just saving stuff for later
	movq %rdi, %r9
	movq %rsi, %r10
	
	# check if key already exists in the table
	push %rdx
	
	call hash_table_find
	andq %rax, %rax
	jnz hash_table_insert_exit # if exists just return


	movq %r9, %rdi
	movq %r10, %rsi
	call hash
	movq %rax, %rbx # save hash
	pop %rdx
	movq (%rdx), %rcx # number of entries
	
	# hash MODULO number_of_entries; it's a power of two so speeeed
	decq %rcx
	andq %rcx, %rax 
	movq %rax, %r13 # current index (higher 60 bits = group number; lower 4 bits = group entry index)
	

	hash_table_insert_groups_loop:
		movq %rdx, %r11
		movq %rsi, %r12
		
		# status
		movq %rdx, %rdi
	
	    # group number
		movq %r13, %rsi
		shrq $4, %rsi
	
		call hash_table_group_status

		# group index = r13b & 0xF
		movb %r13b, %cl
		andb $0xF, %cl
		# ax = status
		hash_table_insert_cells_loop:
			movq %rax, %r15

			# if we are at the end of the group go to next group
			cmpb $HASH_TABLE_GROUP_SIZE, %cl
			jge hash_table_insert_cells_loop_exit
			
			shrw %cl, %ax

			# check status
			andw $1, %ax
			movq %r15, %rax
			jnz hash_table_insert_insert # if empty just insert
			
			# else

			incb %cl # bump index
			incq %r13 # bump index

			jmp hash_table_insert_cells_loop
		hash_table_insert_cells_loop_exit:
		movq %r11, %rdx 
		movq %r12, %rsi 
		
		cmpq (%rdx), %r13
		jge hash_table_insert_resize # we ran out of space. We need to resize the table.

		jmp hash_table_insert_groups_loop
	
	hash_table_insert_insert:
	# get table entry index
	movq %r13, %rax
	push %rax
	
	#
	# metadata
	#

	movq %rbx, %rdx
	andq $0x7F, %rdx  # H2 key (lower 7 bits)
	movq 24(%r8), %rcx
	movb %dl, (%rcx, %rax)

	#
	# table entry
	#

	mulq %r9			# index * size of entry
	addq 24(%r8), %rax	# ... + start of table in memory
	addq   (%r8), %rax	# ... + size of metadata in table

	# copy the goodies
	movq %r9, %rcx
	movq %rax, %rdi
	movq %r10, %rsi
	rep movsb

	pop %rax
	jmp hash_table_insert_exit

	hash_table_insert_type_error:
		movq $0, %rax
		jmp hash_table_insert_exit
	
	hash_table_insert_resize:
		# size * 64
		movq (%r8), %rsi		
		shlq $6, %rsi
		movq %r8, %rdi
		push %r8
		push %r9
		push %r10
		call hash_table_resize		
		pop %r10
		pop %r9
		pop %r8
		
		# recurse	
		movq %r8, %rdx
		movq %r9, %rdi
		movq %r10, %rsi
		call hash_table_insert		
	hash_table_insert_exit:
	movq %rbp, %rsp
	pop %r15
	pop %r14
	pop %r13
	pop %r12
	pop %rbx
	pop %rbp
	ret

# rdi, rsi: key; rdx: hash_table_struct pointer -- rax: reference to data in table
hash_table_find:
	push %rbp
	push %rbx
	push %r12
	push %r13
	push %r14
	push %r15
	movq %rsp, %rbp
	xorq %rax, %rax
	# check the size of the key.
	cmpq %rdi, 8(%rdx)
	jne hash_table_insert_type_error

	movq %rdx, %r8 # just saving stuff for later
	movq %rdi, %r9
	movq %rsi, %r10

	push %rdx
	call hash
	movq %rax, %rbx # save hash
	pop %rdx
	movq (%rdx), %rcx # number of entries
	
	# hash MODULO number_of_entries; it's a power of two so speeeed
	decq %rcx
	andq %rcx, %rax

	movq %rax, %r14 # current index

	hash_table_find_groups_loop:
		movq %rdx, %r11
		movq %rsi, %r12
		movq %rax, %r13
		
		# match
		movq %rdx, %rdi
		
		movq %rbx, %rdx
		andq $0x7F, %rdx  # H2 key (lower 7 bits)
	    
		# group number
		movq %r14, %rsi
		shrq $4, %rsi
	
		call hash_table_group_match
			
		movw %ax, %dx 
		
		# status
		call hash_table_group_status

		# group index = r14b & 0xF
		movb %r14b, %cl
		andb $0xF, %cl

		# dx = match
		# ax = status
		hash_table_find_cells_loop:
			pushw %ax
			pushw %dx

			# if we are at the end of the group go to next group
			cmpb $HASH_TABLE_GROUP_SIZE, %cl
			jge hash_table_find_cells_loop_exit

			shrw %cl, %dx
			shrw %cl, %ax
			
			# check status
			andw $1, %ax
			jnz hash_table_find_no_match # if empty search failed
		
			# else do the comparisons
			
			andw $1, %dx
			
			popw %dx
			popw %ax
			
			jz hash_table_find_cells_loop_continue # if no match skip
			
			push %rax
			push %rdx
			push %rcx
			
			#
			# do the big and expensive comparison of whole hash.
			#
			movq %r14, %rax
			mulq %r9			# index * size of entry
			addq 24(%r8), %rax	# ... + start of table in memory
			addq   (%r8), %rax	# ... + size of metadata in table
				
			# calculate hash
			movq %r9, %rdi
			movq %rax, %rsi		# key in the table
			push %rsi
			call hash
			# compare two hashes
			cmpq %rax, %rbx
			jne hash_table_find_cells_loop_continue # if no match skip
			
			# compare actual key
			movq %r9, %rdi
			movq %r10, %rsi
			movq %r9, %rdx
			pop %rcx
			call vector_equals
			je hash_table_find_find # found!
		
			pop %rcx
			pop %rdx
			pop %rax
			
			hash_table_find_cells_loop_continue:
			incb %cl  # bump group index
			incq %r14 # bump table index

			jmp hash_table_find_cells_loop
		hash_table_find_cells_loop_exit:
		movq %r11, %rdx 
		movq %r12, %rsi 
		movq %r13, %rax 

		cmpq (%rdx), %r14
		jge hash_table_find_no_match # end of table. We didn't find it.

		jmp hash_table_find_groups_loop
	hash_table_find_find:
	# get table entry address
	movq %r14, %rax
	
	mulq %r9			# index * size of entry
	addq 24(%r8), %rax	# ... + start of table in memory
	addq   (%r8), %rax	# ... + size of metadata in table

	jmp hash_table_find_exit

	hash_table_find_type_error:
		movq $-1, %rax
		jmp hash_table_find_exit
	
	hash_table_find_no_match:
		xorq %rax, %rax

	hash_table_find_exit:
	movq %rbp, %rsp
	pop %r15
	pop %r14
	pop %r13
	pop %r12
	pop %rbx
	pop %rbp
	ret

.data
