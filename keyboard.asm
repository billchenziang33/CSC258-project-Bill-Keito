 ##############################################################################
# Example: Keyboard Input
#
# This file demonstrates how to read the keyboard to check if the keyboard
# key q was pressed.
##############################################################################
    .data
ADDR_KBRD:
    .word 0xffff0000

ADDR_DSPL:
    .word 0x10008000

col_x:
    .word 15                     #initialize x

col_y:
    .word 7                     #initialize y

color_top:
    .word 0xFF0000               #red

color_middle:
    .word 0x00FF00               #green

color_bottom:
    .word 0x0000FF               #blue

bg_color:
  .word 0x000000                 #black

    .text
	.globl main

main:
    jal draw_column


main_loop:
    # small delay for keyboard input search
	li 		$v0, 32
	li 		$a0, 1
	syscall

    lw $t0, ADDR_KBRD               # $t0 = base address for keyboard
    lw $t8, 0($t0)                  # Load first word from keyboard
    beq $t8, 1, keyboard_input      # If first word 1, key is pressed
    b main_loop

keyboard_input:                     # A key is pressed
    lw $a0, 4($t0)                  # Load second word from keyboard

    beq $a0, 0x71, respond_to_Q     # Check if the key q was pressed
    beq $a0, 0x61, move_left        # Check if the key a was pressed
    beq $a0, 0x64, move_right       # Check if the key d was pressed
    beq $a0, 0x77, shuffle_column   # Check if the key w was pressed
    beq $a0, 0x73, move_down        # Check if the key s was pressed

    b main_loop


move_left:
  jal erase_column

  lw $t1, col_x
  addi $t1, $t1, -1
  sw $t1, col_x

  jal draw_column
  b main_loop


move_right:
  jal erase_column

  lw $t1, col_x
  addi $t1, $t1, 1
  sw $t1, col_x

  jal draw_column
  b main_loop


shuffle_column:
  lw $t1, color_top
  lw $t2, color_middle
  lw $t3, color_bottom

  sw $t3, color_top
  sw $t2, color_bottom
  sw $t1, color_middle

  jal draw_column
  b main_loop


move_down:
   jal erase_column

  lw $t1, col_y
  addi $t1, $t1, 1
  sw $t1, col_y

  jal draw_column
  b main_loop


draw_column:
    # draw a column with three different colors
    # Position: The top middle of the edge
    # Top block  = (15,7) - > red
    # middle block  = (15,8) - > green
    # Bottom block  = (15,9) - > blue

    lw $t0, ADDR_DSPL              # $t1 = bitmap base address
    lw $t1, col_x                  # set X position
    lw $t2, col_y                  # set Y position

    # offset =(y * 32 + x) * 4
    li $t3, 32
    mul $t4, $t2, $t3
    add $t4, $t4, $t1
    sll $t5, $t4, 2
    add $t0, $t0, $t5

    lw $t5, color_top
    lw $t6, color_middle
    lw $t7, color_bottom

    sw $t5, 0($t0)                # top block
    sw $t6, 128($t0)              # middle block
    sw $t7, 256($t0)              # bottom block

    jr $ra

erase_column:
  lw $t0,ADDR_DSPL                # bitmap base address
  lw $t1, col_x                   # x position
  lw $t2, col_y                   # y position

  # offset =(y * 32 + x) * 4
    li $t3, 32
    mul $t4, $t2, $t3
    add $t4, $t4, $t1
    sll $t5, $t4, 2
    add $t0, $t0, $t5

    lw $t5, bg_color

    sw $t5, 0($t0)                # top block
    sw $t5, 128($t0)              # middle block
    sw $t5, 256($t0)              # bottom block

    jr $ra



respond_to_Q:
	li $v0, 10                      # Quit gracefully
	syscall
