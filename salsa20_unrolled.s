# an attempt to rewrite salsa20 in GNU assembly language
# this is the bottleneck in scrypt, so any little gain here will
# help tremendously in Litecoin mining
#
# using as guidelines the examples at //cs.lmu.edu/~ray/notes/gasexamples/
#
#define R(a,b) (((a) << (b)) | ((a) >> (32 - (b))))
#   void salsa20_word_specification(uint32_t out[16], uint32_t in[16])
	.globl salsa20_unrolled
	.text
#   {
#       uint32_t *x = out;
#       //memcpy((void *)x, (void *)in, 64);
#       for (uint32_t i = 0;i < 16;++i) x[i] = in[i];
#       for (uint32_t i = 0; i < 4; i++) {
#           x[ 4] ^= R(x[ 0]+x[12], 7);  x[ 8] ^= R(x[ 4]+x[ 0], 9);
#           x[12] ^= R(x[ 8]+x[ 4],13);  x[ 0] ^= R(x[12]+x[ 8],18);
#           x[ 9] ^= R(x[ 5]+x[ 1], 7);  x[13] ^= R(x[ 9]+x[ 5], 9);
#           x[ 1] ^= R(x[13]+x[ 9],13);  x[ 5] ^= R(x[ 1]+x[13],18);
#           x[14] ^= R(x[10]+x[ 6], 7);  x[ 2] ^= R(x[14]+x[10], 9);
#           x[ 6] ^= R(x[ 2]+x[14],13);  x[10] ^= R(x[ 6]+x[ 2],18);
#           x[ 3] ^= R(x[15]+x[11], 7);  x[ 7] ^= R(x[ 3]+x[15], 9);
#           x[11] ^= R(x[ 7]+x[ 3],13);  x[15] ^= R(x[11]+x[ 7],18);
#           x[ 1] ^= R(x[ 0]+x[ 3], 7);  x[ 2] ^= R(x[ 1]+x[ 0], 9);
#           x[ 3] ^= R(x[ 2]+x[ 1],13);  x[ 0] ^= R(x[ 3]+x[ 2],18);
#           x[ 6] ^= R(x[ 5]+x[ 4], 7);  x[ 7] ^= R(x[ 6]+x[ 5], 9);
#           x[ 4] ^= R(x[ 7]+x[ 6],13);  x[ 5] ^= R(x[ 4]+x[ 7],18);
#           x[11] ^= R(x[10]+x[ 9], 7);  x[ 8] ^= R(x[11]+x[10], 9);
#           x[ 9] ^= R(x[ 8]+x[11],13);  x[10] ^= R(x[ 9]+x[ 8],18);
#           x[12] ^= R(x[15]+x[14], 7);  x[13] ^= R(x[12]+x[15], 9);
#           x[14] ^= R(x[13]+x[12],13);  x[15] ^= R(x[14]+x[13],18);
#       }
#       for (uint32_t i = 0;i < 16;++i) x[i] += in[i];
#   }
salsa20_unrolled:
	# save registers required by cdecl convention
	push %ebp
	push %edi
	push %esi
	push %ebx
	# at this point the stack contains:
	# the 16 bytes of the 4 registers we just pushed...
	# the 4 bytes of the return address, which makes 20 bytes...
	# the "out" address, and the "in" address, in that order.
	mov 20(%esp), %edi  # destination (out)
	mov 24(%esp), %esi  # source (in)
	movdqa (%esi), %xmm0
	movapd %xmm0, (%edi)
	movdqa 16(%esi), %xmm1
	movapd %xmm1, 16(%edi)
	movdqa 32(%esi), %xmm2
	movapd %xmm2, 32(%edi)
	movdqa 48(%esi), %xmm3
	movapd %xmm3, 48(%edi)
	# restore %esi as pointer for the salsa shuffle
	mov 20(%esp), %esi  # out, where the work will be done.
shuffle:
	# first group of 4 is offsets 0, 4, 8, 12
	mov 48(%esi), %ebp  # x[12]
	mov 0(%esi), %ecx  # x[0]

	# x[ 4] ^= R(x[ 0]+x[12], 7)
	mov %ebp, %ebx
	mov 16(%esi), %edx  # x[4]
	add %ecx, %ebx
	mov 32(%esi), %edi  # x[8]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[ 8] ^= R(x[ 4]+x[ 0], 9)
	mov %ecx, %ebx
	mov %edx, 16(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[12] ^= R(x[ 8]+x[ 4],13)
	mov %edx, %ebx
	mov %edi, 32(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ebp

	# x[ 0] ^= R(x[12]+x[ 8],18)
	mov %edi, %ebx
	mov %ebp, 48(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $14, %ebx
	shl $18, %eax
	or %eax, %ebx
	xor %ebx, %ecx
	mov %ecx, 0(%esi)

	# next group of 4: offsets 1, 5, 9, 13
	mov 20(%esi), %edx  # x[5]
	mov 4(%esi), %ecx  # x[1]

	# x[ 9] ^= R(x[ 5]+x[ 1], 7)
	mov %ecx, %ebx
	mov 36(%esi), %edi  # x[9]
	add %edx, %ebx
	mov 52(%esi), %ebp  # x[13]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[13] ^= R(x[ 9]+x[ 5], 9)
	mov %edx, %ebx
	mov %edi, 36(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ebp

	# x[ 1] ^= R(x[13]+x[ 9],13)
	mov %edi, %ebx
	mov %ebp, 52(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 5] ^= R(x[ 1]+x[13],18)
	mov %ebp, %ebx
	mov %ecx, 4(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $14, %ebx
	shl $18, %eax
	or %eax, %ebx
	xor %ebx, %edx
	mov %edx, 20(%esi)

	# next group: offsets 2, 6, 10, 14
	mov 40(%esi), %edi  # x[10]
	mov 24(%esi), %edx  # x[6]

	# x[14] ^= R(x[10]+x[ 6], 7)
	mov %edx, %ebx
	mov 56(%esi), %ebp  # x[14]
	add %edi, %ebx
	mov 8(%esi), %ecx  # x[2]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ebp

	# x[ 2] ^= R(x[14]+x[10], 9)
	mov %edi, %ebx
	mov %ebp, 56(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 6] ^= R(x[ 2]+x[14],13)
	mov %ebp, %ebx
	mov %ecx, 8(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[10] ^= R(x[ 6]+x[ 2],18)
	add %edx, %ecx
	mov %edx, 24(%esi)
	mov %ecx, %eax
	shr $14, %ecx
	shl $18, %eax
	or %ecx, %eax
	xor %eax, %edi
	mov %edi, 40(%esi)

	# next: offsets 3, 7, 11, 15
	mov 60(%esi), %ebp  # x[15]
	mov 44(%esi), %edi  # x[11]

	# x[ 3] ^= R(x[15]+x[11], 7)
	mov %edi, %ebx
	mov 12(%esi), %ecx  # x[3]
	add %ebp, %ebx
	mov 28(%esi), %edx  # x[7]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 7] ^= R(x[ 3]+x[15], 9)
	mov %ebp, %ebx
	mov %ecx, 12(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[11] ^= R(x[ 7]+x[ 3],13)
	mov %ecx, %ebx
	mov %edx, 28(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[15] ^= R(x[11]+x[ 7],18)
	add %edi, %edx
	mov %edi, 44(%esi)
	mov %edx, %eax
	shr $14, %edx
	shl $18, %eax
	or %eax, %edx
	xor %edx, %ebp
	mov %ebp, 60(%esi)

	# next group: offsets 0, 1, 2, 3
	# %ecx still has x[3] from last round, so we break our usual pattern
	mov 4(%esi), %edx  # x[1]
	mov 0(%esi), %ebp  # x[0]

	# x[ 1] ^= R(x[ 0]+x[ 3], 7)
	mov %ecx, %ebx
	mov 8(%esi), %edi  # x[2]
	add %ebp, %ebx
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[ 2] ^= R(x[ 1]+x[ 0], 9)
	mov %ebp, %ebx
	mov %edx, 4(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[ 3] ^= R(x[ 2]+x[ 1],13)
	mov %edx, %ebx
	mov %edi, 8(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 0] ^= R(x[ 3]+x[ 2],18)
	add %ecx, %edi
	mov %ecx, 12(%esi)
	mov %edi, %eax
	shr $14, %edi
	shl $18, %eax
	or %edi, %eax
	xor %eax, %ebp
	mov %ebp, 0(%esi)

	# next group shuffles offsets 4, 5, 6, and 7
	mov 20(%esi), %edx  # x[5]
	mov 16(%esi), %ecx  # x[4]

	# x[ 6] ^= R(x[ 5]+x[ 4], 7)
	mov %ecx, %ebx
	mov 24(%esi), %edi  # x[6]
	add %edx, %ebx
	mov 28(%esi), %ebp  # x[7]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[ 7] ^= R(x[ 6]+x[ 5], 9)
	mov %edx, %ebx
	mov %edi, 24(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ebp  # new x[7]

	# x[ 4] ^= R(x[ 7]+x[ 6],13)  # %edx:x[4], %edi:x[6], %ebp:x[7]
	mov %edi, %ebx
	mov %ebp, 28(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ecx  # new x[4]

	# x[ 5] ^= R(x[ 4]+x[ 7],18)  # %edx:x[5], %ecx:x[4], %ebp:x[7]
	add %ecx, %ebp
	mov %ecx, 16(%esi)
	mov %ebp, %eax
	shr $14, %ebp
	shl $18, %eax
	or %eax, %ebp
	xor %ebp, %edx
	mov %edx, 20(%esi)

	# next group: offsets 8, 9, 10, 11
	mov 40(%esi), %edi  # x[10]
	mov 36(%esi), %edx  # x[9]

	# x[11] ^= R(x[10]+x[ 9], 7)
	mov %edx, %ebx
	mov 44(%esi), %ebp  # x[11]
	add %edi, %ebx
	mov 32(%esi), %ecx  # x[8]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ebp  # new x[11]

	# x[ 8] ^= R(x[11]+x[10], 9)
	mov %edi, %ebx
	mov %ebp, 44(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ecx  # new x[8]

	# x[ 9] ^= R(x[ 8]+x[11],13)  # reminder: 8:ecx, 9:edx, 10:edi, 11:ebp
	mov %ebp, %ebx
	mov %ecx, 32(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[10] ^= R(x[ 9]+x[ 8],18)
	add %edx, %ecx
	mov %edx, 36(%esi)
	mov %ecx, %eax
	shr $14, %ecx
	shl $18, %eax
	or %ecx, %eax
	xor %eax, %edi
	mov %edi, 40(%esi)

	# final group: offsets 12, 13, 14, 15
	mov 60(%esi), %ebp  # x[15]
	mov 56(%esi), %edi  # x[14]

	# x[12] ^= R(x[15]+x[14], 7)
	mov %edi, %ebx
	mov 48(%esi), %ecx  # x[12]
	add %ebp, %ebx
	mov 52(%esi), %edx  # x[13]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[13] ^= R(x[12]+x[15], 9)  # reminder: 12:ecx,13:edx,14:edi,15:ebp
	mov %ebp, %ebx
	mov %ecx, 48(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[14] ^= R(x[13]+x[12],13)
	mov %ecx, %ebx
	mov %edx, 52(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[15] ^= R(x[14]+x[13],18)
	add %edi, %edx
	mov %edi, 56(%esi)
	mov %edx, %eax
	shr $14, %edx
	shl $18, %eax
	or %edx, %eax
	xor %eax, %ebp
	mov %ebp, 60(%esi)

	# first group of 4 is offsets 0, 4, 8, 12
	mov 48(%esi), %ebp  # x[12]
	mov 0(%esi), %ecx  # x[0]

	# x[ 4] ^= R(x[ 0]+x[12], 7)
	mov %ebp, %ebx
	mov 16(%esi), %edx  # x[4]
	add %ecx, %ebx
	mov 32(%esi), %edi  # x[8]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[ 8] ^= R(x[ 4]+x[ 0], 9)
	mov %ecx, %ebx
	mov %edx, 16(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[12] ^= R(x[ 8]+x[ 4],13)
	mov %edx, %ebx
	mov %edi, 32(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ebp

	# x[ 0] ^= R(x[12]+x[ 8],18)
	mov %edi, %ebx
	mov %ebp, 48(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $14, %ebx
	shl $18, %eax
	or %eax, %ebx
	xor %ebx, %ecx
	mov %ecx, 0(%esi)

	# next group of 4: offsets 1, 5, 9, 13
	mov 20(%esi), %edx  # x[5]
	mov 4(%esi), %ecx  # x[1]

	# x[ 9] ^= R(x[ 5]+x[ 1], 7)
	mov %ecx, %ebx
	mov 36(%esi), %edi  # x[9]
	add %edx, %ebx
	mov 52(%esi), %ebp  # x[13]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[13] ^= R(x[ 9]+x[ 5], 9)
	mov %edx, %ebx
	mov %edi, 36(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ebp

	# x[ 1] ^= R(x[13]+x[ 9],13)
	mov %edi, %ebx
	mov %ebp, 52(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 5] ^= R(x[ 1]+x[13],18)
	mov %ebp, %ebx
	mov %ecx, 4(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $14, %ebx
	shl $18, %eax
	or %eax, %ebx
	xor %ebx, %edx
	mov %edx, 20(%esi)

	# next group: offsets 2, 6, 10, 14
	mov 40(%esi), %edi  # x[10]
	mov 24(%esi), %edx  # x[6]

	# x[14] ^= R(x[10]+x[ 6], 7)
	mov %edx, %ebx
	mov 56(%esi), %ebp  # x[14]
	add %edi, %ebx
	mov 8(%esi), %ecx  # x[2]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ebp

	# x[ 2] ^= R(x[14]+x[10], 9)
	mov %edi, %ebx
	mov %ebp, 56(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 6] ^= R(x[ 2]+x[14],13)
	mov %ebp, %ebx
	mov %ecx, 8(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[10] ^= R(x[ 6]+x[ 2],18)
	add %edx, %ecx
	mov %edx, 24(%esi)
	mov %ecx, %eax
	shr $14, %ecx
	shl $18, %eax
	or %ecx, %eax
	xor %eax, %edi
	mov %edi, 40(%esi)

	# next: offsets 3, 7, 11, 15
	mov 60(%esi), %ebp  # x[15]
	mov 44(%esi), %edi  # x[11]

	# x[ 3] ^= R(x[15]+x[11], 7)
	mov %edi, %ebx
	mov 12(%esi), %ecx  # x[3]
	add %ebp, %ebx
	mov 28(%esi), %edx  # x[7]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 7] ^= R(x[ 3]+x[15], 9)
	mov %ebp, %ebx
	mov %ecx, 12(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[11] ^= R(x[ 7]+x[ 3],13)
	mov %ecx, %ebx
	mov %edx, 28(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[15] ^= R(x[11]+x[ 7],18)
	add %edi, %edx
	mov %edi, 44(%esi)
	mov %edx, %eax
	shr $14, %edx
	shl $18, %eax
	or %eax, %edx
	xor %edx, %ebp
	mov %ebp, 60(%esi)

	# next group: offsets 0, 1, 2, 3
	# %ecx still has x[3] from last round, so we break our usual pattern
	mov 4(%esi), %edx  # x[1]
	mov 0(%esi), %ebp  # x[0]

	# x[ 1] ^= R(x[ 0]+x[ 3], 7)
	mov %ecx, %ebx
	mov 8(%esi), %edi  # x[2]
	add %ebp, %ebx
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[ 2] ^= R(x[ 1]+x[ 0], 9)
	mov %ebp, %ebx
	mov %edx, 4(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[ 3] ^= R(x[ 2]+x[ 1],13)
	mov %edx, %ebx
	mov %edi, 8(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 0] ^= R(x[ 3]+x[ 2],18)
	add %ecx, %edi
	mov %ecx, 12(%esi)
	mov %edi, %eax
	shr $14, %edi
	shl $18, %eax
	or %edi, %eax
	xor %eax, %ebp
	mov %ebp, 0(%esi)

	# next group shuffles offsets 4, 5, 6, and 7
	mov 20(%esi), %edx  # x[5]
	mov 16(%esi), %ecx  # x[4]

	# x[ 6] ^= R(x[ 5]+x[ 4], 7)
	mov %ecx, %ebx
	mov 24(%esi), %edi  # x[6]
	add %edx, %ebx
	mov 28(%esi), %ebp  # x[7]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[ 7] ^= R(x[ 6]+x[ 5], 9)
	mov %edx, %ebx
	mov %edi, 24(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ebp  # new x[7]

	# x[ 4] ^= R(x[ 7]+x[ 6],13)  # %edx:x[4], %edi:x[6], %ebp:x[7]
	mov %edi, %ebx
	mov %ebp, 28(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ecx  # new x[4]

	# x[ 5] ^= R(x[ 4]+x[ 7],18)  # %edx:x[5], %ecx:x[4], %ebp:x[7]
	add %ecx, %ebp
	mov %ecx, 16(%esi)
	mov %ebp, %eax
	shr $14, %ebp
	shl $18, %eax
	or %eax, %ebp
	xor %ebp, %edx
	mov %edx, 20(%esi)

	# next group: offsets 8, 9, 10, 11
	mov 40(%esi), %edi  # x[10]
	mov 36(%esi), %edx  # x[9]

	# x[11] ^= R(x[10]+x[ 9], 7)
	mov %edx, %ebx
	mov 44(%esi), %ebp  # x[11]
	add %edi, %ebx
	mov 32(%esi), %ecx  # x[8]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ebp  # new x[11]

	# x[ 8] ^= R(x[11]+x[10], 9)
	mov %edi, %ebx
	mov %ebp, 44(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ecx  # new x[8]

	# x[ 9] ^= R(x[ 8]+x[11],13)  # reminder: 8:ecx, 9:edx, 10:edi, 11:ebp
	mov %ebp, %ebx
	mov %ecx, 32(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[10] ^= R(x[ 9]+x[ 8],18)
	add %edx, %ecx
	mov %edx, 36(%esi)
	mov %ecx, %eax
	shr $14, %ecx
	shl $18, %eax
	or %ecx, %eax
	xor %eax, %edi
	mov %edi, 40(%esi)

	# final group: offsets 12, 13, 14, 15
	mov 60(%esi), %ebp  # x[15]
	mov 56(%esi), %edi  # x[14]

	# x[12] ^= R(x[15]+x[14], 7)
	mov %edi, %ebx
	mov 48(%esi), %ecx  # x[12]
	add %ebp, %ebx
	mov 52(%esi), %edx  # x[13]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[13] ^= R(x[12]+x[15], 9)  # reminder: 12:ecx,13:edx,14:edi,15:ebp
	mov %ebp, %ebx
	mov %ecx, 48(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[14] ^= R(x[13]+x[12],13)
	mov %ecx, %ebx
	mov %edx, 52(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[15] ^= R(x[14]+x[13],18)
	add %edi, %edx
	mov %edi, 56(%esi)
	mov %edx, %eax
	shr $14, %edx
	shl $18, %eax
	or %edx, %eax
	xor %eax, %ebp
	mov %ebp, 60(%esi)

	# first group of 4 is offsets 0, 4, 8, 12
	mov 48(%esi), %ebp  # x[12]
	mov 0(%esi), %ecx  # x[0]

	# x[ 4] ^= R(x[ 0]+x[12], 7)
	mov %ebp, %ebx
	mov 16(%esi), %edx  # x[4]
	add %ecx, %ebx
	mov 32(%esi), %edi  # x[8]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[ 8] ^= R(x[ 4]+x[ 0], 9)
	mov %ecx, %ebx
	mov %edx, 16(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[12] ^= R(x[ 8]+x[ 4],13)
	mov %edx, %ebx
	mov %edi, 32(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ebp

	# x[ 0] ^= R(x[12]+x[ 8],18)
	mov %edi, %ebx
	mov %ebp, 48(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $14, %ebx
	shl $18, %eax
	or %eax, %ebx
	xor %ebx, %ecx
	mov %ecx, 0(%esi)

	# next group of 4: offsets 1, 5, 9, 13
	mov 20(%esi), %edx  # x[5]
	mov 4(%esi), %ecx  # x[1]

	# x[ 9] ^= R(x[ 5]+x[ 1], 7)
	mov %ecx, %ebx
	mov 36(%esi), %edi  # x[9]
	add %edx, %ebx
	mov 52(%esi), %ebp  # x[13]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[13] ^= R(x[ 9]+x[ 5], 9)
	mov %edx, %ebx
	mov %edi, 36(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ebp

	# x[ 1] ^= R(x[13]+x[ 9],13)
	mov %edi, %ebx
	mov %ebp, 52(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 5] ^= R(x[ 1]+x[13],18)
	mov %ebp, %ebx
	mov %ecx, 4(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $14, %ebx
	shl $18, %eax
	or %eax, %ebx
	xor %ebx, %edx
	mov %edx, 20(%esi)

	# next group: offsets 2, 6, 10, 14
	mov 40(%esi), %edi  # x[10]
	mov 24(%esi), %edx  # x[6]

	# x[14] ^= R(x[10]+x[ 6], 7)
	mov %edx, %ebx
	mov 56(%esi), %ebp  # x[14]
	add %edi, %ebx
	mov 8(%esi), %ecx  # x[2]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ebp

	# x[ 2] ^= R(x[14]+x[10], 9)
	mov %edi, %ebx
	mov %ebp, 56(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 6] ^= R(x[ 2]+x[14],13)
	mov %ebp, %ebx
	mov %ecx, 8(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[10] ^= R(x[ 6]+x[ 2],18)
	add %edx, %ecx
	mov %edx, 24(%esi)
	mov %ecx, %eax
	shr $14, %ecx
	shl $18, %eax
	or %ecx, %eax
	xor %eax, %edi
	mov %edi, 40(%esi)

	# next: offsets 3, 7, 11, 15
	mov 60(%esi), %ebp  # x[15]
	mov 44(%esi), %edi  # x[11]

	# x[ 3] ^= R(x[15]+x[11], 7)
	mov %edi, %ebx
	mov 12(%esi), %ecx  # x[3]
	add %ebp, %ebx
	mov 28(%esi), %edx  # x[7]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 7] ^= R(x[ 3]+x[15], 9)
	mov %ebp, %ebx
	mov %ecx, 12(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[11] ^= R(x[ 7]+x[ 3],13)
	mov %ecx, %ebx
	mov %edx, 28(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[15] ^= R(x[11]+x[ 7],18)
	add %edi, %edx
	mov %edi, 44(%esi)
	mov %edx, %eax
	shr $14, %edx
	shl $18, %eax
	or %eax, %edx
	xor %edx, %ebp
	mov %ebp, 60(%esi)

	# next group: offsets 0, 1, 2, 3
	# %ecx still has x[3] from last round, so we break our usual pattern
	mov 4(%esi), %edx  # x[1]
	mov 0(%esi), %ebp  # x[0]

	# x[ 1] ^= R(x[ 0]+x[ 3], 7)
	mov %ecx, %ebx
	mov 8(%esi), %edi  # x[2]
	add %ebp, %ebx
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[ 2] ^= R(x[ 1]+x[ 0], 9)
	mov %ebp, %ebx
	mov %edx, 4(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[ 3] ^= R(x[ 2]+x[ 1],13)
	mov %edx, %ebx
	mov %edi, 8(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 0] ^= R(x[ 3]+x[ 2],18)
	add %ecx, %edi
	mov %ecx, 12(%esi)
	mov %edi, %eax
	shr $14, %edi
	shl $18, %eax
	or %edi, %eax
	xor %eax, %ebp
	mov %ebp, 0(%esi)

	# next group shuffles offsets 4, 5, 6, and 7
	mov 20(%esi), %edx  # x[5]
	mov 16(%esi), %ecx  # x[4]

	# x[ 6] ^= R(x[ 5]+x[ 4], 7)
	mov %ecx, %ebx
	mov 24(%esi), %edi  # x[6]
	add %edx, %ebx
	mov 28(%esi), %ebp  # x[7]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[ 7] ^= R(x[ 6]+x[ 5], 9)
	mov %edx, %ebx
	mov %edi, 24(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ebp  # new x[7]

	# x[ 4] ^= R(x[ 7]+x[ 6],13)  # %edx:x[4], %edi:x[6], %ebp:x[7]
	mov %edi, %ebx
	mov %ebp, 28(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ecx  # new x[4]

	# x[ 5] ^= R(x[ 4]+x[ 7],18)  # %edx:x[5], %ecx:x[4], %ebp:x[7]
	add %ecx, %ebp
	mov %ecx, 16(%esi)
	mov %ebp, %eax
	shr $14, %ebp
	shl $18, %eax
	or %eax, %ebp
	xor %ebp, %edx
	mov %edx, 20(%esi)

	# next group: offsets 8, 9, 10, 11
	mov 40(%esi), %edi  # x[10]
	mov 36(%esi), %edx  # x[9]

	# x[11] ^= R(x[10]+x[ 9], 7)
	mov %edx, %ebx
	mov 44(%esi), %ebp  # x[11]
	add %edi, %ebx
	mov 32(%esi), %ecx  # x[8]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ebp  # new x[11]

	# x[ 8] ^= R(x[11]+x[10], 9)
	mov %edi, %ebx
	mov %ebp, 44(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ecx  # new x[8]

	# x[ 9] ^= R(x[ 8]+x[11],13)  # reminder: 8:ecx, 9:edx, 10:edi, 11:ebp
	mov %ebp, %ebx
	mov %ecx, 32(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[10] ^= R(x[ 9]+x[ 8],18)
	add %edx, %ecx
	mov %edx, 36(%esi)
	mov %ecx, %eax
	shr $14, %ecx
	shl $18, %eax
	or %ecx, %eax
	xor %eax, %edi
	mov %edi, 40(%esi)

	# final group: offsets 12, 13, 14, 15
	mov 60(%esi), %ebp  # x[15]
	mov 56(%esi), %edi  # x[14]

	# x[12] ^= R(x[15]+x[14], 7)
	mov %edi, %ebx
	mov 48(%esi), %ecx  # x[12]
	add %ebp, %ebx
	mov 52(%esi), %edx  # x[13]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[13] ^= R(x[12]+x[15], 9)  # reminder: 12:ecx,13:edx,14:edi,15:ebp
	mov %ebp, %ebx
	mov %ecx, 48(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[14] ^= R(x[13]+x[12],13)
	mov %ecx, %ebx
	mov %edx, 52(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[15] ^= R(x[14]+x[13],18)
	add %edi, %edx
	mov %edi, 56(%esi)
	mov %edx, %eax
	shr $14, %edx
	shl $18, %eax
	or %edx, %eax
	xor %eax, %ebp
	mov %ebp, 60(%esi)

	# first group of 4 is offsets 0, 4, 8, 12
	mov 48(%esi), %ebp  # x[12]
	mov 0(%esi), %ecx  # x[0]

	# x[ 4] ^= R(x[ 0]+x[12], 7)
	mov %ebp, %ebx
	mov 16(%esi), %edx  # x[4]
	add %ecx, %ebx
	mov 32(%esi), %edi  # x[8]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[ 8] ^= R(x[ 4]+x[ 0], 9)
	mov %ecx, %ebx
	mov %edx, 16(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[12] ^= R(x[ 8]+x[ 4],13)
	mov %edx, %ebx
	mov %edi, 32(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ebp

	# x[ 0] ^= R(x[12]+x[ 8],18)
	mov %edi, %ebx
	mov %ebp, 48(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $14, %ebx
	shl $18, %eax
	or %eax, %ebx
	xor %ebx, %ecx
	mov %ecx, 0(%esi)

	# next group of 4: offsets 1, 5, 9, 13
	mov 20(%esi), %edx  # x[5]
	mov 4(%esi), %ecx  # x[1]

	# x[ 9] ^= R(x[ 5]+x[ 1], 7)
	mov %ecx, %ebx
	mov 36(%esi), %edi  # x[9]
	add %edx, %ebx
	mov 52(%esi), %ebp  # x[13]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[13] ^= R(x[ 9]+x[ 5], 9)
	mov %edx, %ebx
	mov %edi, 36(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ebp

	# x[ 1] ^= R(x[13]+x[ 9],13)
	mov %edi, %ebx
	mov %ebp, 52(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 5] ^= R(x[ 1]+x[13],18)
	mov %ebp, %ebx
	mov %ecx, 4(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $14, %ebx
	shl $18, %eax
	or %eax, %ebx
	xor %ebx, %edx
	mov %edx, 20(%esi)

	# next group: offsets 2, 6, 10, 14
	mov 40(%esi), %edi  # x[10]
	mov 24(%esi), %edx  # x[6]

	# x[14] ^= R(x[10]+x[ 6], 7)
	mov %edx, %ebx
	mov 56(%esi), %ebp  # x[14]
	add %edi, %ebx
	mov 8(%esi), %ecx  # x[2]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ebp

	# x[ 2] ^= R(x[14]+x[10], 9)
	mov %edi, %ebx
	mov %ebp, 56(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 6] ^= R(x[ 2]+x[14],13)
	mov %ebp, %ebx
	mov %ecx, 8(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[10] ^= R(x[ 6]+x[ 2],18)
	add %edx, %ecx
	mov %edx, 24(%esi)
	mov %ecx, %eax
	shr $14, %ecx
	shl $18, %eax
	or %ecx, %eax
	xor %eax, %edi
	mov %edi, 40(%esi)

	# next: offsets 3, 7, 11, 15
	mov 60(%esi), %ebp  # x[15]
	mov 44(%esi), %edi  # x[11]

	# x[ 3] ^= R(x[15]+x[11], 7)
	mov %edi, %ebx
	mov 12(%esi), %ecx  # x[3]
	add %ebp, %ebx
	mov 28(%esi), %edx  # x[7]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 7] ^= R(x[ 3]+x[15], 9)
	mov %ebp, %ebx
	mov %ecx, 12(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[11] ^= R(x[ 7]+x[ 3],13)
	mov %ecx, %ebx
	mov %edx, 28(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[15] ^= R(x[11]+x[ 7],18)
	add %edi, %edx
	mov %edi, 44(%esi)
	mov %edx, %eax
	shr $14, %edx
	shl $18, %eax
	or %eax, %edx
	xor %edx, %ebp
	mov %ebp, 60(%esi)

	# next group: offsets 0, 1, 2, 3
	# %ecx still has x[3] from last round, so we break our usual pattern
	mov 4(%esi), %edx  # x[1]
	mov 0(%esi), %ebp  # x[0]

	# x[ 1] ^= R(x[ 0]+x[ 3], 7)
	mov %ecx, %ebx
	mov 8(%esi), %edi  # x[2]
	add %ebp, %ebx
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[ 2] ^= R(x[ 1]+x[ 0], 9)
	mov %ebp, %ebx
	mov %edx, 4(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[ 3] ^= R(x[ 2]+x[ 1],13)
	mov %edx, %ebx
	mov %edi, 8(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[ 0] ^= R(x[ 3]+x[ 2],18)
	add %ecx, %edi
	mov %ecx, 12(%esi)
	mov %edi, %eax
	shr $14, %edi
	shl $18, %eax
	or %edi, %eax
	xor %eax, %ebp
	mov %ebp, 0(%esi)

	# next group shuffles offsets 4, 5, 6, and 7
	mov 20(%esi), %edx  # x[5]
	mov 16(%esi), %ecx  # x[4]

	# x[ 6] ^= R(x[ 5]+x[ 4], 7)
	mov %ecx, %ebx
	mov 24(%esi), %edi  # x[6]
	add %edx, %ebx
	mov 28(%esi), %ebp  # x[7]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[ 7] ^= R(x[ 6]+x[ 5], 9)
	mov %edx, %ebx
	mov %edi, 24(%esi)
	add %edi, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ebp  # new x[7]

	# x[ 4] ^= R(x[ 7]+x[ 6],13)  # %edx:x[4], %edi:x[6], %ebp:x[7]
	mov %edi, %ebx
	mov %ebp, 28(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %ecx  # new x[4]

	# x[ 5] ^= R(x[ 4]+x[ 7],18)  # %edx:x[5], %ecx:x[4], %ebp:x[7]
	add %ecx, %ebp
	mov %ecx, 16(%esi)
	mov %ebp, %eax
	shr $14, %ebp
	shl $18, %eax
	or %eax, %ebp
	xor %ebp, %edx
	mov %edx, 20(%esi)

	# next group: offsets 8, 9, 10, 11
	mov 40(%esi), %edi  # x[10]
	mov 36(%esi), %edx  # x[9]

	# x[11] ^= R(x[10]+x[ 9], 7)
	mov %edx, %ebx
	mov 44(%esi), %ebp  # x[11]
	add %edi, %ebx
	mov 32(%esi), %ecx  # x[8]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ebp  # new x[11]

	# x[ 8] ^= R(x[11]+x[10], 9)
	mov %edi, %ebx
	mov %ebp, 44(%esi)
	add %ebp, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %ecx  # new x[8]

	# x[ 9] ^= R(x[ 8]+x[11],13)  # reminder: 8:ecx, 9:edx, 10:edi, 11:ebp
	mov %ebp, %ebx
	mov %ecx, 32(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[10] ^= R(x[ 9]+x[ 8],18)
	add %edx, %ecx
	mov %edx, 36(%esi)
	mov %ecx, %eax
	shr $14, %ecx
	shl $18, %eax
	or %ecx, %eax
	xor %eax, %edi
	mov %edi, 40(%esi)

	# final group: offsets 12, 13, 14, 15
	mov 60(%esi), %ebp  # x[15]
	mov 56(%esi), %edi  # x[14]

	# x[12] ^= R(x[15]+x[14], 7)
	mov %edi, %ebx
	mov 48(%esi), %ecx  # x[12]
	add %ebp, %ebx
	mov 52(%esi), %edx  # x[13]
	mov %ebx, %eax
	shr $25, %ebx
	shl $7, %eax
	or %eax, %ebx
	xor %ebx, %ecx

	# x[13] ^= R(x[12]+x[15], 9)  # reminder: 12:ecx,13:edx,14:edi,15:ebp
	mov %ebp, %ebx
	mov %ecx, 48(%esi)
	add %ecx, %ebx
	mov %ebx, %eax
	shr $23, %ebx
	shl $9, %eax
	or %eax, %ebx
	xor %ebx, %edx

	# x[14] ^= R(x[13]+x[12],13)
	mov %ecx, %ebx
	mov %edx, 52(%esi)
	add %edx, %ebx
	mov %ebx, %eax
	shr $19, %ebx
	shl $13, %eax
	or %eax, %ebx
	xor %ebx, %edi

	# x[15] ^= R(x[14]+x[13],18)
	add %edi, %edx
	mov %edi, 56(%esi)
	mov %edx, %eax
	shr $14, %edx
	shl $18, %eax
	or %edx, %eax
	xor %eax, %ebp
	mov %ebp, 60(%esi)

	# now add IN to OUT before returning
	mov 20(%esp), %esi  # both source and destination (out)
	movdqa (%esi), %xmm4
	paddd %xmm4, %xmm0
	movapd %xmm0, (%esi)
	movdqa 16(%esi), %xmm5
	paddd %xmm5, %xmm1
	movapd %xmm1, 16(%esi)
	movdqa 32(%esi), %xmm6
	paddd %xmm6, %xmm2
	movapd %xmm2, 32(%esi)
	movdqa 48(%esi), %xmm7
	paddd %xmm7, %xmm3
	movapd %xmm3, 48(%esi)
	pop %ebx
	pop %esi
	pop %edi
	pop %ebp
	ret
# vim: set tabstop=4 expandtab shiftwidth=4 softtabstop=4
