#########################
# File: spimbot.s       #
#                       #
# Author: Andrew Mass   #
# Date:   2014-04-30    #
#                       #
# "The distance between #
# insanity and genius   #
# is measured only by   #
# success."             #
# -Bruce Feirstein      #
#########################

########################
# Constants and Memory #
########################

.data

# Spimbot constants
NUM_FLAGS          = 40                # Maximum flags on the board
BASE_RADIUS        = 24                # Base radius
MAX_FLAGS          = 5                 # Maximum flags in hand
FLAG_COST          = 7                 # Energy cost to generate a flag
INVIS_COST         = 25                # Energy cost to go invisible
BE_T               = 150 - BASE_RADIUS # Top edge of the base
BE_B               = 150 + BASE_RADIUS # Bottom edge of the base

# Memory-mapped I/O
VELOCITY           = 0xffff0010
ANGLE              = 0xffff0014
ANGLE_CONTROL      = 0xffff0018
BOT_X              = 0xffff0020
BOT_Y              = 0xffff0024
FLAG_REQUEST       = 0xffff0050
PICK_FLAG          = 0xffff0054
FLAGS_IN_HAND      = 0xffff0058
GENERATE_FLAG      = 0xffff005c
ENERGY             = 0xffff0074
ACTIVATE_INVIS     = 0xffff0078
PRINT_INT          = 0xffff0080
PRINT_FLOAT        = 0xffff0084
PRINT_HEX          = 0xffff0088
SUDOKU_REQUEST     = 0xffff0090
SUDOKU_SOLVED      = 0xffff0094
OTHER_BOT_X        = 0xffff00a0
OTHER_BOT_Y        = 0xffff00a4
COORDS_REQUEST     = 0xffff00a8
SCORE              = 0xffff00b0
ENEMY_SCORE        = 0xffff00b4

# Interrupt memory-mapped I/O
TIMER              = 0xffff001c
BONK_ACKNOWLEDGE   = 0xffff0060
COORDS_ACKNOWLEDGE = 0xffff0064
TIMER_ACKNOWLEDGE  = 0xffff006c
TAG_ACKNOWLEDGE    = 0xffff0070
INVIS_ACKNOWLEDGE  = 0xffff007c

# Interrupt masks
TAG_MASK           = 0x400
INVIS_MASK         = 0x800
BONK_MASK          = 0x1000
COORDS_MASK        = 0x2000
TIMER_MASK         = 0x8000

# Syscall constants
SYS_PRINT_INT      = 1
SYS_PRINT_STRING   = 4
SYS_PRINT_CHAR     = 11

# Frequency constants
TIMER_FREQ         = 2000

# Float constants
three:             .float 3.0
five:              .float 5.0
pi:                .float 3.14159265
f180:              .float 180.0

# Data member storage
target_x:          .word 0
target_y:          .word 0

# Sudoku board memory
sudoku:            .space 512
flags:             .space NUM_FLAGS * 2 * 4

#############
# Main Loop #
#############

.text

main:
  li     $t0, TIMER_MASK
  or     $t0, $t0, BONK_MASK
  or     $t0, $t0, 1
  mtc0   $t0, $12                      # Enable timer and bonk interrupts

  li     $t0, 10
  sw     $t0, VELOCITY                 # SET_VELCOITY(10)

  lw     $t0, TIMER
  add    $t0, $t0, TIMER_FREQ
  sw     $t0, TIMER                    # REQUEST_TIMER(TIMER() + 10)

  la     $t0, sudoku
  sw     $t0, SUDOKU_REQUEST           # Request new soduku puzzle

  la     $t0, flags
  sw     $t0, FLAG_REQUEST             # FLAG_REQUEST(&flags)

  lw     $t0, flags($0)
  sw     $t0, target_x
  lw     $t1, flags+4($0)
  sw     $t1, target_y                 # target = flags[0]

infinite:
  la     $a0, sudoku
  jal    sudoku_r1                     # Run rule1 algorithm
  bnez   $v0, infinite                 # Repeat rule1 if changes were made

  la     $t0, sudoku
  sw     $t0, SUDOKU_SOLVED            # Report solved sudoku

  la     $t0, sudoku
  sw     $t0, SUDOKU_REQUEST           # Request new soduku puzzle

  j      infinite                      # Jump to top of loop

#####################
# Interrupt Handler #
#####################

.kdata

chunkIH:           .space    12
non_intrpt_str:    .asciiz   "Non-interrupt exception\n"
unhandled_str:     .asciiz   "Unhandled interrupt type\n"

.ktext 0x80000180

interrupt_handler:
.set noat
  move   $k1, $at                      # Save $at
.set at
  la     $k0, chunkIH
  sw     $a0, 0($k0)                  # Save $a0
  sw     $a1, 4($k0)                  # Save $a1
  sw     $v0, 8($k0)                  # Save $v0

  mfc0   $k0, $13                      # Get interrupt cause register
  srl    $a0, $k0, 2
  and    $a0, $a0, 0xf                 # Mask with ExcCode field
  bnez   $a0, non_interrupt            # Non-interrupt

interrupt_dispatch:
  mfc0   $k0, $13                      # Get interrupt cause register
  beqz   $k0, id_done                  # Handled all interrupts

  and    $a0, $k0, BONK_MASK
  bnez   $a0, interrupt_bonk           # Handle bonk interrupt

  and    $a0, $k0, TIMER_MASK
  bnez   $a0, interrupt_timer          # Handle timer interrupt

  li     $v0, SYS_PRINT_STRING
  la     $a0, unhandled_str
  syscall                              # Print unhandled interrupt message

  j      id_done                       # Finish interrupt handler

interrupt_bonk:
  sw     $0, BONK_ACKNOWLEDGE          # Acknowledge bonk interrupt

  li     $v0, 135
  sw     $v0, ANGLE
  sw     $0, ANGLE_CONTROL             # Turn 135 degrees

  li     $v0, 10
  sw     $v0, VELOCITY                 # SET_VELOCITY(10)

  j      interrupt_dispatch

interrupt_timer:
  sw     $0, TIMER_ACKNOWLEDGE         # Acknowledge timer interrupt

  lw     $a0, FLAGS_IN_HAND
  sw     $0, PICK_FLAG
  lw     $a1, FLAGS_IN_HAND
  ble    $a1, $a0, it_skip_target

  la     $a0, flags
  sw     $a0, FLAG_REQUEST
  lw     $a0, flags($0)
  sw     $a0, target_x
  lw     $a1, flags+4($0)
  sw     $a1, target_y

it_skip_target:
  lw     $a0, BOT_X
  bge    $a0, BASE_RADIUS, it_skip_base # Skip if right of base

  lw     $a0, BOT_Y
  bge    $a0, BE_B, it_skip_base       # Skip if below base
  ble    $a0, BE_T, it_skip_base       # Skip if above base

  li     $a0, 180
  sw     $a0, ANGLE
  sw     $0, ANGLE_CONTROL             # Turn around

it_skip_base:
  lw     $a0, TIMER
  add    $a0, $a0, TIMER_FREQ
  sw     $a0, TIMER                    # REQUEST_TIMER(TIMER() + TIMER_FREQ)

  j      interrupt_dispatch            # Handle further interrupts

non_interrupt:
  li     $v0, SYS_PRINT_STRING
  la     $a0, non_intrpt_str
  syscall                              # Print non-interrupt error message

id_done:
  la     $k0, chunkIH
  lw     $a0, 0($k0)                   # Restore $a0
  lw     $a1, 4($k0)                   # Restore $a1
  lw     $v0, 8($k0)                   # Restore $v0
.set noat
  move   $at, $k1                      # Restore $at
.set at
  eret                                 # Return

####################
# Helper Functions #
####################

### int euclidean_dist(int x, int y);
### Returns sqrt(x^2 + y^2)
euclidean_dist:
  mul    $a0, $a0, $a0                 # x^2
  mul    $a1, $a1, $a1                 # y^2
  add    $v0, $a0, $a1                 # x^2 + y^2
  mtc1   $v0, $f0
  cvt.s.w $f0, $f0                     # float(x^2 + y^2)
  sqrt.s $f0, $f0                      # sqrt(x^2 + y^2)
  cvt.w.s $f0, $f0                     # int(sqrt(...))
  mfc1   $v0, $f0
  jr     $ra

### int arctan(int x, int y);
### Returns arctan(y / x)
sb_arctan:
  li     $v0, 0                        # angle = 0;

  abs    $t0, $a0                      # get absolute values
  abs    $t1, $a1
  ble    $t1, $t0, no_TURN_90          # Branch if(abs(y) < abs(x))

  move   $t0, $a1                      # int temp = y;
  neg    $a1, $a0                      # y = -x;
  move   $a0, $t0                      # x = temp;
  li     $v0, 90                       # angle = 90;

no_TURN_90:
  bgez   $a0, pos_x                    # skip if (x >= 0)

  add    $v0, $v0, 180                 # angle += 180;

pos_x:
  mtc1   $a0, $f0
  mtc1   $a1, $f1
  cvt.s.w $f0, $f0                     # convert from ints to floats
  cvt.s.w $f1, $f1

  div.s  $f0, $f1, $f0                 # float v = (float) y / (float) x;

  mul.s  $f1, $f0, $f0                 # v^^2
  mul.s  $f2, $f1, $f0                 # v^^3
  l.s    $f3, three                    # load 5.0
  div.s  $f3, $f2, $f3                 # v^^3/3
  sub.s  $f6, $f0, $f3                 # v - v^^3/3

  mul.s  $f4, $f1, $f2                 # v^^5
  l.s    $f5, five                     # load 3.0
  div.s  $f5, $f4, $f5                 # v^^5/5
  add.s  $f6, $f6, $f5                 # value = v - v^^3/3 + v^^5/5

  l.s    $f8, pi                       # load PI
  div.s  $f6, $f6, $f8                 # value / PI
  l.s    $f7, f180                     # load 180.0
  mul.s  $f6, $f6, $f7                 # 180.0 * value / PI

  cvt.w.s $f6, $f6                     # convert "delta" back to integer
  mfc1   $t0, $f6
  add    $v0, $v0, $t0                 # angle += delta

  jr     $ra

#################
# Sudoku Solver #
#################

.text

sudoku_r1:
  sub    $sp, $sp, 32                  # Allocate stack memory
  sw     $s0, 0($sp)                   # Save $s0
  sw     $s1, 4($sp)                   # Save $s1
  sw     $s2, 8($sp)                   # Save $s2
  sw     $s3, 12($sp)                  # Save $s3
  sw     $s4, 16($sp)                  # Save $s4
  sw     $s5, 20($sp)                  # Save $s5
  sw     $s6, 24($sp)                  # Save $s6
  sw     $ra, 28($sp)                  # Save $ra
  li     $s0, 0                        # bool changed = false
  li     $s1, 0                        # int i = 0
  move   $s3, $a0                      # &board

s_r1_oloop:
  bge    $s1, 16, s_r1_oloop_e         # Exit outer loop if(i >= 4 * 4)
  li     $s2, 0                        # int j = 0

s_r1_iloop:
  bge    $s2, 16, s_r1_iloop_e         # Exit inner loop if(j >= 4 * 4)
  mul    $t0, $s1, 16
  add    $t0, $t0, $s2
  mul    $t0, $t0, 2
  add    $t0, $t0, $s3                 # &board[i][j]
  lhu    $s4, 0($t0)                   # unsigned value = board[i][j]
  move   $a0, $s4
  jal    s_has_single_bit_set
  beq    $v0, 0, s_r1_bit_set_skip     # Branch if(!has_single_bit_set(value))
  li     $t0, 0                        # int k = 0

s_r1_i1loop:
  bge    $t0, 16, s_r1_i1loop_e        # Exit inner k loop if(k >= 4 * 4)
  beq    $t0, $s2, s_r1_i11_skip       # Skip if(k == j)
  mul    $t1, $s1, 16
  add    $t1, $t1, $t0
  mul    $t1, $t1, 2
  add    $t1, $t1, $s3                 # &board[i][k]
  lhu    $t2, 0($t1)                   # board[i][k]
  and    $t2, $t2, $s4                 # board[i][k] & value
  beq    $t2, $0, s_r1_i11_skip        # Skip if((board[i][k] & value) == 0)
  lhu    $t2, 0($t1)                   # board[i][k]
  li     $t3, -1
  xor    $t3, $t3, $s4
  and    $t2, $t2, $t3                 # board[i][k] & ~value
  sh     $t2, 0($t1)                   # board[i][k] &= ~value
  li     $s0, 1                        # changed = true

s_r1_i11_skip:
  beq    $t0, $s1, s_r1_i12_skip       # Skip if(k == i)
  mul    $t1, $t0, 16
  add    $t1, $t1, $s2
  mul    $t1, $t1, 2
  add    $t1, $t1, $s3                 # &board[k][j]
  lhu    $t2, 0($t1)                   # board[k][j]
  and    $t2, $t2, $s4                 # board[k][j] & value
  beq    $t2, $0, s_r1_i12_skip        # Skip if((board[k][j] & value) == 0)
  lhu    $t2, 0($t1)                   # board[k][j]
  li     $t3, -1
  xor    $t3, $t3, $s4
  and    $t2, $t2, $t3                 # board[k][j] & ~value
  sh     $t2, 0($t1)                   # board[k][j] &= ~value
  li     $s0, 1                        # changed = true

s_r1_i12_skip:
  add    $t0, $t0, 1                   # k++
  j      s_r1_i1loop                   # Jump to top of k inner loop

s_r1_i1loop_e:
  move   $a0, $s1
  jal    s_get_square_begin
  move   $s5, $v0                      # int ii = get_square_begin(i);
  move   $a0, $s2
  jal    s_get_square_begin
  move   $s6, $v0                      # int jj = get_square_begin(j);
  move   $t0, $s5                      # int k = ii

s_r1_i2loop:
  add    $t2, $s5, 4
  bge    $t0, $t2, s_r1_i2loop_e       # Break loop if(k >= ii + 4)
  move   $t1, $s6                      # int l = jj

s_r1_i2iloop:
  add    $t2, $s6, 4
  bge    $t1, $t2, s_r1_i2iloop_e      # Break inner loop if(l >= jj + 4)
  xor    $t2, $t0, $s1
  xor    $t3, $t1, $s2
  bne    $t2, $0, s_r1_i21_skip        # Skip if(k != i)
  bne    $t3, $0, s_r1_i21_skip        # Skip if(l != j)
  add    $t1, $t1, 1                   # l++
  j      s_r1_i2iloop                  # Jump to top of inner l loop

s_r1_i21_skip:
  mul    $t2, $t0, 16
  add    $t2, $t2, $t1
  mul    $t2, $t2, 2
  add    $t2, $t2, $s3                 # &board[k][l]
  lhu    $t3, 0($t2)                   # board[k][l]
  and    $t3, $t3, $s4                 # board[k][l] & value
  beq    $t3, $0, s_r1_i22_skip        # Skip if((board[k][l] & value) == 0)
  lhu    $t3, 0($t2)                   # board[k][l]
  li     $t4, -1
  xor    $t4, $t4, $s4                 # ~value
  and    $t3, $t3, $t4                 # board[k][l] & ~value
  sh     $t3, 0($t2)                   # board[k][l] &= ~value
  li     $s0, 1                        # changed = true

s_r1_i22_skip:
  add    $t1, $t1, 1                   # l++
  j      s_r1_i2iloop                  # Jump to top out inner l loop

s_r1_i2iloop_e:
  add    $t0, $t0, 1                   # k++
  j      s_r1_i2loop                   # Jump to top of outer k loop

s_r1_i2loop_e:
  j      s_r1_bit_set_skip             # Jump if(has_single_bit_set(value))

s_r1_bit_set_skip:
  add    $s2, $s2, 1                   # j++
  j      s_r1_iloop                    # Jump to top of inner loop

s_r1_iloop_e:
  add    $s1, $s1, 1                   # i++
  j      s_r1_oloop                    # Jump to top of outer loop

s_r1_oloop_e:
  move   $v0, $s0
  lw     $ra, 28($sp)                  # Restore $ra
  lw     $s6, 24($sp)                  # Restore $s6
  lw     $s5, 20($sp)                  # Restore $s5
  lw     $s4, 16($sp)                  # Restore $s4
  lw     $s3, 12($sp)                  # Restore $s3
  lw     $s2, 8($sp)                   # Restore $s2
  lw     $s1, 4($sp)                   # Restore $s1
  lw     $s0, 0($sp)                   # Restore $s0
  add    $sp, $sp, 32                  # Deallocate stack memory
  jr     $ra                           # Return changed

s_get_square_begin:
  div    $v0, $a0, 4
  mul    $v0, $v0, 4
  jr     $ra

s_has_single_bit_set:
  beq    $a0, 0, s_hsbs_ret_zero       # Branch if(value == 0)
  sub    $a1, $a0, 1
  and    $a1, $a0, $a1
  bne    $a1, 0, s_hsbs_ret_zero       # Branch if((value & (value - 1)) == 0)
  li     $v0, 1
  jr     $ra                           # Return true

s_hsbs_ret_zero:
  li     $v0, 0
  jr     $ra                           # Return false

