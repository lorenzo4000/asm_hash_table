.global hash

.text
	# rdi: size; rsi: bytes
	djb2:
		push %rbp
		movq %rsp, %rbp
		push %r8
		
		movq $5381, %rax  # hash
		movq $0, %rcx	  # index
		djb2_main_loop:
			cmpq %rdi, %rcx
			jge djb2_exit		
			
			movq %rax, %rdx
			shlq $5, %rax 			   # hash << 5
			addq %rdx, %rax 		   # hash + hash
			movzbq (%rsi, %rcx), %r8   # hash + c
			addq %r8, %rax

			incq %rcx
			jmp djb2_main_loop
		djb2_exit:
		pop %r8
		movq %rbp, %rsp
		pop %rbp
		ret

	hash:
		push %rbp
		movq %rsp, %rbp
		
		call djb2
		
		movq %rbp, %rsp
		pop %rbp
		ret
