/*
	vector:
		8byte size
		8byte address
*/

.global new_vector
.global vector_free
.global vector_equals
.global vector_endl
.global vector_push_front
.global vector_push

.text
#rdi, rsi: vector; rdx: data address; rcx: data size --
#rax, rbx: new vector
vector_push_front:
	push %rbp
	movq %rsp, %rbp
	subq $0x20, %rsp
	movq %rdi, -8(%rbp)
	movq %rsi, -16(%rbp)
	movq %rdx, -24(%rbp)
	movq %rcx, -32(%rbp)

	movq $0, %rdi
	call new_vector
	mov %rax, %rdi
	mov %rbx, %rsi

	# push new
	mov -24(%rbp), %rdx   
	mov -32(%rbp), %rcx   
	call vector_push	
	mov %rax, %rdi
	mov %rbx, %rsi

	# push old
	mov -16(%rbp), %rdx   
	mov -8(%rbp), %rcx   
	call vector_push	
	push %rax
	push %rbx
	
	movq -8(%rbp), %rdi
	movq -16(%rbp), %rsi	
	call vector_free

	pop %rbx
	pop %rax
	movq %rbp, %rsp	
	pop %rbp	
	ret
# rdi: initial size -- rax, rbx: new vector
new_vector:  
	push %rsi
	push %r9
 	movq $9, %rax            # mmap
	movq %rdi, %rsi 
	movq $0, %rdi 
	movq $(0x1  | 0x2), %rdx # PROT_READ | PROT_WRITE
	movq $(0x20 | 0x2), %r10 # MAP_ANON  | MAP_PRIVATE
	movq $0, %r9 	
	syscall
	mov %rax, %rbx           # address
	mov %rsi, %rax           # size
	pop %r9
	pop %rsi
	ret	

#rdi, rsi: vector 
vector_free:
	push %rbp
	movq %rsp, %rbp
	push %rdi
	push %rsi
	#munmap(%rsi, %rdi)
	movq $11, %rax
	movq %rdi, %rcx
	movq %rsi, %rdi
	movq %rcx, %rsi
	syscall
	pop %rsi
	pop %rdi
	movq %rbp, %rsp
	pop %rbp
	ret


# rdi, rsi: vector a; rdx, rcx: vector b -- zero flag: 1 if a == b; else 0
vector_equals:
	push %rdi
	push %rsi
	push %r9
	cmp %rdi, %rdx
	jne vector_equals_exit
	
	movq %rcx, %r9
	movq %rdi, %rcx
	movq %r9, %rdi	
	repe cmpsb

	vector_equals_exit:
	pop %r9
	pop %rsi
	pop %rdi
	ret

# rdi, rsi: vector -- rax, rbx: new vector
vector_endl:
	subq $1, %rsp
	movb $0x0A, (%rsp)
	
	movq %rsp, %rdx
	movq $1, %rcx
	call vector_push

	addq $1, %rsp
	ret










#rdi, rsi: vector; rdx: data address; rcx: data size --
#rax, rbx: new vector
vector_push:
	push %rbp
	movq %rsp, %rbp
	subq $0x20, %rsp
	movq %rdi, -8(%rbp)
	movq %rsi, -16(%rbp)
	movq %rdx, -24(%rbp)
	movq %rcx, -32(%rbp)

	addq %rcx, %rdi
	call new_vector
	push %rax

	cmpq $0, -8(%rbp)	
	jle vector_push_append_new

	mov -16(%rbp), %rsi   
	mov -8(%rbp), %rcx   
	mov %rbx, %rdi
	cld
	rep movsb

	vector_push_append_new:
	mov -24(%rbp), %rsi   
	mov -32(%rbp), %rcx   
	mov %rbx, %rdi
	addq -8(%rbp), %rdi
	cld
	rep movsb
		
	movq -8(%rbp), %rdi
	movq -16(%rbp), %rsi	
	call vector_free

	pop %rax
	movq %rbp, %rsp	
	pop %rbp	
	ret
