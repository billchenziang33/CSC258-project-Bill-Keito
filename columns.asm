##############################################################################
# CSC258 Bitmap Display + Keyboard Input
# - Draw playfield border
# - Draw an initial 3-color column
# - a: move left
# - d: move right
# - w: shuffle colors downward
# - s: move down
# - q: quit
#
# Bitmap configuration:
# - Unit width in pixels: 8
# - Unit height in pixels: 8
# - Display width in pixels: 256
# - Display height in pixels: 256
# - Base Address for Display: 0x10008000
##############################################################################

.data
ADDR_KBRD:
    .word 0xffff0000

ADDR_DSPL:
    .word 0x10008000

# Column state
col_x:
    .word 15              # initial x (top middle inside border)

col_y:
    .word 7               # initial y

color_top:
    .word 0xFF0000        # red

color_middle:
    .word 0x00FF00        # green

color_bottom:
    .word 0x0000FF        # blue

bg_color:
    .word 0x000000        # black

.text
.globl main

##############################################################################
# main
##############################################################################
main:
    # Draw border first
    jal draw_border

    # Draw initial column
    jal draw_column

##############################################################################
# Main game loop
##############################################################################
main_loop:
    # Small delay
    li   $v0, 32
    li   $a0, 1
    syscall

    # Poll keyboard
    lw   $t0, ADDR_KBRD
    lw   $t8, 0($t0)
    beq  $t8, 1, keyboard_input
    b    main_loop

##############################################################################
# Keyboard handling
##############################################################################
keyboard_input:
    lw   $a0, 4($t0)

    beq  $a0, 0x71, respond_to_Q     # q
    beq  $a0, 0x61, move_left        # a
    beq  $a0, 0x64, move_right       # d
    beq  $a0, 0x77, shuffle_column   # w
    beq  $a0, 0x73, move_down        # s

    b    main_loop

##############################################################################
# Move left: x = x - 1
# Left inside boundary is x = 10
##############################################################################
move_left:
    lw   $t1, col_x
    li   $t2, 10
    beq  $t1, $t2, main_loop     # do nothing if already at left boundary

    jal  erase_column

    addi $t1, $t1, -1
    sw   $t1, col_x

    jal  draw_column
    b    main_loop

##############################################################################
# Move right: x = x + 1
# Right inside boundary is x = 21
##############################################################################
move_right:
    lw   $t1, col_x
    li   $t2, 21
    beq  $t1, $t2, main_loop     # do nothing if already at right boundary

    jal  erase_column

    addi $t1, $t1, 1
    sw   $t1, col_x

    jal  draw_column
    b    main_loop

##############################################################################
# Move down: y = y + 1
# Bottom inside boundary for a 3-block column:
# interior bottom row is y = 30
# so top block can go down to y = 28
##############################################################################
move_down:
    lw   $t1, col_y
    li   $t2, 28
    beq  $t1, $t2, main_loop     # do nothing if already at bottom boundary

    jal erase_column

    lw $t1, col_y
    addi $t1, $t1, 1
    sw $t1, col_y

    jal draw_column
    b main_loop

##############################################################################
# Shuffle colors downward
# new top    = old bottom
# new middle = old top
# new bottom = old middle
##############################################################################
shuffle_column:
    lw   $t1, color_top
    lw   $t2, color_middle
    lw   $t3, color_bottom

    sw   $t3, color_top
    sw   $t1, color_middle
    sw   $t2, color_bottom

    jal  draw_column
    b    main_loop

##############################################################################
# draw_column
# Draw current 3-color vertical column at (col_x, col_y)
##############################################################################
draw_column:
    lw   $t0, ADDR_DSPL
    lw   $t1, col_x
    lw   $t2, col_y

    # offset = (y * 32 + x) * 4
    li   $t3, 32
    mul  $t4, $t2, $t3
    add  $t4, $t4, $t1
    sll  $t4, $t4, 2
    add  $t0, $t0, $t4

    lw   $t5, color_top
    lw   $t6, color_middle
    lw   $t7, color_bottom

    sw   $t5, 0($t0)        # top
    sw   $t6, 128($t0)      # middle
    sw   $t7, 256($t0)      # bottom

    jr   $ra

##############################################################################
# erase_column
# Erase current column with background color
##############################################################################
erase_column:
    lw   $t0, ADDR_DSPL
    lw   $t1, col_x
    lw   $t2, col_y

    # offset = (y * 32 + x) * 4
    li   $t3, 32
    mul  $t4, $t2, $t3
    add  $t4, $t4, $t1
    sll  $t4, $t4, 2
    add  $t0, $t0, $t4

    lw   $t5, bg_color

    sw   $t5, 0($t0)
    sw   $t5, 128($t0)
    sw   $t5, 256($t0)

    jr   $ra

##############################################################################
# draw_border
# Draws the playfield border using draw_rectangle
# Color is passed in $t9
##############################################################################
draw_border:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    li   $t9, 0xFFFFFF      # white border color

    # Border top: x=10, y=6, width=12, height=1
    addi $a0, $zero, 10
    addi $a1, $zero, 6
    addi $a2, $zero, 12
    addi $a3, $zero, 1
    jal  draw_rectangle

    # Border bottom: x=10, y=31, width=12, height=1
    addi $a0, $zero, 10
    addi $a1, $zero, 31
    addi $a2, $zero, 12
    addi $a3, $zero, 1
    jal  draw_rectangle

    # Border left: x=9, y=6, width=1, height=26
    addi $a0, $zero, 9
    addi $a1, $zero, 6
    addi $a2, $zero, 1
    addi $a3, $zero, 26
    jal  draw_rectangle

    # Border right: x=22, y=6, width=1, height=26
    addi $a0, $zero, 22
    addi $a1, $zero, 6
    addi $a2, $zero, 1
    addi $a3, $zero, 26
    jal  draw_rectangle

    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
# draw_rectangle
# Arguments:
#   $a0 = x
#   $a1 = y
#   $a2 = width
#   $a3 = height
# Color:
#   $t9 = color
##############################################################################
draw_rectangle:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)

    move $t0, $a0           # start x
    move $t1, $a1           # start y
    move $t2, $a2           # width
    move $t3, $a3           # height

    li   $t4, 0             # row index = 0

rect_row_loop:
    beq  $t4, $t3, rect_done

    li   $t5, 0             # col index = 0

rect_col_loop:
    beq  $t5, $t2, next_row

    # current_x = start_x + col
    add  $t6, $t0, $t5

    # current_y = start_y + row
    add  $t7, $t1, $t4

    # addr = base + ((current_y * 32 + current_x) * 4)
    lw   $t8, ADDR_DSPL
    li   $s0, 32
    mul  $s1, $t7, $s0
    add  $s1, $s1, $t6
    sll  $s1, $s1, 2
    add  $t8, $t8, $s1

    sw   $t9, 0($t8)

    addi $t5, $t5, 1
    b    rect_col_loop

next_row:
    addi $t4, $t4, 1
    b    rect_row_loop

rect_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra

##############################################################################
# Quit
##############################################################################
respond_to_Q:
    li   $v0, 10
    syscall