################# CSC258 Assembly Final Project ###################
# This file contains our implementation of Columns.
#
# Student 1: Name, Student Number
# Student 2: Name, Student Number (if applicable)
#
# We assert that the code submitted here is entirely our own 
# creation, and will indicate otherwise when it is not.
#
######################## Bitmap Display Configuration ########################
# - Unit width in pixels:       TODO
# - Unit height in pixels:      TODO
# - Display width in pixels:    TODO
# - Display height in pixels:   TODO
# - Base Address for Display:   0x10008000 ($gp)
##############################################################################

    .data
##############################################################################
# Immutable Data
##############################################################################
# The address of the bitmap display. Don't forget to connect it!
ADDR_DSPL:
    .word 0x10008000
# The address of the keyboard. Don't forget to connect it!
ADDR_KBRD:
    .word 0xffff0000

##############################################################################
# Mutable Data
##############################################################################

##############################################################################
# Code
##############################################################################
	.text
	.globl main

    # Run the game.
main:
    # Initialize the game
    lw $t0, ADDR_DSPL
    jal draw_border # draw border of the game

game_loop:
    # 1a. Check if key has been pressed
    # 1b. Check which key has been pressed
    # 2a. Check for collisions
	# 2b. Update locations (capsules)
	# 3. Draw the screen
	# 4. Sleep

    # 5. Go back to Step 1
    j game_loop

###
###  The border drawing code
###
draw_border:
  li $t9, 0xffffff   # white
    
  # Initialize the input parameters for the draw_rectangle function (Border top)
  addi $a0, $zero, 10             # Set the X coordinate for the top left corner of the rectangle
  addi $a1, $zero, 6              # Set the Y coordinate for the top left corner of the rectangle
  addi $a2, $zero, 12             # Set the width of the rectangle
  addi $a3, $zero, 1             # Set the height of the rectangle
  jal draw_rectangle
  
  # Initialize the input parameters for the draw_rectangle function (Border bottom)
  addi $a0, $zero, 10            # Set the X coordinate for the top left corner of the rectangle
  addi $a1, $zero, 31            # Set the Y coordinate for the top left corner of the rectangle
  addi $a2, $zero, 12            # Set the width of the rectangle
  addi $a3, $zero, 1             # Set the height of the rectangle
  jal draw_rectangle
  
  # Initialize the input parameters for the draw_rectangle function (Border left)
  addi $a0, $zero, 9              # Set the X coordinate for the top left corner of the rectangle
  addi $a1, $zero, 6              # Set the Y coordinate for the top left corner of the rectangle
  addi $a2, $zero, 1              # Set the width of the rectangle
  addi $a3, $zero, 26             # Set the height of the rectangle
  jal draw_rectangle
  
  # Initialize the input parameters for the draw_rectangle function (Border right)
  addi $a0, $zero, 22             # Set the X coordinate for the top left corner of the rectangle
  addi $a1, $zero, 6              # Set the Y coordinate for the top left corner of the rectangle
  addi $a2, $zero, 1              # Set the width of the rectangle
  addi $a3, $zero, 26             # Set the height of the rectangle
  jal draw_rectangle


###
###  The rectangle drawing code
###  Draws a filled rectangle by repeatedly calling draw_line.
###  Each iteration draws one horizontal line and moves down one row.
###
###  Variables:
###  - $a0 = The X coordinate of the top left corner of the rectangle
###  - $a1 = The Y coordinate of the top left corner of the rectangle
###  - $a2 = The width of the rectangle
###  - $a3 = The height of the rectangle
###  - $t0 = The address in memory of the top left corner of the bitmap.
###  - $t1 = The loop index of the current row being drawn
###  - $t9 = The colour value for a white pixel

draw_rectangle:
move $t7, $a1　　　　　　　　　　　　　　# Save original Y coordinate because $a1 will be modified inside the loop
add $t1, $zero, $zero               # Initialize the loop index variable to zero
# Start of the rectangle drawing loop
draw_rect_loop:
beq $t1, $a3, end_draw_rect_loop    # Branch out of the loop if the index variable is the same as the height
addi $sp, $sp, -4                   # move the stack pointer to an empty location on top of the stack (decrement $sp by 4)
sw $t1, 0($sp)                      # push $t1 onto the stack
addi $sp, $sp, -4                   # move the stack pointer to an empty location on top of the stack (decrement $sp by 4)
sw $ra, 0($sp)                      # push $ra onto the stack
jal draw_line                       # Draw a line
lw $ra, 0($sp)                      # pop $ra from the stack
addi $sp, $sp, 4                    # move the stack pointer back to the top stack element
lw $t1, 0($sp)                      # pop $t1 from the stack
addi $sp, $sp, 4                    # move the stack pointer back to the top stack element
addi $t1, $t1, 1                    # Increment the index variable to the next line in the rectangle 
addi $a1, $a1, 1                    # Move the Y coordinate to the next line
j draw_rect_loop                    # Jump to the start of the loop
end_draw_rect_loop:                 # End of the rectangle drawing loop
move $a1, $t7                       # Restore original Y coordinate before returning (to avoid side effects)
jr $ra                              # Return to calling program


###
###  The line drawing code
###
###  Variables:
###  - $a0 = The X coordinate of the starting point for the line
###  - $a1 = The Y coordinate of the starting point for the line
###  - $a2 = The length of the line
###  - $t0 = The address in memory of the top left corner of the bitmap.
###  - $t1 = The vertical offset (from the Y coordinate)
###  - $t2 = The horizontal offset (from the X coordinate)
###  - $t3 = The address in memory of the current pixel to draw
###  - $t4 = The address in memory of the final pixel in the line
###  - $t5 = The width in bytes of the line
###  - $t9 = The colour value for a white pixel

draw_line:
sll $t1, $a1, 7                     # Calculate the vertical offset to add to $t0 (multiply $a1 by 128)
add $t3, $t0, $t1                   # Add this offset to $t0, store the updated location in $t3
sll $t2, $a0, 2                     # Calculate the horizontal offset to add to the vslue above (multiply $a0 by 4)
add $t3, $t3, $t2                   # Add this horizontal offset to $t3
sll $t5, $a2, 2                     # Calculate the offset between the starting location in the line and the end location.
add $t4, $t3, $t5                   # Calculate the location in memory of the end pixel in the line.

# Start of the loop
draw_line_loop:
beq $t3, $t4, end_draw_line_loop    # Exit the loop if the current pixel location is the location of the end of the line
sw $t9, 0($t3)                      # Draw a white pixel at the current location
addi $t3, $t3, 4                    # Move the current pixel location one pixel over to the right
j draw_line_loop                    # Jump to the start of the loop
end_draw_line_loop:
jr $ra                              # return to the calling program