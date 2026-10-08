# RV32I adaptation of stage3_coordinates.c.

.ifndef RENDER
.equ RENDER, 0
.endif
.ifndef LED_DELAY
.equ LED_DELAY, 1000000
.endif
.if RENDER
.if LED_MATRIX_0_WIDTH != 35
.error "LED Matrix Width must be 35"
.endif
.if LED_MATRIX_0_HEIGHT != 25
.error "LED Matrix Height must be 25"
.endif
.endif

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
path: .zero 12
.align 2
# Twelve explicit frames, 32 bytes each. No recursive procedure calls.
# frame: parent p, parent o, accumulated p, accumulated o, face, turn,
#        previous face, unused.
search_frames: .zero 384
.if RENDER
.align 2
.globl led_state, led_frame_count, led_move_count
led_state: .zero 16           # Cubie IDs[8], followed by twists[8].
led_next: .zero 16
led_frame_count: .word 0
led_move_count: .word 0
led_return: .word 0           # Fixed return slots; no recursive calls.
led_print_return: .word 0
led_print_remaining: .word 0
led_print_total: .word 0
led_print_move: .word 0
led_turns: .word 0
.endif
static_end:
.equ GOAL_O_OFFSET, goal_o-goal_p
.equ RESULT_LENGTH_OFFSET, result_length-expected_length

.text
.globl main
main:
    la a0, input_state
    jal ra, parse_input
    bltz a0, invalid_input
    mv s4, a0
    mv s5, a1
    la t0, goal_p
    sw a0, 0(t0)
    sw a1, GOAL_O_OFFSET(t0)
.if RENDER
    jal ra, renderer_init
.endif

    # Exact projected distances to the requested input, like Stage 3.
    la a0, permutation_turns
    la a1, permutation_distance
    li a2, 5040
    mv a3, s4
    jal ra, build_distances
    beqz a0, failed_result
    la a0, orientation_turns
    la a1, orientation_distance
    li a2, 729
    mv a3, s5
    jal ra, build_distances
    beqz a0, failed_result

    jal ra, solve_iterative
    bltz a0, failed_result
    mv s11, a0
    la t0, expected_length
    sw s11, RESULT_LENGTH_OFFSET(t0)
    lw t0, 0(t0)
    bltz t0, main_validate
    bne t0, s11, failed_result
main_validate:
    mv a0, s11
    jal ra, validate_path
    beqz a0, failed_result
    mv a0, s11
    jal ra, print_solution
.if RENDER
    jal ra, renderer_validate_solved
    beqz a0, failed_result
.endif
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
    li a4, 0
    li a0, 0
    la a3, rank_weights
# Validate and rank in one pass. The seventh cubie needs validation only.
parse_rank_outer:
    add t2, t6, t0
    lbu t3, 0(t2)
    addi t5, t3, -49
    li t4, 7
    bgeu t5, t4, parse_bad
    li t4, 1
    sll t4, t4, t5
    and t5, a4, t4
    bnez t5, parse_bad
    or a4, a4, t4
    li t4, 6
    beq t0, t4, parse_orientations
    slli t5, t0, 1
    add t5, a3, t5
    lhu a2, 0(t5)
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

# Layer-scanning BFS from stage3_coordinates.c (no FIFO queue).
# a0 turns, a1 distance, a2 count, a3 goal; returns a0=1 on success.
# Each new entry is written at depth+1 and processed on the next level.
# The stride count*2 is a shift; all remaining arithmetic is add/subtract.
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
    li a4, 1
    li a5, 0
    slli a6, a2, 1
    li t1, 255
bfs_level:
    li a7, 0
    li t0, 0
bfs_scan:
    add t6, a1, t0
    lbu t6, 0(t6)
    bne t6, a5, bfs_next_state
    mv t2, a0
    li t3, 3
bfs_face:
    mv t4, t0
    li t5, 3
bfs_turn:
    slli t6, t4, 1
    add t6, t2, t6
    lhu t4, 0(t6)
    add t6, a1, t4
    lbu a3, 0(t6)
    bne a3, t1, bfs_seen
    addi a3, a5, 1
    sb a3, 0(t6)
    addi a7, a7, 1
bfs_seen:
    addi t5, t5, -1
    bnez t5, bfs_turn
    add t2, t2, a6
    addi t3, t3, -1
    bnez t3, bfs_face
bfs_next_state:
    addi t0, t0, 1
    bltu t0, a2, bfs_scan
    beqz a7, bfs_unreachable
    add a4, a4, a7
    addi a5, a5, 1
    bltu a4, a2, bfs_level
    li a0, 1
    ret
bfs_unreachable:
    li a0, 0
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
    # main has already set s4/s5; all intervening leaf routines preserve them.
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
    # max(pd,od) <= remaining is equivalent to BOTH distances <= remaining.
    # A rejected permutation needs no orientation-distance load/comparison.
    sub t3, s6, s7
    addi t3, t3, -1
    add t1, s2, a0
    lbu t1, 0(t1)
    bgtu t1, t3, search_next
    add t2, s3, a1
    lbu t2, 0(t2)
    bgtu t2, t3, search_next
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
    # Immutable goal registers are still live after solve_iterative.
    mv a0, s4
    mv a1, s5
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
.if RENDER
    la t0, led_print_return
    sw ra, 0(t0)
    la t0, led_print_remaining
    sw a0, 0(t0)
    la t0, led_print_total
    sw a0, 0(t0)
led_print_next:
    la t0, led_print_remaining
    lw t1, 0(t0)
    beqz t1, led_print_done
    la t2, led_print_total
    lw t2, 0(t2)
    beq t1, t2, led_print_no_separator
    li a0, 32
    li a7, 11
    ecall
led_print_no_separator:
    addi t1, t1, -1
    sw t1, 0(t0)
    la t2, path
    add t2, t2, t1
    lbu t2, 0(t2)
    la t0, led_print_move
    sw t2, 0(t0)
    li t1, 0
led_print_face:
    addi t0, t2, -3
    bltz t0, led_print_face_ready
    mv t2, t0
    addi t1, t1, 1
    j led_print_face
led_print_face_ready:
    la t0, faces
    add t0, t0, t1
    lbu a0, 0(t0)
    li a7, 11
    ecall
    la t0, suffixes
    add t0, t0, t2
    lbu a0, 0(t0)
    beqz a0, led_print_redraw
    li a7, 11
    ecall
led_print_redraw:
    la t0, led_print_move
    lw a0, 0(t0)
    jal ra, renderer_move
    j led_print_next
led_print_done:
    li a0, 10
    li a7, 11
    ecall
    la t0, led_print_return
    lw ra, 0(t0)
    ret
.else
    mv a5, a0
    la a2, path
    la a3, faces
    la a4, suffixes
    li a6, 0
    # Ripes print_char preserves a7; this leaf uses only that ecall.
    li a7, 11
print_next:
    beqz a5, print_done
    beqz a6, print_no_separator
    li a0, 32
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
    ecall
    add t0, a4, t0
    lbu a0, 0(t0)
    beqz a0, print_next
    ecall
    j print_next
print_done:
    li a0, 10
    ecall
    ret
.endif

.if RENDER
# Read the input's actual cubies/twists, clear all 35x25 LEDs, and draw it.
# These routines use a*/t* registers only, preserving main's s11 length.
renderer_init:
    la t0, led_return
    sw ra, 0(t0)
    la t0, led_state
    sb zero, 0(t0)
    sb zero, 8(t0)
    la t1, input_state
    li t2, 1
renderer_init_corner:
    lbu t3, 0(t1)
    addi t3, t3, -48
    add t4, t0, t2
    sb t3, 0(t4)
    lbu t3, 7(t1)
    addi t3, t3, -49
    sb t3, 8(t4)
    addi t1, t1, 1
    addi t2, t2, 1
    li t3, 8
    bltu t2, t3, renderer_init_corner
    la t0, led_frame_count
    sw zero, 0(t0)
    la t0, led_move_count
    sw zero, 0(t0)
    li t0, LED_MATRIX_0_BASE
    li t1, LED_MATRIX_0_HEIGHT
renderer_clear_row:
    li t2, LED_MATRIX_0_WIDTH
renderer_clear_column:
    sw zero, 0(t0)
    addi t0, t0, 4
    addi t2, t2, -1
    bnez t2, renderer_clear_column
    addi t1, t1, -1
    bnez t1, renderer_clear_row
    jal ra, renderer_draw
    jal ra, renderer_pause
    la t0, led_return
    lw ra, 0(t0)
    ret

# a0 is a move from the solved->input search path. Apply its INVERSE,
# exactly as print_solution emits it: 3-(move%3) quarter-turns of its face.
renderer_move:
    la t0, led_return
    sw ra, 0(t0)
    li t0, 0
renderer_move_face:
    addi t1, a0, -3
    bltz t1, renderer_move_face_ready
    mv a0, t1
    addi t0, t0, 1
    j renderer_move_face
renderer_move_face_ready:
    li t1, 3
    sub t1, t1, a0
    la t2, led_turns
    sw t1, 0(t2)
    slli t0, t0, 3
    la t1, led_twist
    add t1, t1, t0
    la t2, led_source
    add t0, t2, t0
renderer_quarter:
    li t2, 0
    la t3, led_state
    la t4, led_next
renderer_corner:
    add t5, t0, t2
    lbu t5, 0(t5)
    add t6, t3, t5
    lbu a0, 0(t6)
    lbu a1, 8(t6)
    add t6, t1, t2
    lbu t6, 0(t6)
    add a1, a1, t6
    addi a1, a1, -3
    bgez a1, renderer_mod_ready
    addi a1, a1, 3
renderer_mod_ready:
    add t5, t4, t2
    sb a0, 0(t5)
    sb a1, 8(t5)
    addi t2, t2, 1
    li t5, 8
    bltu t2, t5, renderer_corner
    mv a0, t4
    mv a1, t3
    li t2, 4
renderer_copy:
    lw t5, 0(a0)
    sw t5, 0(a1)
    addi a0, a0, 4
    addi a1, a1, 4
    addi t2, t2, -1
    bnez t2, renderer_copy
    la t5, led_turns
    lw t6, 0(t5)
    addi t6, t6, -1
    sw t6, 0(t5)
    bnez t6, renderer_quarter
    la t0, led_move_count
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
    jal ra, renderer_draw
    jal ra, renderer_pause
    la t0, led_return
    lw ra, 0(t0)
    ret

# Paint 24 facelets, each 4 LEDs wide and 3 high. Row-major MMIO:
# BASE + 4*(35*y+x), with 35*y = (y<<5)+(y<<1)+y.
# RGB of slot k is colors[cubie][(k+orientation)%3]. Sum is at most 4.
renderer_draw:
    la a0, led_facelets
    li a1, 24
    la a2, led_state
    la a3, led_corner_colors
    li a4, LED_MATRIX_0_BASE
renderer_facelet:
    lbu t0, 0(a0)
    lbu t1, 1(a0)
    lbu t2, 2(a0)
    lbu t3, 3(a0)
    add t4, a2, t0
    lbu t0, 0(t4)
    lbu t4, 8(t4)
    add t1, t1, t4
    addi t1, t1, -3
    bgez t1, renderer_slot_ready
    addi t1, t1, 3
renderer_slot_ready:
    slli t4, t0, 1
    add t4, t4, t0
    add t4, t4, t1
    slli t4, t4, 2
    add t4, a3, t4
    lw t5, 0(t4)
    slli t6, t3, 5
    slli t4, t3, 1
    add t6, t6, t4
    add t6, t6, t3
    add t6, t6, t2
    slli t6, t6, 2
    add t6, a4, t6
    li t2, LED_MATRIX_0_WIDTH << 2
    li a5, 3
renderer_pixel_row:
    mv a7, t6
    li a6, 4
renderer_pixel_column:
    sw t5, 0(a7)
    addi a7, a7, 4
    addi a6, a6, -1
    bnez a6, renderer_pixel_column
    add t6, t6, t2
    addi a5, a5, -1
    bnez a5, renderer_pixel_row
    addi a0, a0, 4
    addi a1, a1, -1
    bnez a1, renderer_facelet
    la t0, led_frame_count
    lw t1, 0(t0)
    addi t1, t1, 1
    sw t1, 0(t0)
    ret

renderer_pause:
    li t0, LED_DELAY
    beqz t0, renderer_pause_done
renderer_pause_loop:
    addi t0, t0, -1
    bnez t0, renderer_pause_loop
renderer_pause_done:
    ret

# Independent renderer-state check: all 8 cubies home and all twists zero.
renderer_validate_solved:
    la t0, led_state
    li t1, 0
renderer_validate_corner:
    lbu t2, 0(t0)
    bne t2, t1, renderer_validate_bad
    lbu t2, 8(t0)
    bnez t2, renderer_validate_bad
    addi t0, t0, 1
    addi t1, t1, 1
    li t2, 8
    bltu t1, t2, renderer_validate_corner
    li a0, 1
    ret
renderer_validate_bad:
    li a0, 0
    ret
.endif
