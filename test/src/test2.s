.global _start

.text
	_start:
		push %rbp
		movq %rsp, %rbp
		subq $(SIZE_OF_HASH_MAP_STRUCT + 8 + 20), %rsp

		movq $0x1000, %rdi
		movq $8, %rsi
		movq $20, %rdx
		leaq 28(%rsp), %rcx
		call new_hash_map
		cmpq $0, %rax
		jl _exit

		movq $0, 20(%rsp)
		movq $69, (%rsp)
		movq $8, %rdi
		leaq 20(%rsp), %rsi
		movq $20, %rdx
		movq %rsp, %rcx
		leaq 28(%rsp), %r8
		call hash_map_insert
		
		andq %rax, %rax
		jz 0

		xorq %rax, %rax
		movq $8, %rdi
		leaq 20(%rsp), %rsi
		leaq 28(%rsp), %rdx
		call hash_map_find

		andq %rax, %rax
		jz 0

		/*
		movw $0, (%rsp)
		test_loop:
			movq $8, %rdi
			movq %rsp, %rsi
			leaq 8(%rsp), %rdx
			call hash_table_insert

			incw (%rsp)
			jz test_loop_exit
	
			jmp test_loop
		test_loop_exit:

		movw $0, (%rsp)
		find_test_loop:
			movq $8, %rdi
			movq %rsp, %rsi
			leaq 8(%rsp), %rdx
			call hash_table_find

			cmpq $0, %rax
			jle 0

			incw (%rsp)
			jz find_test_loop_exit
	
			jmp find_test_loop
		find_test_loop_exit:
		*/	
_exit:
		movq $60, %rax
		movq $0, %rdi
		syscall


