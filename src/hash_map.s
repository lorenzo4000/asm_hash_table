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

		
	# rdi, rsi: key; rdx, rcx: value; r8: hash_map_struct pointer -- rax: reference to new entry / 0 if error
	hash_map_insert:
		cmpq %rdx, 32(%r8)
		jne hash_map_insert_exit

		movq %rdx, %rbx
		movq %rcx, %r12
		movq %r8, %r13
		movq %r8, %rdx
		call hash_table_insert

		andq %rax, %rax
		jz hash_map_insert_error	
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

		hash_map_insert_exit:
		ret
