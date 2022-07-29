.global _start

.text
	_start:
		push %rbp
		movq %rsp, %rbp
		subq $(SIZE_OF_HASH_TABLE_STRUCT + 8), %rsp

		movq $2, %rdi
		movq $8, %rsi
		leaq 8(%rsp), %rdx
		call new_hash_table
		cmpq $0, %rax
		jl _exit

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
		
_exit:
		movq $60, %rax
		movq $0, %rdi
		syscall


