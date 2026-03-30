##############################################################################
# CSC258 Bitmap Display + Keyboard Input
# - Draw playfield border
# - Draw an initial 3-color column
# - a: move left
# - d: move right
# - w: shuffle colors downward
# - s: move down
# - q: quit
# - r: retry (on game over screen)
# - p: paused and resume
# - 1: Easy mode
# - 2: Medium mode
# - 3: Hard mode

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
    .word 6              # initial x (top middle inside border)

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

color_list:
  .word 0xFF0000        # red
  .word 0x00FF00        # green
  .word 0x0000FF        # blue
  .word 0xFFFF00        # yellow
  .word 0xFF00FF        # magenta
  .word 0x00FFFF        # cyan

grid:
  .space 4096

mark_grid:
  .space 4096    # 32 * 32 * 4

score:
    .word 0

high_score:
    .word 0

score_fg_color:
    .word 0xFFFFFF

score_bg_color:
    .word 0x000000

drop_counter:
    .word 0

drop_speed: # Default speed
    .word 60

speed_step:# Decrease speed by 5 every 100 points
    .word 5

difficulty:
    .word 0   # 0=easy, 1=medium, 2=hard

paused:
    .word 0 # Paused

# 3x5 digit font (3 bits each row), 10 digits * 5 rows
digit_font_3x5:
    # 0
    .word 0b111
    .word 0b101
    .word 0b101
    .word 0b101
    .word 0b111
    # 1
    .word 0b010
    .word 0b110
    .word 0b010
    .word 0b010
    .word 0b111
    # 2
    .word 0b111
    .word 0b001
    .word 0b111
    .word 0b100
    .word 0b111
    # 3
    .word 0b111
    .word 0b001
    .word 0b111
    .word 0b001
    .word 0b111
    # 4
    .word 0b101
    .word 0b101
    .word 0b111
    .word 0b001
    .word 0b001
    # 5
    .word 0b111
    .word 0b100
    .word 0b111
    .word 0b001
    .word 0b111
    # 6
    .word 0b111
    .word 0b100
    .word 0b111
    .word 0b101
    .word 0b111
    # 7
    .word 0b111
    .word 0b001
    .word 0b001
    .word 0b001
    .word 0b001
    # 8
    .word 0b111
    .word 0b101
    .word 0b111
    .word 0b101
    .word 0b111
    # 9
    .word 0b111
    .word 0b101
    .word 0b111
    .word 0b001
    .word 0b111

.text
.globl main

##############################################################################
# main
##############################################################################
main:
    # jal select_difficulty
    # Clear entire screen first (grid is all zeros after reset)
    jal draw_grid

    # Draw border
    jal draw_border

    jal draw_title
    jal draw_score

    jal get_random_color
    sw $v0, color_top

    jal get_random_color
    sw $v0, color_middle

    jal get_random_color
    sw $v0, color_bottom

    # Draw initial column
    jal draw_column

    jal select_difficulty

##############################################################################
# Main game loop
##############################################################################
main_loop:

    jal update_speed
    # Small delay
    li   $v0, 32
    li   $a0, 16
    syscall

    lw   $t0, drop_counter
    addi $t0, $t0, 1
    sw   $t0, drop_counter

    lw   $t1, drop_speed
    blt  $t0, $t1, skip_auto_drop

    # reset the count
    li   $t0, 0
    sw   $t0, drop_counter

    # Move down
    jal  move_down

skip_auto_drop:

    # Poll keyboard
    lw   $t0, ADDR_KBRD
    lw   $t8, 0($t0)
    beq  $t8, 1, keyboard_input
    b    main_loop

##############################################################################
# Speed handling
##############################################################################
update_speed:
    # --- decide base_speed based on difficulty ---
    lw   $t0, difficulty

    beq  $t0, 0, set_easy_speed
    beq  $t0, 1, set_medium_speed
    beq  $t0, 2, set_hard_speed

set_easy_speed:
    li   $t3, 60     # easy
    b base_done

set_medium_speed:
    li   $t3, 50     # medium
    b base_done

set_hard_speed:
    li   $t3, 35     # hard

base_done:

    # --- level = score / 100 ---
    lw   $t1, score #set score
    li   $t2, 100 #set 100
    div  $t1, $t2 #score / 100
    mflo $t4         # level

    # --- speed = base - level * step ---
    lw   $t5, speed_step
    mul  $t6, $t4, $t5
    sub  $t7, $t3, $t6

    # --- Lowest speed constraint ---
    li   $t8, 10 # set lowest speed to 10
    bgt  $t7, $t8, speed_ok
    li   $t7, 10

speed_ok:
    sw   $t7, drop_speed

    jr $ra

##############################################################################
# Select difficulty
##############################################################################
select_difficulty:

wait_input:
    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    beq  $t1, 1, key_pressed
    b    wait_input

key_pressed:
    lw   $t2, 4($t0)   # Get the pressed key

    li   $t3, 0x31     # Press '1'
    beq  $t2, $t3, set_easy_diff # Set easy level

    li   $t3, 0x32     # Press '2'
    beq  $t2, $t3, set_medium_diff #Set Medium level

    li   $t3, 0x33     # Press '3'
    beq  $t2, $t3, set_hard_diff #Set Hard level

    b wait_input

set_easy_diff:
    li $t4, 0
    sw $t4, difficulty
    jr $ra

set_medium_diff:
    li $t4, 1
    sw $t4, difficulty
    jr $ra

set_hard_diff:
    li $t4, 2
    sw $t4, difficulty
    jr $ra

##############################################################################
# Keyboard handling
##############################################################################ss
keyboard_input:
    lw   $a0, 4($t0)

    beq  $a0, 0x71, game_over_screen # q
    beq  $a0, 0x61, move_left        # a
    beq  $a0, 0x64, move_right       # d
    beq  $a0, 0x77, shuffle_column   # w
    beq  $a0, 0x73, move_down        # s
    beq  $a0, 0x70, do_pause     # p

    b    main_loop

##############################################################################
# Move left: x = x - 1
# Left inside boundary is x = 1
##############################################################################
move_left:
    lw   $t1, col_x
    li   $t2, 1
    beq  $t1, $t2, main_loop     # do nothing if already at left boundary

    lw   $a0, col_x
    addi $a0, $a0, -1
    jal  check_horizontal_collision
    bne  $v0, $zero, main_loop

    jal  erase_column

    lw $t1, col_x
    addi $t1, $t1, -1
    sw   $t1, col_x

    jal  draw_column
    b    main_loop

##############################################################################
# Move right: x = x + 1
# Right inside boundary is x = 12
##############################################################################
move_right:
    lw   $t1, col_x
    li   $t2, 12
    beq  $t1, $t2, main_loop     # do nothing if already at right boundary

    lw   $a0, col_x
    addi $a0, $a0, 1
    jal  check_horizontal_collision
    bne  $v0, $zero, main_loop

    jal  erase_column

    lw $t1, col_x
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
  jal check_collision
  bne $v0, $zero, move_down_lock

  jal erase_column

  lw $t1, col_y
  addi $t1, $t1, 1
  sw $t1, col_y

  jal draw_column
  b main_loop

move_down_lock:
  jal lock_column
  li  $s5, 1

resolve_loop:
  jal remove_matches
  beq $v0, $zero, resolve_done
  move $a0, $v0
  move $a1, $s5
  jal add_score
  addi $s5, $s5, 1
  jal apply_gravity
  b resolve_loop

resolve_done:
  li  $s5, 1
  jal draw_grid
  jal draw_border
  jal draw_title
  jal draw_score
  jal create_new_column
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


get_random_color:
  li $v0, 42
  li $a0, 0              # use default generator for random integer
  li $a1, 6              # set upper bound as 6, so we can choose 0-5
  syscall                # $a0 = random index

  la $t0, color_list
  sll $t1, $a0, 2
  add $t0, $t0, $t1
  lw $v0, 0($t0)

  jr $ra

# a0 = x-position , a1 = y-position

get_cell_address:       # get the index of the cell in the position (x,y)
  la $t0, grid

  li $t1, 32
  mul $t2, $a1, $t1       # y * 32
  add $t2, $t2, $a0       # y * 32 + x
  sll $t2, $t2, 2         # 4 * (y * 32 + x)

  add $v0, $t0, $t2
  jr $ra

set_cell:       # store the color from $a2 into the cell--grid(x,y)
  addi $sp, $sp, -8
  sw $ra, 4($sp)
  sw $a2, 0($sp)

  jal get_cell_address

  lw $t0, 0($sp)
  sw $t0, 0($v0)

  lw $ra, 4($sp)
  addi $sp, $sp, 8

  jr $ra


get_cell:       #return the color in $v0 for the grid(x,y)
  addi $sp, $sp, -4
  sw $ra, 0($sp)

  jal get_cell_address
  lw $v0, 0($v0)

  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra


  #####################################################################
  # draw grid

  draw_grid:
    lw $t0, ADDR_DSPL
    la $t1, grid
    li $t2, 1024

  draw_grid_loop:
    beq $t2, $zero, draw_grid_done
    lw $t3, 0($t1)
    sw $t3, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, 4
    addi $t2, $t2, -1
    b draw_grid_loop

  draw_grid_done:
    jr $ra

  ######################################################
# check collision
check_collision:
  addi $sp, $sp, -4
  sw $ra, 0($sp)

  lw $t0, col_y
  li $t1, 28
  beq $t0, $t1, check_collision_yes

  lw $a0, col_x
  addi $a1, $t0, 3              # The row number of the brick under the draw_column
  jal get_cell
  bne $v0, $zero, check_collision_yes

  move $v0, $zero
  b check_collision_done

check_collision_yes:
  li $v0, 1

check_collision_done:
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra


##################################################################
# lock column -- write the color into the column(3 cells)

lock_column:
  addi $sp, $sp, -4
  sw $ra, 0($sp)

  lw $a0, col_x
  lw $a1, col_y
  lw $a2, color_top
  jal set_cell

  lw $a0, col_x
  lw $t0, col_y
  lw $a2, color_middle
  addi $a1, $t0, 1
  jal set_cell

  lw $a0, col_x
  lw $t0, col_y
  lw $a2, color_bottom
  addi $a1, $t0, 2
  jal set_cell

  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra


#################################################################
# create new column at the color_top
create_new_column:
  addi $sp, $sp, -4
  sw $ra, 0($sp)

  li $a0, 6
  li $a1, 7
  jal get_cell
  bne $v0, $zero, spawn_game_over

  li   $t0, 6
  li   $t1, 7
  sw   $t0, col_x
  sw   $t1, col_y

  jal  get_random_color
  sw   $v0, color_top

  jal  get_random_color
  sw   $v0, color_middle

  jal  get_random_color
  sw   $v0, color_bottom

  lw   $ra, 0($sp)
  addi $sp, $sp, 4
  jr   $ra


spawn_game_over:
  lw $ra, 0($sp)
  addi $sp, $sp, 4
  b game_over_screen

game_over_screen:
  jal draw_game_over
game_over_loop:
  # Poll keyboard while staying on game over screen
  lw   $t0, ADDR_KBRD
  lw   $t8, 0($t0)
  beq  $t8, 1, game_over_input
  b    game_over_loop

game_over_input:
  lw   $a0, 4($t0)
  beq  $a0, 0x72, retry_game      # r
  b    game_over_loop

retry_game:
  jal  reset_game_state
  b    main


##########################################################
# set all the element in mark_grid as 0
clear_mark_grid:
  la $t0, mark_grid
  li $t1, 1024

clear_mark_loop:
  beq $t1, $zero, clear_mark_done
  sw $zero, 0($t0)
  addi $t0, $t0, 4
  addi $t1, $t1, -1
  b clear_mark_loop

clear_mark_done:
  jr $ra

##########################################################
# clear grid
# set all the element in grid as 0
clear_grid:
  la $t0, grid
  li $t1, 1024

clear_grid_loop:
  beq $t1, $zero, clear_grid_done
  sw $zero, 0($t0)
  addi $t0, $t0, 4
  addi $t1, $t1, -1
  b clear_grid_loop

clear_grid_done:
  jr $ra

##########################################################
# reset game state for retry
reset_game_state:
  addi $sp, $sp, -4
  sw   $ra, 0($sp)

  jal  clear_grid
  jal  clear_mark_grid

  li   $t0, 6
  li   $t1, 7
  sw   $t0, col_x
  sw   $t1, col_y

  sw   $zero, score

  lw   $ra, 0($sp)
  addi $sp, $sp, 4
  jr   $ra


############################################################
# get mark_grid address
# return v0 as the address for mark_grid[x][y]
get_mark_address:
  la $t0, mark_grid

  li $t1, 32
  mul $t2, $a1, $t1       # y * 32
  add $t2, $t2, $a0       # y * 32 + x
  sll $t2, $t2, 2         # 4 * (y * 32 + x)

  add $v0, $t0, $t2
  jr $ra

mark_cell:                  # set mark_grid[x][y] = 1
  addi $sp, $sp, -4
  sw $ra, 0($sp)

  jal get_mark_address
  li $t0,1
  sw $t0, 0($v0)

  lw $ra, 0($sp)
  addi $sp, $sp, 4
  jr $ra


############################################################
# Paused the game
do_pause:
    li   $t0, 1　#set the paused flag to 1
    sw   $t0, paused
    jal  draw_pause_screen #call draw paused screen

do_pause_clear:
    lw   $t0, ADDR_KBRD
    lw   $t1, 4($t0)

do_pause_wait:
    lw   $t0, ADDR_KBRD
    lw   $t1, 0($t0)
    beq  $t1, $zero, do_pause_wait　# if the key is 0, wait until the p key is pressed.

    lw   $t2, 4($t0)
    li   $t3, 0x70          # 'p'
    bne  $t2, $t3, do_pause_wait #if the key is not p, wait until the p key is pressed.

    sw   $zero, paused # resume

    # After resume, redraw the game situation
    jal  draw_grid
    jal  draw_border
    jal  draw_title
    jal  draw_score
    jal  draw_column

    b    main_loop


#############################################################################
# Remove mathces cell (horizontal, vertical, diagonal-right, diagonal- left)
remove_matches:
    addi $sp, $sp, -28
    sw   $ra, 24($sp)
    sw   $s0, 20($sp)      # current y
    sw   $s1, 16($sp)      # current x
    sw   $s2, 12($sp)      # current color
    sw   $s3, 8($sp)       # mark_grid
    sw   $s4, 4($sp)       # match flag
    sw   $s5, 0($sp)       # removed count

    jal  clear_mark_grid
    li   $s4, 0                 # matches-found flag
    li   $s5, 0                 # removed gems count

    # ---- Horizontal scan: y=7..30, x=1..10 ----
    li   $s0, 7
rm_horiz_y:
    li   $t0, 31
    beq  $s0, $t0, rm_vert_start
    li   $s1, 1
rm_horiz_x:
    li   $t0, 11
    beq  $s1, $t0, rm_horiz_next_y

    move $a0, $s1
    move $a1, $s0
    jal  get_cell
    move $s2, $v0
    beq  $s2, $zero, rm_horiz_next_x   #first cell

    addi $a0, $s1, 1
    move $a1, $s0
    jal  get_cell
    bne  $v0, $s2, rm_horiz_next_x     # second cell

    addi $a0, $s1, 2
    move $a1, $s0
    jal  get_cell
    bne  $v0, $s2, rm_horiz_next_x     # Third cell

    li   $s4, 1
    move $a0, $s1
    move $a1, $s0
    jal  mark_cell
    addi $a0, $s1, 1
    move $a1, $s0
    jal  mark_cell
    addi $a0, $s1, 2
    move $a1, $s0
    jal  mark_cell

rm_horiz_next_x:
    addi $s1, $s1, 1
    b    rm_horiz_x
rm_horiz_next_y:
    addi $s0, $s0, 1
    b    rm_horiz_y

    # ---- Vertical scan: y=7..28, x=1..12 ----
rm_vert_start:
    li   $s0, 7
rm_vert_y:
    li   $t0, 29
    beq  $s0, $t0, rm_diagr_start
    li   $s1, 1
rm_vert_x:
    li   $t0, 13
    beq  $s1, $t0, rm_vert_next_y

    move $a0, $s1
    move $a1, $s0
    jal  get_cell
    move $s2, $v0
    beq  $s2, $zero, rm_vert_next_x

    move $a0, $s1
    addi $a1, $s0, 1
    jal  get_cell
    bne  $v0, $s2, rm_vert_next_x

    move $a0, $s1
    addi $a1, $s0, 2
    jal  get_cell
    bne  $v0, $s2, rm_vert_next_x

    li   $s4, 1
    move $a0, $s1
    move $a1, $s0
    jal  mark_cell
    move $a0, $s1
    addi $a1, $s0, 1
    jal  mark_cell
    move $a0, $s1
    addi $a1, $s0, 2
    jal  mark_cell

rm_vert_next_x:
    addi $s1, $s1, 1
    b    rm_vert_x
rm_vert_next_y:
    addi $s0, $s0, 1
    b    rm_vert_y

    # ---- Diagonal right scan: y=7..28, x=1..10 ----
rm_diagr_start:
    li   $s0, 7
rm_diagr_y:
    li   $t0, 29
    beq  $s0, $t0, rm_diagl_start
    li   $s1, 1
rm_diagr_x:
    li   $t0, 11
    beq  $s1, $t0, rm_diagr_next_y

    move $a0, $s1
    move $a1, $s0
    jal  get_cell
    move $s2, $v0
    beq  $s2, $zero, rm_diagr_next_x

    addi $a0, $s1, 1
    addi $a1, $s0, 1
    jal  get_cell
    bne  $v0, $s2, rm_diagr_next_x

    addi $a0, $s1, 2
    addi $a1, $s0, 2
    jal  get_cell
    bne  $v0, $s2, rm_diagr_next_x

    li   $s4, 1
    move $a0, $s1
    move $a1, $s0
    jal  mark_cell
    addi $a0, $s1, 1
    addi $a1, $s0, 1
    jal  mark_cell
    addi $a0, $s1, 2
    addi $a1, $s0, 2
    jal  mark_cell

rm_diagr_next_x:
    addi $s1, $s1, 1
    b    rm_diagr_x
rm_diagr_next_y:
    addi $s0, $s0, 1
    b    rm_diagr_y

    # ---- Diagonal left scan: y=7..28, x=3..12 ----
rm_diagl_start:
    li   $s0, 7
rm_diagl_y:
    li   $t0, 29
    beq  $s0, $t0, rm_clear_start
    li   $s1, 3
rm_diagl_x:
    li   $t0, 13
    beq  $s1, $t0, rm_diagl_next_y

    move $a0, $s1
    move $a1, $s0
    jal  get_cell
    move $s2, $v0
    beq  $s2, $zero, rm_diagl_next_x

    addi $a0, $s1, -1
    addi $a1, $s0, 1
    jal  get_cell
    bne  $v0, $s2, rm_diagl_next_x

    addi $a0, $s1, -2
    addi $a1, $s0, 2
    jal  get_cell
    bne  $v0, $s2, rm_diagl_next_x

    li   $s4, 1
    move $a0, $s1
    move $a1, $s0
    jal  mark_cell
    addi $a0, $s1, -1
    addi $a1, $s0, 1
    jal  mark_cell
    addi $a0, $s1, -2
    addi $a1, $s0, 2
    jal  mark_cell

rm_diagl_next_x:
    addi $s1, $s1, 1
    b    rm_diagl_x
rm_diagl_next_y:
    addi $s0, $s0, 1
    b    rm_diagl_y

    # ---- Clear phase: set grid[y][x] = 0 wherever mark_grid == 1 ----
rm_clear_start:
    li   $s0, 7
rm_clear_y:
    li   $t0, 31
    beq  $s0, $t0, rm_done
    li   $s1, 1
rm_clear_x:
    li   $t0, 13
    beq  $s1, $t0, rm_clear_next_y

    move $a0, $s1
    move $a1, $s0
    jal  get_mark_address
    lw   $s3, 0($v0)
    beq  $s3, $zero, rm_clear_next_x

    move $a0, $s1
    move $a1, $s0
    move $a2, $zero
    jal  set_cell
    addi $s5, $s5, 1

rm_clear_next_x:
    addi $s1, $s1, 1
    b    rm_clear_x
rm_clear_next_y:
    addi $s0, $s0, 1
    b    rm_clear_y

rm_done:
    move $v0, $s5

    lw   $s5, 0($sp)
    lw   $s4, 4($sp)
    lw   $s3, 8($sp)
    lw   $s2, 12($sp)
    lw   $s1, 16($sp)
    lw   $s0, 20($sp)
    lw   $ra, 24($sp)
    addi $sp, $sp, 28
    jr   $ra

##########################################################################
# consider gravity
#   Scan from bottom (y=30) to top (y=8).
#   If grid[y][x] == 0 and grid[y-1][x] != 0, move block down.
#   Repeat passes until no block moves (stable).
#   Playfield: x = 10..21, y = 7..30
apply_gravity:
    addi $sp, $sp, -24
    sw   $ra, 20($sp)
    sw   $s0, 16($sp)
    sw   $s1, 12($sp)
    sw   $s2, 8($sp)
    sw   $s3, 4($sp)
    sw   $s4, 0($sp)

gravity_pass:
    li   $s4, 0                 # changed flag

    li   $s0, 30                # y = 30 (bottom of playfield)
gravity_y:
    li   $t0, 7
    beq  $s0, $t0, gravity_check

    li   $s1, 1                 # x = 1
gravity_x:
    li   $t0, 13
    beq  $s1, $t0, gravity_next_y

    move $a0, $s1
    move $a1, $s0
    jal  get_cell
    bne  $v0, $zero, gravity_next_x

    move $a0, $s1
    addi $a1, $s0, -1
    jal  get_cell
    beq  $v0, $zero, gravity_next_x

    move $s2, $v0
    move $a0, $s1
    move $a1, $s0
    move $a2, $s2
    jal  set_cell

    move $a0, $s1
    addi $a1, $s0, -1
    move $a2, $zero
    jal  set_cell

    li   $s4, 1

gravity_next_x:   # x++ ,search for each column
    addi $s1, $s1, 1
    b    gravity_x

gravity_next_y:    # y--  search for each row
    addi $s0, $s0, -1
    b    gravity_y

gravity_check:
    bne  $s4, $zero, gravity_pass

    lw   $s4, 0($sp)
    lw   $s3, 4($sp)
    lw   $s2, 8($sp)
    lw   $s1, 12($sp)
    lw   $s0, 16($sp)
    lw   $ra, 20($sp)
    addi $sp, $sp, 24
    jr   $ra


  ######################################################
# check collision
check_horizontal_collision:
  addi $sp, $sp, -8
  sw $ra, 0($sp)
  sw $s0, 4($sp)

  move $s0, $a0
  lw $a1, col_y
  jal get_cell
  bne $v0, $zero, horiz_col_yes

  move $a0, $s0
  lw $a1, col_y
  addi $a1, $a1, 1
  jal get_cell
  bne $v0, $zero, horiz_col_yes

  move $a0, $s0
  lw $a1, col_y
  addi $a1, $a1, 2
  jal get_cell
  bne $v0, $zero, horiz_col_yes

  move $v0, $zero
  b check_horizontal_collision_done

horiz_col_yes:
  li $v0, 1

check_horizontal_collision_done:
  lw $ra, 0($sp)
  lw $s0, 4($sp)
  addi $sp, $sp, 8
  jr $ra


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
    addi $a0, $zero, 1
    addi $a1, $zero, 6
    addi $a2, $zero, 12
    addi $a3, $zero, 1
    jal  draw_rectangle

    # Border bottom: x=10, y=31, width=12, height=1
    addi $a0, $zero, 1
    addi $a1, $zero, 31
    addi $a2, $zero, 12
    addi $a3, $zero, 1
    jal  draw_rectangle

    # Border left: x=9, y=6, width=1, height=26
    addi $a0, $zero, 0
    addi $a1, $zero, 6
    addi $a2, $zero, 1
    addi $a3, $zero, 26
    jal  draw_rectangle

    # Border right: x=22, y=6, width=1, height=26
    addi $a0, $zero, 13
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
    addi $sp, $sp, -12
    sw   $ra, 0($sp)
    sw   $a0, 4($sp)
    sw   $a1, 8($sp)

    move $t2, $a2           # width
    move $t3, $a3           # height

    li   $t4, 0             # row index = 0

rect_row_loop:
    beq  $t4, $t3, rect_done

    li   $t5, 0             # col index = 0

rect_col_loop:
    beq  $t5, $t2, next_row

    lw $t0, 4($sp)           # start x
    lw $t1, 8($sp)        # start y

    # current_x = start_x + col
    add  $t6, $t0, $t5

    # current_y = start_y + row
    add  $t7, $t1, $t4

    # addr = base + ((current_y * 32 + current_x) * 4)
    lw   $t8, ADDR_DSPL
    sll  $t0, $t7, 5        # current_y * 32
    add  $t0, $t0, $t6
    sll  $t0, $t0, 2
    add  $t8, $t8, $t0

    sw   $t9, 0($t8)

    addi $t5, $t5, 1
    b    rect_col_loop

next_row:
    addi $t4, $t4, 1
    b    rect_row_loop

rect_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 12
    jr   $ra

##############################################################################
# add_score
# score += removed_gems * 10 * chain_multiplier
# Inputs:
#   $a0 = removed_gems
#   $a1 = chain_multiplier
##############################################################################
add_score:
    blez $a0, add_score_done

    mul  $t0, $a0, $a1
    li   $t1, 10
    mul  $t0, $t0, $t1

    lw   $t2, score
    addu $t2, $t2, $t0
    sw   $t2, score

    lw   $t3, high_score
    sltu $t4, $t3, $t2
    beq  $t4, $zero, add_score_done
    sw   $t2, high_score

add_score_done:
    jr   $ra

##############################################################################
# draw_score
# Draw right-side score panel:
#   Row 1: PTS label + current score number
#   Row 2: HI  label + high score number
##############################################################################
draw_score:
    addi $sp, $sp, -8
    sw   $ra, 4($sp)
    sw   $s0, 0($sp)

    # clear entire score panel area
    lw   $t9, score_bg_color
    li   $a0, 15
    li   $a1, 8
    li   $a2, 17
    li   $a3, 24
    jal  draw_rectangle

    lw   $t9, score_fg_color

    # --- Row 1: PTS ---
    li   $a0, 15
    li   $a1, 8
    jal  draw_letter_p

    li   $a0, 19
    li   $a1, 8
    jal  draw_letter_t

    li   $a0, 23
    li   $a1, 8
    jal  draw_letter_s

    # current score number below PTS
    lw   $a0, score
    li   $a1, 15
    li   $a2, 14
    jal  draw_number

    # --- Row 2: HI ---
    li   $a0, 15
    li   $a1, 20
    jal  draw_letter_h

    li   $a0, 19
    li   $a1, 20
    jal  draw_letter_i

    # high score number below HI
    lw   $a0, high_score
    li   $a1, 15
    li   $a2, 26
    jal  draw_number

    lw   $s0, 0($sp)
    lw   $ra, 4($sp)
    addi $sp, $sp, 8
    jr   $ra

##############################################################################
# draw_letter_p (3x5)
##############################################################################
draw_letter_p:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    # left stem
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    # top bar
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    # right upper stem
    lw   $a0, 4($sp)
    addi $a0, $a0, 2
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 2
    jal  draw_rectangle

    # middle bar
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 2
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

##############################################################################
# draw_letter_t (3x5)
##############################################################################
draw_letter_t:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    # top bar
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    # center stem
    lw   $a0, 4($sp)
    addi $a0, $a0, 1
    lw   $a1, 0($sp)
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 4
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

##############################################################################
# draw_letter_s (3x5)
##############################################################################
draw_letter_s:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    # top
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    # upper-left
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    # middle
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 2
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    # lower-right
    lw   $a0, 4($sp)
    addi $a0, $a0, 2
    lw   $a1, 0($sp)
    addi $a1, $a1, 3
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    # bottom
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 4
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

##############################################################################
# draw_letter_e (3x5)
##############################################################################
draw_letter_e:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    # left stem
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    # top bar
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    # middle bar
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 2
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    # bottom bar
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 4
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

##############################################################################
# draw_letter_r (3x5)
##############################################################################
draw_letter_r:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    # left stem
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    # top bar
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    # right upper stem
    lw   $a0, 4($sp)
    addi $a0, $a0, 2
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 2
    jal  draw_rectangle

    # middle bar
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 2
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    # right lower leg
    lw   $a0, 4($sp)
    addi $a0, $a0, 2
    lw   $a1, 0($sp)
    addi $a1, $a1, 3
    li   $a2, 1
    li   $a3, 2
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

##############################################################################
# draw_letter_h (3x5)
##############################################################################
draw_letter_h:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    # left stem
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    # right stem
    lw   $a0, 4($sp)
    addi $a0, $a0, 2
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    # middle bar
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 2
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

##############################################################################
# draw_letter_i (3x5)
##############################################################################
draw_letter_i:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    # top bar
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    # center stem
    lw   $a0, 4($sp)
    addi $a0, $a0, 1
    lw   $a1, 0($sp)
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 3
    jal  draw_rectangle

    # bottom bar
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 4
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

##############################################################################
# draw_digit
# Inputs:
#   $a0 = digit (0..9)
#   $a1 = x
#   $a2 = y
##############################################################################
draw_digit:
    li   $t0, 10
    sltu $t1, $a0, $t0
    beq  $t1, $zero, draw_digit_done

    la   $t2, digit_font_3x5
    li   $t3, 20              # 5 rows * 4 bytes
    mul  $t4, $a0, $t3
    addu $t2, $t2, $t4

    li   $t5, 0               # row
draw_digit_row_loop:
    li   $t0, 5
    beq  $t5, $t0, draw_digit_done

    sll  $t6, $t5, 2
    addu $t7, $t2, $t6
    lw   $t8, 0($t7)

    li   $t0, 0               # col
draw_digit_col_loop:
    li   $t1, 3
    beq  $t0, $t1, draw_digit_next_row

    li   $t1, 2
    subu $t1, $t1, $t0
    li   $t3, 1
    sllv $t3, $t3, $t1
    and  $t4, $t8, $t3
    beq  $t4, $zero, draw_digit_next_col

    addu $t6, $a1, $t0
    addu $t7, $a2, $t5
    lw   $t9, score_fg_color
    lw   $t1, ADDR_DSPL
    sll  $t3, $t7, 5
    addu $t3, $t3, $t6
    sll  $t3, $t3, 2
    addu $t1, $t1, $t3
    sw   $t9, 0($t1)

draw_digit_next_col:
    addi $t0, $t0, 1
    b    draw_digit_col_loop

draw_digit_next_row:
    addi $t5, $t5, 1
    b    draw_digit_row_loop

draw_digit_done:
    jr   $ra

##############################################################################
# draw_number
# Inputs:
#   $a0 = number
#   $a1 = x
#   $a2 = y
##############################################################################
draw_number:
    addi $sp, $sp, -80
    sw   $ra, 76($sp)
    sw   $s0, 72($sp)
    sw   $s1, 68($sp)
    sw   $s2, 64($sp)
    sw   $s3, 60($sp)
    sw   $s4, 56($sp)
    sw   $s5, 52($sp)

    move $s0, $a0             # number
    move $s1, $a1             # x
    move $s2, $a2             # y
    li   $s3, 0               # digit count

    bne  $s0, $zero, draw_number_extract
    sw   $zero, 0($sp)
    li   $s3, 1
    b    draw_number_draw_setup

draw_number_extract:
    li   $t7, 10
draw_number_extract_loop:
    beq  $s0, $zero, draw_number_draw_setup
    divu $s0, $t7
    mfhi $t0
    mflo $s0

    sll  $t1, $s3, 2
    addu $t2, $sp, $t1
    sw   $t0, 0($t2)
    addi $s3, $s3, 1
    b    draw_number_extract_loop

draw_number_draw_setup:
    addi $s4, $s3, -1         # index (highest stored digit)
    move $s5, $s1             # current x

draw_number_draw_loop:
    bltz $s4, draw_number_done

    sll  $t1, $s4, 2
    addu $t2, $sp, $t1
    lw   $a0, 0($t2)
    move $a1, $s5
    move $a2, $s2
    jal  draw_digit

    addi $s5, $s5, 4          # 3 pixels + 1 space
    addi $s4, $s4, -1
    b    draw_number_draw_loop

draw_number_done:
    lw   $s5, 52($sp)
    lw   $s4, 56($sp)
    lw   $s3, 60($sp)
    lw   $s2, 64($sp)
    lw   $s1, 68($sp)
    lw   $s0, 72($sp)
    lw   $ra, 76($sp)
    addi $sp, $sp, 80
    jr   $ra

##############################################################################
# draw_title
# Draw "column" above the top border using the six existing colors in color_list
##############################################################################
draw_title:
    addi $sp, $sp, -8
    sw   $ra, 4($sp)
    sw   $s0, 0($sp)

    la   $s0, color_list

    lw   $t9, 0($s0)
    li   $a0, 4
    li   $a1, 0
    jal  draw_letter_c

    lw   $t9, 4($s0)
    li   $a0, 8
    li   $a1, 0
    jal  draw_letter_o

    lw   $t9, 8($s0)
    li   $a0, 12
    li   $a1, 0
    jal  draw_letter_l

    lw   $t9, 12($s0)
    li   $a0, 16
    li   $a1, 0
    jal  draw_letter_u

    lw   $t9, 16($s0)
    li   $a0, 20
    li   $a1, 0
    jal  draw_letter_m

    lw   $t9, 20($s0)
    li   $a0, 26
    li   $a1, 0
    jal  draw_letter_n

    lw   $s0, 0($sp)
    lw   $ra, 4($sp)
    addi $sp, $sp, 8
    jr   $ra

##############################################################################
# 3x5 title letters
# Inputs:
#   $a0 = start x
#   $a1 = start y
#   $t9 = color
##############################################################################
draw_letter_c:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 4
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter_o:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 4
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    lw   $a0, 4($sp)
    addi $a0, $a0, 2
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter_l:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 4
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter_u:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    lw   $a0, 4($sp)
    addi $a0, $a0, 2
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 4
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter_m:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    lw   $a0, 4($sp)
    addi $a0, $a0, 4
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    lw   $a0, 4($sp)
    addi $a0, $a0, 1
    lw   $a1, 0($sp)
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    addi $a0, $a0, 2
    lw   $a1, 0($sp)
    addi $a1, $a1, 2
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    addi $a0, $a0, 3
    lw   $a1, 0($sp)
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter_n:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    lw   $a0, 4($sp)
    addi $a0, $a0, 3
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    lw   $a0, 4($sp)
    addi $a0, $a0, 1
    lw   $a1, 0($sp)
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    addi $a0, $a0, 2
    lw   $a1, 0($sp)
    addi $a1, $a1, 2
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

##############################################################################
# draw_game_over
# Clear screen and draw "GAME OVER"
##############################################################################
draw_game_over:
    addi $sp, $sp, -8
    sw   $ra, 4($sp)
    sw   $s0, 0($sp)

    # Clear whole bitmap to black
    li   $t9, 0x000000
    li   $a0, 0
    li   $a1, 0
    li   $a2, 32
    li   $a3, 32
    jal  draw_rectangle

    # Draw GAME (row 1) using 7x7 glyphs
    li   $t9, 0xFFFFFF
    li   $a0, 0
    li   $a1, 7
    jal  draw_letter7_g

    li   $a0, 8
    li   $a1, 7
    jal  draw_letter7_a

    li   $a0, 16
    li   $a1, 7
    jal  draw_letter7_m

    li   $a0, 24
    li   $a1, 7
    jal  draw_letter7_e

    # Draw OVER (row 2) using 7x7 glyphs
    li   $a0, 0
    li   $a1, 18
    jal  draw_letter7_o

    li   $a0, 8
    li   $a1, 18
    jal  draw_letter7_v

    li   $a0, 16
    li   $a1, 18
    jal  draw_letter7_e

    li   $a0, 24
    li   $a1, 18
    jal  draw_letter7_r

    lw   $s0, 0($sp)
    lw   $ra, 4($sp)
    addi $sp, $sp, 8
    jr   $ra

##############################################################################
# 7x7 game over letters
##############################################################################
draw_letter7_g:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 1
    li   $a2, 5
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 1
    addi $a1, $a1, 6
    li   $a2, 5
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 6
    addi $a1, $a1, 3
    li   $a2, 1
    li   $a3, 3
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 3
    addi $a1, $a1, 3
    li   $a2, 4
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter7_a:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 1
    li   $a2, 5
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 6
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 6
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 6
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 1
    addi $a1, $a1, 3
    li   $a2, 5
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter7_m:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 7
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 6
    li   $a2, 1
    li   $a3, 7
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 1
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 2
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 2
    addi $a1, $a1, 2
    li   $a2, 1
    li   $a3, 2
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 3
    addi $a1, $a1, 3
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 4
    addi $a1, $a1, 2
    li   $a2, 1
    li   $a3, 2
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 5
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 2
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter7_e:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 7
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 1
    li   $a2, 6
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 1
    addi $a1, $a1, 3
    li   $a2, 5
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 1
    addi $a1, $a1, 6
    li   $a2, 6
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter7_o:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 1
    li   $a2, 5
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 1
    addi $a1, $a1, 6
    li   $a2, 5
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 6
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter7_v:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 4
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 6
    li   $a2, 1
    li   $a3, 4
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 1
    addi $a1, $a1, 4
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 5
    addi $a1, $a1, 4
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 2
    addi $a1, $a1, 5
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 4
    addi $a1, $a1, 5
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 3
    addi $a1, $a1, 6
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

draw_letter7_r:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 7
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 1
    li   $a2, 5
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 1
    addi $a1, $a1, 3
    li   $a2, 5
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 6
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 2
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 3
    addi $a1, $a1, 4
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 4
    addi $a1, $a1, 5
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a0, $a0, 5
    addi $a1, $a1, 6
    li   $a2, 1
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra


##############################################################################
# Draw paused screen
##############################################################################
draw_pause_screen:
    addi $sp, $sp, -8　#Allocate 8 bytes on the stack to store saved registers.
    sw   $ra, 4($sp) #Save the return address ($ra) onto the stack.
    sw   $s0, 0($sp) #Save the callee-saved register ($s0) onto the stack.

    # Clear the background with black
    li   $t9, 0x000000
    li   $a0, 0
    li   $a1, 0
    li   $a2, 32
    li   $a3, 32
    jal  draw_rectangle

    # Set the color to white
    li   $t9, 0xFFFFFF

    # Display「PAUSED」 (y=13)
    # P
    li   $a0, 4
    li   $a1, 13
    jal  draw_letter_p

    # A
    li   $a0, 8
    li   $a1, 13
    jal  draw_letter_a

    # U
    li   $a0, 12
    li   $a1, 13
    jal  draw_letter_u

    # S
    li   $a0, 16
    li   $a1, 13
    jal  draw_letter_s

    # E
    li   $a0, 20
    li   $a1, 13
    jal  draw_letter_e

    # D
    li   $a0, 24
    li   $a1, 13
    jal  draw_letter_d

    lw   $s0, 0($sp) #Restore the original value of $s0 from the stack.
    lw   $ra, 4($sp) #Restore the return address ($ra) from the stack.
    addi $sp, $sp, 8 #Deallocate the stack space and restore the stack pointer.
    jr   $ra #Return to the caller using the restored return address.



##############################################################################
# draw_letter_a (3x5)
##############################################################################
draw_letter_a:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    # top bar
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    # left stem
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 4
    jal  draw_rectangle

    # right stem
    lw   $a0, 4($sp)
    addi $a0, $a0, 2
    lw   $a1, 0($sp)
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 4
    jal  draw_rectangle

    # middle bar
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    addi $a1, $a1, 2
    li   $a2, 3
    li   $a3, 1
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra


##############################################################################
# draw_letter_d (3x5)
##############################################################################
draw_letter_d:
    addi $sp, $sp, -12
    sw   $ra, 8($sp)
    sw   $a0, 4($sp)
    sw   $a1, 0($sp)

    # left stem
    lw   $a0, 4($sp)
    lw   $a1, 0($sp)
    li   $a2, 1
    li   $a3, 5
    jal  draw_rectangle

    # top bar
    lw   $a0, 4($sp)
    addi $a0, $a0, 1
    lw   $a1, 0($sp)
    li   $a2, 2
    li   $a3, 1
    jal  draw_rectangle

    # bottom bar
    lw   $a0, 4($sp)
    addi $a0, $a0, 1
    lw   $a1, 0($sp)
    addi $a1, $a1, 4
    li   $a2, 2
    li   $a3, 1
    jal  draw_rectangle

    # right stem
    lw   $a0, 4($sp)
    addi $a0, $a0, 2
    lw   $a1, 0($sp)
    addi $a1, $a1, 1
    li   $a2, 1
    li   $a3, 3
    jal  draw_rectangle

    lw   $ra, 8($sp)
    addi $sp, $sp, 12
    jr   $ra

##############################################################################
# Quit
##############################################################################
respond_to_Q:
    li   $v0, 10
    syscall
    // final version