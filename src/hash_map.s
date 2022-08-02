.global new_hash_map
.global delete_hash_map
.global hash_map_resize
.global hash_map_insert
.global hash_map_find
.global SIZE_OF_HASH_MAP_STRUCT

/*
	hash_map_struct:
		32byte [hash_table_struct] keys
		
		8byte size of value
		16byte [vector] values
*/

SIZE_OF_HASH_MAP_STRUCT = 32 + 24


.text
	# rdi: wanted number of entries; rsi: size of key; rdx: size of value; rcx: hash_map_struct pointer -- rax: 0 = OK / -1 = ERROR
	new_hash_map:
		movq %rdx, 32(%rcx)

		movq %rcx, %rdx
		call new_hash_table
		cmpq $0, %rax
		jl new_hash_map_error

		movq %rdx, %r9

		movq (%r9), %rax
		mulq 32(%r9)
		movq %rax, %rdi
		
		call new_vector	
		cmpq $0, %rax
		jle new_hash_map_error

		movq %rax, 40(%r9)
		movq %rbx, 48(%r9)

		xorq %rax, %rax
		jmp new_hash_map_exit

		new_hash_map_error:
			movq $-1, %rax

		new_hash_map_exit:
		movq %r9, %rdx
		ret

	# rdi: hash_map_struct pointer
	delete_hash_map:
		movq %rdi, %rdx
		call delete_hash_table

		movq 40(%rdx), %rdi
		movq 48(%rdx), %rsi
		call vector_free

		ret

	# rdi: hash_map_struct pointer; rsi: new wanted number of entries -- rax: 0 = OK / -1 = ERROR
	hash_map_resize:
		push %rbp
		push %rbx
		push %r15
		movq %rsp, %rbp
		subq $24, %rsp
		movq %rdi, -8(%rbp)
		movq (%rdi), %rdi
		movq %rdi, -16(%rbp) # old number of entries
		
		subq $SIZE_OF_HASH_MAP_STRUCT, %rsp
		
		movq %rsi, %rdi    # number of entries
		movq -8(%rbp), %rcx
		movq 8(%rcx), %rsi # size of key (unchanged)
		movq 32(%rcx), %rdx # size of value (unchanged)
		movq %rsp, %rcx	   # pointer to struct in the stack
		call new_hash_map

		cmpq $0, %rax
		jl hash_map_resize_error
		
		xorq %rbx, %rbx # index
		hash_map_resize_copy:
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
			hash_map_resize_copy_cells:
				movq %rax, %r15

				# if we are at the end of the group go to next group
				cmpb $HASH_TABLE_GROUP_SIZE, %cl
				jge hash_map_resize_copy_cells_exit
				

				# check status
				shrw %cl, %ax
				andw $1, %ax
				jnz hash_map_resize_copy_cells_continue # skip if emtpy
				

				movq -8(%rbp), %rdi
				movq %rbx, %rsi
				call hash_table_at
				
				# key
				movq 8(%rsp), %rdi  # size
				movq %rax, %rsi		# address
				# value
				movq -8(%rbp), %rdx
				movq %rbx, %rax
				mulq 32(%rdx)
				movq -8(%rbp), %rdx
				addq 48(%rdx), %rax		# address
				movq %rsp, %r8
				push %rcx
				movq %rax, %rcx
				movq 32(%rdx), %rdx # size
				call hash_map_insert			
				pop %rcx

				cmpq $0, %rax
				jl 0
				
				jmp hash_map_resize_copy_cells_continue


				hash_map_resize_copy_cells_continue:
				incb %cl # bump index
				incq %rbx # bump index

				movq %r15, %rax
				
				jmp hash_map_resize_copy_cells
			hash_map_resize_copy_cells_exit:
			cmpq -16(%rbp), %rbx
			jge hash_map_resize_copy_exit # end of table

			jmp hash_map_resize_copy
		hash_map_resize_copy_exit:

		# delete old map
		movq -8(%rbp), %rdi
		call delete_hash_map
		
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
		movq 32(%rsp), %rax
		movq %rax, 32(%rdi)
		movq 40(%rsp), %rax
		movq %rax, 40(%rdi)
		movq 48(%rsp), %rax
		movq %rax, 48(%rdi)

		jmp hash_map_resize_exit
		hash_map_resize_error:
			movq $-1, %rax

		hash_map_resize_exit:	
		movq %rbp, %rsp
		pop %r15
		pop %rbx
		pop %rbp
		ret
		
	# rdi, rsi: key; rdx, rcx: value; r8: hash_map_struct pointer -- rax: reference to new entry / 0 if error
	hash_map_insert:
		push %rbp
		push %rbx
		push %r12
		push %r13
		push %r14
		push %r15
		movq %rsp, %rbp

		cmpq %rdx, 32(%r8)
		jne hash_map_insert_error

		movq %rdx, %rbx
		movq %rcx, %r12
		movq %r8, %r13
		movq %rdi, %r14
		movq %rsi, %r15
		movq %r8, %rdx
		call hash_table_insert

		cmpq $-1, %rax
		je hash_map_insert_error	
		cmpq $-2, %rax
		je hash_map_insert_resize
		# rax = entry index

		mulq %rbx # index * value size

		movq 48(%r13), %r14
		
		leaq (%r14, %rax), %rdi # dest.
		movq %rdi, %rax			# return value
		movq %rbx, %rcx         # count
		movq %r12, %rsi			# source
		rep movsb	
		
		jmp hash_map_insert_exit
		hash_map_insert_error:
			xorq %rax, %rax
			jmp hash_map_insert_exit
		hash_map_insert_resize:
			# size * 64
			movq %r13, %rdi
			movq (%rdi), %rsi
			shlq $6, %rsi
			call hash_map_resize
		
			cmpq $0, %rax
			jl hash_map_insert_error

			# recurse
			movq %r14, %rdi
			movq %r15, %rsi
			movq %rbx, %rdx
			movq %r12, %rcx
			movq %r13, %r8
			call hash_map_insert

		hash_map_insert_exit:
		movq %rbp, %rsp
		pop %r15
		pop %r14
		pop %r13
		pop %r12
		pop %rbx
		pop %rbp
		ret

	
	# rdi, rsi: key; rdx: hash_map_struct pointer -- rax: reference to entry / 0 if error
	hash_map_find:
		push %rbp
		push %rbx
		movq %rsp, %rbp

		movq %rdx, %rbx
		call hash_table_find

		cmpq $0, %rax
		jl hash_map_find_error	

		# rax = entry index
		mulq 32(%rbx) # index * value size

		addq 48(%rbx), %rax
		
		jmp hash_map_find_exit
		hash_map_find_error:
			xorq %rax, %rax

		hash_map_find_exit:
		movq %rbp, %rsp
		pop %rbx
		pop %rbp
		ret
