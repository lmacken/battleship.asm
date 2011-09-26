# File:         $Id$
# Author:       Luke Macken (lewk@csh.rit.edu)
#               Fotios Lindiakos (fotios@csh.rit.edu)
# Contributors: M. Reek 
#
# Description:  A game to play a very simplified version of "Battleship"
#
# Revisions:    $Log$

# USEFUL CONSTANTS

TRUE = 1
FALSE = 0
MAX = 5
MAX_SIZE = 25
MAX_SHIPS = 2
MAX_GUESSES = 10

GOT_HIT = -1
PIRATE = 'p'
DUCKY = 'd'
PIRATE_SIZE = 40
DUCKY_SIZE = 28

# offsets into Game structure
SHIP1 = 0
SHIP2 = 4
GUESSES = 8

# offsets & other constants for ship data structures
TYPE = 0
LENGTH = 1
ROW = 4;
COLUMN = 8
HIT = 12
HOLE_SIZE = 12

# syscall codes
PRINT_INT       = 1
PRINT_STRING    = 4
READ_INT        = 5
READ_STRING     = 8

.data

row_prompt:
    .asciiz "row ? "
column_prompt:
    .asciiz "column ? "
already_guessed:
    .asciiz "You already guessed that, try again\n"
you_missed: 
    .asciiz "You missed\n"
you_lose:
    .asciiz "Out of guesses -- too bad, you lose!\n"
you_win:
    .asciiz "You sank my fleet - you win!\n"
ducky_hit:
    .asciiz "You hit my rubber ducky!\n"
pirate_hit:
    .asciiz "You hit my pirate ship!\n"
ducky_sank:
    .asciiz "You sank my rubber ducky!\n"
pirate_sank:
    .asciiz "You sank my pirate ship!\n"
next_game:
    .asciiz "Ready for another game? (y or n)\n"

# game specific data structures
# use to keep track of whether this location has been guess already
guessed:
    .space  MAX_SIZE

    # these are the data structures that will be passed to play_game
game1:
    .word   ships1
    .word   ships1  # need to add PIRATE_SIZE to this at run time 
    .word   guessed
game2:
    .word   ships2
    .word   ships2 # need to add DUCKY_SIZE to this at run time 
    .word   guessed

    # your code should never access these directly - you'll find them
    # via the game structure
ships1:
    .byte   PIRATE, 3       # type of ship, length of ship
    .byte   0,0             # for alignment
    .word   1,1,FALSE       # row, column, hit=FALSE
    .word   1,2,FALSE       # row, column, hit=FALSE
    .word   1,3,FALSE       # row, column, hit=FALSE

    .byte   DUCKY, 2        # type of ship, length of ship
    .byte   0,0             # for alignment
    .word   3,0,FALSE       # row, column, hit=FALSE
    .word   4,0,FALSE       # row, column, hit=FALSE
ships2:
    .byte   DUCKY,2
    .byte   0,0 # for alignment
    .word   0,2,FALSE
    .word   0,3,FALSE

    .byte   PIRATE, 3
    .byte   0,0 # for alignment
    .word   4,4,FALSE
    .word   3,4,FALSE
    .word   2,4,FALSE

buffer: .space 10
    .text

play_game:

    addi    $sp,$sp,-40      # allocate stack frame (on doubleword boundary)
    sw      $ra, 32($sp)    # store the ra & s reg's on the stack
    sw      $s7, 28($sp)
    sw      $s6, 24($sp)
    sw      $s5, 20($sp)
    sw      $s4, 16($sp)
    sw      $s3, 12($sp)
    sw      $s2, 8($sp)
    sw      $s1, 4($sp)
    sw      $s0, 0($sp)

    move    $s0, $a0        # save the game address 

    li  $t7, MAX_SHIPS      # number of ships not sank

    ##
    # initialize the game matrix
    ##
    lw  $t0, GUESSES($a0)   # load the guess grid address
    add $t1, $t0, MAX_SIZE  # load the last address
    li  $t2, FALSE      # set the values to FALSE

init_loop:
    beq $t0, $t1, done_init 
    sb  $t2, 0($t0)     # store FALSE in the grid spot
    addi    $t0, $t0, 1     # increment the grid spot
    j   init_loop
done_init:
    move    $s1, $zero      # zero out guesses taken
check_num_guesses:
    li  $t0, MAX_GUESSES
    beq $s1, $t0, out_of_guesses

prompt:
    ##
    # Get row and col data
    ##
    la  $a0, row_prompt
    li  $v0, PRINT_STRING
    syscall
    li  $v0, READ_INT
    syscall
    move    $s2, $v0

    la  $a0, column_prompt
    li  $v0, PRINT_STRING
    syscall
    li  $v0, READ_INT
    syscall
    move    $s3, $v0

    ##
    # Check state of guess grid
    ##
    li  $t0, 5          # load 5 into t0
    mult    $s2, $t0        # multiply row by 5
    mflo    $t0         # get answer into t0
    add $t0, $t0, $s3       # add col to get index
    lw  $t1, GUESSES($s0)   # create pointer to start of grid
    add $t1, $t1, $t0       # move the pointer
    lb  $t0, 0($t1)     # load state into t0
    move    $s4, $t1        # save the address of the cur guess
    bnez    $t0, dupe_guess     # if the number was already guessed

    lw  $s5, SHIP1($s0)     # give it the first ship
    move    $s7, $zero      # zero out ships counter
    jal check_hit

    addi    $s1, $s1, 1     # increment shots taken
    j   check_num_guesses

check_hit:
    li  $t0, MAX_SHIPS
    beq $s7, $t0, not_hit   # done if its the max 

    move    $a0, $s5        # save the addr of boat
    move    $s6, $zero      # create a counter of holes

checking_loop:
    lb  $t1, LENGTH($s5)    # get length of structure
    beq $t1, $s6, done_checking_loop
    addi    $s6, $s6, 1     # increment counter

    ##
    # Check row
    ##
    lw  $t1, ROW($a0)       # load row offset from spot
    bne $s2, $t1, miss      

    ##
    # Check col
    ##
    lw  $t1, COLUMN($a0)    # load col offset from spot
    bne $s3, $t1, miss

    ##
    # At this point it is a hit
    ##
    li  $t1, TRUE       # load the TRUE flag into t1
    sw  $t1, HIT($a0)       # store it in the hit word of ship
    lb  $t1, TYPE($s5)      # load type into t1
    sb  $t1, 0($s4)     # store the ship type in the matrix

    # print which ship is hit
    li  $t2, DUCKY
    beq $t2, $t1, hit_ducky
    li  $t2, PIRATE
    beq $t2, $t1, hit_pirate

hit_ducky:
    la  $a0, ducky_hit
    j   print_hit
hit_pirate:
    la  $a0, pirate_hit
print_hit:
    li  $v0, PRINT_STRING
    syscall
    j   is_sunk
    jr  $ra

miss:
    addi    $a0, $a0, HOLE_SIZE # move to the next hole
    j   checking_loop

done_checking_loop:
    move    $t3, $s0
    addi    $t3, $t3, 4     # move to the next ship
    lw  $s5, 0($t3)     # load the addr of next ship
    addi    $s7, $s7, 1     # increment ships counter
    j   check_hit

not_hit:
    # update grid with NOT_HIT then print and j $ra
    li  $t1, GOT_HIT
    sb  $t1, 0($s4)

    la  $a0, you_missed
    li  $v0, PRINT_STRING
    syscall

    jr  $ra

is_sunk:
    lb  $t1, LENGTH($s5)    # length of current ship
    move    $t2, $s5        # make a temp copy of the address
sunk_loop:
    beq $t1, $zero, sunk    # if number of holes left to check is 0
    addi    $t1, $t1, -1        # decrement
    li  $t3, HOLE_SIZE
    add $t2, $t2, $t3
    lw  $t5, 0($t2)     # load the value of the HIT
    li  $t4, TRUE       # load TRUE
    beq $t4, $t5, sunk_loop
    jr  $ra
sunk:
    lb  $t3, TYPE($s5)      # get the type of the ship
    li  $t2, DUCKY
    beq $t2, $t3, sunk_ducky    # if the ducky was sank
    li  $t2, PIRATE
    beq $t2, $t3, sunk_pirate   # if the pirate was sank

sunk_ducky:
    la  $a0, ducky_sank
    j   print_sunk
sunk_pirate:
    la  $a0, pirate_sank
print_sunk:
    li  $v0, PRINT_STRING
    syscall

    addi    $t7, $t7, -1            # decrement number of ships
    beq $t7, $zero, done_game_win

    jr  $ra

dupe_guess:
    la  $a0, already_guessed
    li  $v0, PRINT_STRING
    syscall
    j   prompt

done_game_win:
    la  $a0, you_win
    li  $v0, PRINT_STRING
    syscall
    j   done_play_game

out_of_guesses:
    la  $a0, you_lose
    li  $v0, PRINT_STRING
    syscall

done_play_game:

        lw      $ra, 32($sp)    # restore the ra & s reg's from the stack
        lw      $s7, 28($sp)
        lw      $s6, 24($sp)
        lw      $s5, 20($sp)
        lw      $s4, 16($sp)
        lw      $s3, 12($sp)
        lw      $s2, 8($sp)
        lw      $s1, 4($sp)
        lw      $s0, 0($sp)
        addi    $sp,$sp,40      # clean up stack
        jr      $ra

FS_M = 8
main:
    sub $sp, $sp, FS_M
    sw  $ra, -4+FS_M($sp)

    # fiddle with addresses in structure because the stupid assembler
    # can't handle arithmetic with .word 

    li  $t0, PIRATE_SIZE
    la  $t1, game1
    lw  $t2, 4($t1)
    add $t2, $t2, $t0
    sw  $t2, 4($t1)

    li  $t0, DUCKY_SIZE
    la  $t1, game2
    lw  $t2, 4($t1)
    add $t2, $t2, $t0
    sw  $t2, 4($t1)

    # now let's get rolling and play the game!  
    # pass address of first game structure in a0

    la  $a0, game1
    jal play_game

    # ask if they want to play again
    la  $a0, next_game
    li  $v0, PRINT_STRING
    syscall

    # read the answer
    li  $v0, READ_STRING
    la  $a0, buffer
    li  $a1, 3
    syscall

    # see if it is yes
    li  $t0, 'y'
    lb  $t1, buffer
    bne $t0, $t1, done_main

    # they want to play again, so load up new game into a0
    la  $a0, game2
    jal play_game

done_main:
    # all done!

    lw  $ra, -4+FS_M($sp)
    add $sp, $sp, FS_M

    jr  $ra
