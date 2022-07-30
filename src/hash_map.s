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


