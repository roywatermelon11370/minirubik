# Hand-written RV32I adaptation of stage3_queue.c.
# Assembly generated with AI assistance; disclose this when using it.
# No M/C instructions, compiler arithmetic helpers, heap, or recursion.
# Quarter-turn tables are appended by build.ps1.
# Search order and inverse output match Stage 3 exactly.

.data
.align 2
input_state: .string "21345671111111"
.align 2
# -1 disables the optional known-optimal-length assertion for arbitrary input.
expected_length: .word 11
result_status: .word -1
result_length: .word 0
goal_p: .word 0
goal_o: .word 0
permutation_ptrs: .word permutation_turns, permutation_turns+10080, permutation_turns+20160
orientation_ptrs: .word orientation_turns, orientation_turns+1458, orientation_turns+2916
faces: .string "RBD"
suffixes: .byte 39, 50, 0
ok_message: .string "PASS\n"
bad_input_message: .string "FAIL: invalid cube input\n"
bad_result_message: .string "FAIL: search or path validation\n"
.align 2
permutation_distance: .zero 5040
orientation_distance: .zero 729
.align 2
bfs_queue: .zero 10080
path: .zero 12
.align 2
# Twelve explicit frames, 32 bytes each. No recursive procedure calls.
# frame: parent p, parent o, accumulated p, accumulated o, face, turn,
#        previous face, unused.
search_frames: .zero 384
static_end:

.text
.globl main
main:
    la a0, input_state
    jal ra, parse_input
    bltz a0, invalid_input
    la t0, goal_p
    sw a0, 0(t0)
    la t0, goal_o
    sw a1, 0(t0)

    # Exact projected distances to the requested input, like Stage 3.
    la a0, permutation_turns
    la a1, permutation_distance
    li a2, 5040
    la t0, goal_p
    lw a3, 0(t0)
    jal ra, build_distances
    beqz a0, failed_result
    la a0, orientation_turns
    la a1, orientation_distance
    li a2, 729
    la t0, goal_o
    lw a3, 0(t0)
    jal ra, build_distances
    beqz a0, failed_result

    jal ra, solve_iterative
    bltz a0, failed_result
    mv s11, a0
    la t0, result_length
    sw s11, 0(t0)
    la t0, expected_length
    lw t0, 0(t0)
    bltz t0, main_validate
    bne t0, s11, failed_result
main_validate:
    mv a0, s11
    jal ra, validate_path
    beqz a0, failed_result
    mv a0, s11
    jal ra, print_solution
    la a0, ok_message
    li a7, 4
    ecall
    la t0, result_status
    sw zero, 0(t0)
    li a0, 0
    li a7, 93
    ecall
invalid_input:
    la a0, bad_input_message
    li a7, 4
    ecall
    li t1, 2
    j exit_failure
failed_result:
    la a0, bad_result_message
    li a7, 4
    ecall
    li t1, 1
exit_failure:
    la t0, result_status
    sw t1, 0(t0)
    mv a0, t1
    li a7, 93
    ecall

# Parse and rank both coordinates with shifts/adds and no division.
# a0 = input; returns a0=p, a1=o, or a0=-1.
# Seven permutation digits must be unique; sum of twists must be 0 mod 3.
parse_input:
    mv t6, a0
    li t0, 0
    li t1, 0
parse_permutation:
    add t2, t6, t0
    lbu t3, 0(t2)
    addi t3, t3, -49
    li t4, 7
    bgeu t3, t4, parse_bad
    li t4, 1
    sll t4, t4, t3
    and t5, t1, t4
    bnez t5, parse_bad
    or t1, t1, t4
    addi t0, t0, 1
    li t4, 7
    bltu t0, t4, parse_permutation

    # Lehmer rank: weighted count of smaller digits on the right.
    # Constant factorial weights need only shifts and additions.
    li a0, 0
    li t0, 0
    li a2, 720
parse_rank_outer:
    add t2, t6, t0
    lbu t3, 0(t2)
    addi t1, t0, 1
    li t4, 0
parse_rank_inner:
    li t5, 7
    bgeu t1, t5, parse_rank_weight
    add t2, t6, t1
    lbu t5, 0(t2)
    sltu t5, t5, t3
    add t4, t4, t5
    addi t1, t1, 1
    j parse_rank_inner
parse_rank_weight:
    # At most six additions; only input parsing uses this loop.
    beqz t4, parse_rank_next
parse_rank_add:
    add a0, a0, a2
    addi t4, t4, -1
    bnez t4, parse_rank_add
parse_rank_next:
    addi t0, t0, 1
    li t5, 1
    beq t0, t5, parse_weight120
    li t5, 2
    beq t0, t5, parse_weight24
    li t5, 3
    beq t0, t5, parse_weight6
    li t5, 4
    beq t0, t5, parse_weight2
    li t5, 5
    beq t0, t5, parse_weight1
    j parse_orientations
parse_weight120:
    li a2, 120
    j parse_rank_outer
parse_weight24:
    li a2, 24
    j parse_rank_outer
parse_weight6:
    li a2, 6
    j parse_rank_outer
parse_weight2:
    li a2, 2
    j parse_rank_outer
parse_weight1:
    li a2, 1
    j parse_rank_outer
parse_orientations:
    li a1, 0
    li t0, 0
    li t1, 0
    addi t6, t6, 7
parse_orientation_loop:
    add t2, t6, t0
    lbu t3, 0(t2)
    addi t3, t3, -49
    li t4, 3
    bgeu t3, t4, parse_bad
    add t1, t1, t3
    li t4, 6
    beq t0, t4, parse_orientation_last
    slli t4, a1, 1
    add a1, a1, t4
    add a1, a1, t3
parse_orientation_last:
    addi t0, t0, 1
    li t4, 7
    bltu t0, t4, parse_orientation_loop
    lbu t2, 7(t6)
    bnez t2, parse_bad
parse_sum_mod3:
    addi t2, t1, -3
    bltz t2, parse_sum_done
    mv t1, t2
    j parse_sum_mod3
parse_sum_done:
    bnez t1, parse_bad
    ret
parse_bad:
    li a0, -1
    ret

# Leaf FIFO BFS; a0 turns, a1 distances, a2 count, a3 goal.
# Only caller-saved registers are used. Queue has at most count entries.
build_distances:
    mv t0, a1
    add t1, a1, a2
    li t2, 255
bfs_clear:
    sb t2, 0(t0)
    addi t0, t0, 1
    bltu t0, t1, bfs_clear
    add t0, a1, a3
    sb zero, 0(t0)
    la a4, bfs_queue
    mv a5, a4
    sh a3, 0(a5)
    addi a5, a5, 2
    slli a6, a2, 1
bfs_pop:
    beq a4, a5, bfs_done
    lhu t0, 0(a4)
    addi a4, a4, 2
    add t1, a1, t0
    lbu a7, 0(t1)
    addi a7, a7, 1
    mv t1, a0
    li t2, 3
bfs_face:
    mv t3, t0
    li t4, 3
bfs_turn:
    slli t5, t3, 1
    add t5, t1, t5
    lhu t3, 0(t5)
    add t5, a1, t3
    lbu t6, 0(t5)
    li a3, 255
    bne t6, a3, bfs_visited
    sb a7, 0(t5)
    sh t3, 0(a5)
    addi a5, a5, 2
bfs_visited:
    addi t4, t4, -1
    bnez t4, bfs_turn
    add t1, t1, a6
    addi t2, t2, -1
    bnez t2, bfs_face
    j bfs_pop
bfs_done:
    la t0, bfs_queue
    add t0, t0, a6
    xor t0, t0, a5
    seqz a0, t0
    ret

# Iterative IDA*, with the same nine-move order as Stage 3.
# s0/s1 table pointer arrays; s2/s3 distance bases; s4/s5 goal;
# s6 bound; s7 depth; s8 current frame; s9 path; s10 frame base.
# Does not call itself (or any other procedure).
solve_iterative:
    la s0, permutation_ptrs
    la s1, orientation_ptrs
    la s2, permutation_distance
    la s3, orientation_distance
    la t0, goal_p
    lw s4, 0(t0)
    la t0, goal_o
    lw s5, 0(t0)
    la s9, path
    la s10, search_frames
    lbu s6, 0(s2)
    lbu t0, 0(s3)
    bgeu s6, t0, search_bound_ready
    mv s6, t0
search_bound_ready:
    li s7, 0
    mv s8, s10
    sw zero, 0(s8)
    sw zero, 4(s8)
    sw zero, 8(s8)
    sw zero, 12(s8)
    sw zero, 16(s8)
    sw zero, 20(s8)
    li t0, 3
    sw t0, 24(s8)
    or t0, s4, s5
    beqz t0, search_found
search_next:
    beq s7, s6, search_backtrack
    lw t0, 16(s8)
    li t1, 3
    beq t0, t1, search_backtrack
    lw t1, 24(s8)
    beq t0, t1, search_skip_face

    # Quarter-turn lookup: power-of-two element strides, no multiplication.
    slli t1, t0, 2
    add t2, s0, t1
    lw t2, 0(t2)
    add t3, s1, t1
    lw t3, 0(t3)
    lw t4, 8(s8)
    slli t4, t4, 1
    add t2, t2, t4
    lhu a0, 0(t2)
    lw t4, 12(s8)
    slli t4, t4, 1
    add t3, t3, t4
    lhu a1, 0(t3)
    lw t1, 20(s8)
    mv a2, t1
    # Advance parent cursor before pushing a child.
    addi t1, t1, 1
    li t2, 3
    beq t1, t2, search_advance_face
    sw a0, 8(s8)
    sw a1, 12(s8)
    sw t1, 20(s8)
    j search_child
search_advance_face:
    addi t1, t0, 1
    sw t1, 16(s8)
    sw zero, 20(s8)
    lw t2, 0(s8)
    sw t2, 8(s8)
    lw t2, 4(s8)
    sw t2, 12(s8)
search_child:
    add t1, s2, a0
    lbu t1, 0(t1)
    add t2, s3, a1
    lbu t2, 0(t2)
    bgeu t1, t2, search_h_ready
    mv t1, t2
search_h_ready:
    add t1, t1, s7
    addi t1, t1, 1
    bgtu t1, s6, search_next
    # Only accepted children need a recorded path move.
    slli t2, t0, 1
    add t2, t2, t0
    add t2, t2, a2
    add t3, s9, s7
    sb t2, 0(t3)
    addi s7, s7, 1
    bne a0, s4, search_push
    beq a1, s5, search_found
search_push:
    addi s8, s8, 32
    sw a0, 0(s8)
    sw a1, 4(s8)
    sw a0, 8(s8)
    sw a1, 12(s8)
    sw zero, 16(s8)
    sw zero, 20(s8)
    sw t0, 24(s8)
    j search_next
search_skip_face:
    addi t0, t0, 1
    sw t0, 16(s8)
    j search_next
search_backtrack:
    beqz s7, search_increase_bound
    addi s7, s7, -1
    addi s8, s8, -32
    j search_next
search_increase_bound:
    addi s6, s6, 1
    li t0, 11
    bleu s6, t0, search_bound_ready
    li a0, -1
    ret
search_found:
    mv a0, s7
    ret

# T5: replay inverse(path) from the input using quarter-turn tables.
# This checks every returned move rather than relying on printed output.
validate_path:
    mv a5, a0
    la t0, goal_p
    lw a0, 0(t0)
    la t0, goal_o
    lw a1, 0(t0)
    la a2, path
    la a3, permutation_ptrs
    la a4, orientation_ptrs
validate_next:
    beqz a5, validate_done
    addi a5, a5, -1
    add t0, a2, a5
    lbu t0, 0(t0)
    li t1, 0
validate_face:
    addi t2, t0, -3
    bltz t2, validate_face_ready
    mv t0, t2
    addi t1, t1, 4
    j validate_face
validate_face_ready:
    add t2, a3, t1
    lw t2, 0(t2)
    add t3, a4, t1
    lw t3, 0(t3)
    li t4, 3
    sub t4, t4, t0
validate_turn:
    slli t5, a0, 1
    add t5, t2, t5
    lhu a0, 0(t5)
    slli t5, a1, 1
    add t5, t3, t5
    lhu a1, 0(t5)
    addi t4, t4, -1
    bnez t4, validate_turn
    j validate_next
validate_done:
    or a0, a0, a1
    seqz a0, a0
    ret

# Print inverse(path) in reverse order. a0 length.
print_solution:
    mv a5, a0
    la a2, path
    la a3, faces
    la a4, suffixes
    li a6, 0
print_next:
    beqz a5, print_done
    beqz a6, print_no_separator
    li a0, 32
    li a7, 11
    ecall
print_no_separator:
    li a6, 1
    addi a5, a5, -1
    add t0, a2, a5
    lbu t0, 0(t0)
    li t1, 0
print_face:
    addi t2, t0, -3
    bltz t2, print_face_ready
    mv t0, t2
    addi t1, t1, 1
    j print_face
print_face_ready:
    add t1, a3, t1
    lbu a0, 0(t1)
    li a7, 11
    ecall
    add t0, a4, t0
    lbu a0, 0(t0)
    beqz a0, print_next
    li a7, 11
    ecall
    j print_next
print_done:
    li a0, 10
    li a7, 11
    ecall
    ret
