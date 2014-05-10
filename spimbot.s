#########################
# Karel J. Spimbot      #
# ================      #
#                       #
# File: spimbot.s       #
#                       #
# Author: Andrew Mass   #
# Date:   2014-05-10    #
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
TIMER_FREQ         = 1000

# THRESHOLDS
DEF_THRESHOLD      = 6
HAND_THRESHOLD     = 4
INVIS_THRESHOLD    = 40
INVIS_DIST         = 10
FLAGGEN_ENERGY     = 75

# Float constants
three:             .float 3.0
five:              .float 5.0
pi:                .float 3.14159265
f180:              .float 180.0

# Data member storage
defense_mode:      .word 0             # Initially in offense mode
invis_ready:       .word 0             # Initially not ready
target_x:          .word 148
target_y:          .word 150           # Initially targeted at the center
other_x:           .word -1
other_y:           .word -1            # Initally unknown

# Sudoku board memory
sudoku:            .space 512
flags:             .space NUM_FLAGS * 2 * 4

#############
# Main Loop #
#############

.text

main:
  li     $t0, BONK_MASK
  or     $t0, $t0, COORDS_MASK
  or     $t0, $t0, INVIS_MASK
  or     $t0, $t0, TAG_MASK
  or     $t0, $t0, TIMER_MASK
  or     $t0, $t0, 1
  mtc0   $t0, $12                      # Enable all interrupts

  li     $t0, 10
  sw     $t0, VELOCITY                 # SET_VELCOITY(10)

  sw     $0, COORDS_REQUEST            # REQUEST_ENEMY_COORDS()

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

  sw     $0, ANGLE
  add    $t0, $0, 1
  sw     $t0, ANGLE_CONTROL            # SET_ABSOLUTE_ANGLE(0)

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

chunkIH:           .space    28
non_intrpt_str:    .asciiz   "Non-interrupt exception\n"
unhandled_str:     .asciiz   "Unhandled interrupt type\n"

.ktext 0x80000180

interrupt_handler:
.set noat
  move   $k1, $at                      # Save $at
.set at
  la     $k0, chunkIH
  sw     $a0, 0($k0)                   # Save $a0
  sw     $a1, 4($k0)                   # Save $a1
  sw     $t0, 8($k0)                   # Save $t0
  sw     $t1, 12($k0)                  # Save $t1
  sw     $v0, 16($k0)                  # Save $v0
  sw     $ra, 24($k0)                  # Save $ra

  mfc0   $k0, $13                      # Get interrupt cause register
  srl    $a0, $k0, 2
  and    $a0, $a0, 0xf                 # Mask with ExcCode field
  bnez   $a0, non_interrupt            # Non-interrupt

interrupt_dispatch:
  mfc0   $k0, $13                      # Get interrupt cause register
  beqz   $k0, id_done                  # Handled all interrupts

  and    $a0, $k0, BONK_MASK
  bnez   $a0, interrupt_bonk           # Handle bonk interrupt

  and    $a0, $k0, COORDS_MASK
  bnez   $a0, interrupt_coords         # Handle coords interrupt

  and    $a0, $k0, INVIS_MASK
  bnez   $a0, interrupt_invis          # Handle invisibility interrupt

  and    $a0, $k0, TAG_MASK
  bnez   $a0, interrupt_tag            # Handle tag interrupt

  and    $a0, $k0, TIMER_MASK
  bnez   $a0, interrupt_timer          # Handle timer interrupt

  li     $v0, SYS_PRINT_STRING
  la     $a0, unhandled_str
  syscall                              # Print unhandled interrupt message

  j      id_done                       # Finish interrupt handler

interrupt_bonk:
  sw     $0, BONK_ACKNOWLEDGE          # Acknowledge bonk interrupt

  jal    turn_to_target                # Face current target (away from wall)

  li     $v0, 10
  sw     $v0, VELOCITY                 # SET_VELOCITY(10)

  j      interrupt_dispatch            # Handle remaining interrupts

interrupt_coords:
  sw     $0, COORDS_ACKNOWLEDGE        # Acknowledge coords interrupt

  sw     $0, COORDS_REQUEST            # REQUEST_ENEMY_COORDS()

  lw     $a0, OTHER_BOT_X              # Get OTHER_BOT_X
  bltz   $a0, interrupt_dispatch       # Halt if other bot is invisible
  lw     $a1, OTHER_BOT_Y              # Get OTHER_BOT_Y

  sw     $a0, other_x                  # Store OTHER_BOT_X
  sw     $a1, other_y                  # Store OTHER_BOT_Y

  j      interrupt_dispatch            # Handle remaining interrupts

interrupt_invis:
  sw     $0, INVIS_ACKNOWLEDGE         # Acknowledge invisibility interrupt

  add    $a0, $0, 1
  sw     $a0, invis_ready              # Set invis_ready = true

  j      interrupt_dispatch            # Handle remaining interrupts

interrupt_tag:
  sw     $0, TAG_ACKNOWLEDGE           # Acknowledge tag interrupt

  jal    turn_to_target

  j      interrupt_dispatch            # Handle remaining interrupts

interrupt_timer:
  sw     $0, TIMER_ACKNOWLEDGE         # Acknowledge timer interrupt

  lw     $a0, FLAGS_IN_HAND
  sw     $0, PICK_FLAG                 # Attempt to pick up flag (no penalty)
  lw     $a1, FLAGS_IN_HAND

  beq    $a1, $a0, it_skip_target      # Find new target if flag was picked

  bge    $a1, HAND_THRESHOLD, it_target_base # Return to base if enough flags

  jal    select_target
  jal    turn_to_target

it_skip_target:
  lw     $t0, defense_mode
  beqz   $t0, it_skip_defense

  lw     $t0, BOT_X
  bne    $t0, 148, it_skip_defense_nav

  lw     $t0, other_y
  lw     $t1, BOT_Y
  blt    $t1, $t0, it_defense_down

  add    $a0, $0, 270
  sw     $a0, ANGLE

  add    $a0, $0, 1
  sw     $a0, ANGLE_CONTROL
  j      it_skip_nav

it_defense_down:
  add    $a0, $0, 90
  sw     $a0, ANGLE

  add    $a0, $0, 1
  sw     $a0, ANGLE_CONTROL
  j      it_skip_nav

it_skip_defense_nav:
  jal    select_target                 # select_target
  jal    turn_to_target                # Turn to target

  j      it_skip_nav

it_target_base:
  sw     $0, GENERATE_FLAG
  sw     $0, GENERATE_FLAG
  sw     $0, GENERATE_FLAG
  sw     $0, GENERATE_FLAG             # Generate flags

  lw     $t0, ENERGY
  blt    $t0, FLAGGEN_ENERGY, it_skip_extra

  sw     $0, GENERATE_FLAG
  sw     $0, GENERATE_FLAG
  sw     $0, GENERATE_FLAG
  sw     $0, GENERATE_FLAG             # Generate flags

it_skip_extra:
  add    $a0, $0, 150
  sw     $a0, target_y                 # target_y = 150 (middle axis)
  add    $a0, $0, 12
  sw     $a0, target_x                 # target_x = 12 (in base)
  jal    turn_to_target                # Turn to target
  j      it_skip_nav

it_skip_defense:
  lw     $a0, BOT_X
  bge    $a0, BASE_RADIUS, it_skip_nav # Skip if right of base

  lw     $a0, BOT_Y
  bge    $a0, BE_B, it_skip_nav        # Skip if below base
  ble    $a0, BE_T, it_skip_nav        # Skip if above base

  jal    select_target                 # Target next flag
  jal    turn_to_target                # Turn to target

it_skip_nav:
  lw     $a0, SCORE                    # Get our score
  lw     $a1, ENEMY_SCORE              # Get enemy score

  add    $v0, $a1, DEF_THRESHOLD
  ble    $a0, $v0, it_enable_off       # Offense if score is below threshold
  ble    $a0, 12, it_enable_off        # Offense if less than 12 score
  jal    enable_defense                # Otherwise, defense mode
  j      it_invis

it_enable_off:
  jal    enable_offense                # Enable offense if margin is small

it_invis:
  lw     $a0, invis_ready
  beqz   $a0, it_finis
  jal    check_set_invis               # Turn invisible if able and willing

it_finis:
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
  lw     $t0, 8($k0)                   # Restore $t0
  lw     $t1, 12($k0)                  # Restore $t1
  lw     $v0, 16($k0)                  # Restore $v0
  lw     $ra, 24($k0)                  # Restore $ra
.set noat
  move   $at, $k1                      # Restore $at
.set at
  eret                                 # Return

####################
# Helper Functions #
####################

### void check_set_invis()
### Enables invisibility if there is good reason to do so
check_set_invis:
  lw     $a0, defense_mode
  bnez   $a0, csi_return

  lw     $a0, ENERGY
  blt    $a0, INVIS_THRESHOLD, csi_return

  lw     $a0, BOT_X
  blt    $a0, 150, csi_return

  lw     $a1, OTHER_BOT_X
  sub    $a0, $a0, $a1
  abs    $a0, $a0
  bgt    $a0, INVIS_DIST, csi_return

  lw     $a0, BOT_Y
  lw     $a1, OTHER_BOT_Y
  sub    $a0, $a0, $a1
  abs    $a0, $a0
  bgt    $a0, INVIS_DIST, csi_return

  sw     $0, ACTIVATE_INVIS
  sw     $0, invis_ready

csi_return:
  jr     $ra

### void enable_offense()
### Changes to offense mode if not already in offense mode
enable_offense:
  sub    $sp, $sp, 4                   # Allocate stack memory
  sw     $ra, 0($sp)                   # Save $ra

  lw     $t0, defense_mode
  beqz   $t0, eo_return                # Return if already in offense mode

  sw     $0, defense_mode              # Enable offense mode
  jal    select_target
  jal    turn_to_target                # Turn towards next target

eo_return:
  lw     $ra, 0($sp)                   # Restore $ra
  add    $sp, $sp, 4                   # Deallocate stack memory
  jr     $ra                           # Return

### void enable_defense()
### Changes to defense mode if not already in defense mode
enable_defense:
  sub    $sp, $sp, 4
  sw     $ra, 0($sp)
  lw     $a0, defense_mode
  bgtz   $a0, ed_return                # Skip if already in defense mode

  add    $v0, $0, 1
  sw     $v0, defense_mode             # Enable defense mode

  jal    select_target                 # Target defense position
  jal    turn_to_target                # Turn to target

ed_return:
  lw     $ra, 0($sp)
  add    $sp, $sp, 4
  jr     $ra

### bool select_target()
### Updates the target_x and target_y variables with correct values
### Returns true if defense target and false if offense target
select_target:
  lw     $t0, defense_mode
  beqz   $t0, st_offense

  lw     $t0, other_y
  sw     $t0, target_y                 # target_y = other_y

  add    $t0, $0, 148
  sw     $t0, target_x                 # target_x = 148 (left of half)

  add    $v0, $0, 1
  jr     $ra                           # Return true (defense mode)

st_offense:
  la     $a0, flags
  sw     $a0, FLAG_REQUEST
  lw     $a0, flags($0)
  bltz   $a0, st_no_flags              # Branch if flags[0].x < 0
  lw     $a1, flags+4($0)

  sw     $a0, target_x                 # target_x = flags[0].x
  sw     $a1, target_y                 # target_y = flags[0].y

  j      st_return_false

st_no_flags:
  li     $a0, 12
  li     $a1, 150
  sw     $a0, target_x                 # target_x = 12;
  sw     $a1, target_y                 # target_y = 150;

  sw     $0, GENERATE_FLAG
  sw     $0, GENERATE_FLAG
  sw     $0, GENERATE_FLAG
  sw     $0, GENERATE_FLAG
  sw     $0, GENERATE_FLAG             # Generate some flags

st_return_false:
  move   $v0, $0
  jr     $ra                           # Return false (offense mode)

### void turn_to_target
### Turns the spimbot to face the target
turn_to_target:
  la     $k0, chunkIH
  sw     $ra, 20($k0)

  lw     $t0, target_x
  lw     $t1, BOT_X
  sub    $a0, $t0, $t1                 # x = other_x - target_x

  lw     $t0, target_y
  lw     $t1, BOT_Y
  sub    $a1, $t0, $t1                 # y = other_y - target_y

  jal    sb_arctan                     # sb_arctan(x, y)

  add    $t0, $0, 1
  sw     $v0, ANGLE
  sw     $t0, ANGLE_CONTROL            # SET_ANGLE_ABSOLUTE(arctan)

  lw     $ra, 20($k0)
  jr     $ra

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
  sub    $sp, $sp, 24                  # Allocate stack memory
  sw     $s0, 0($sp)                   # Save $s0
  sw     $s1, 4($sp)                   # Save $s1
  sw     $s2, 8($sp)                   # Save $s2
  sw     $s3, 12($sp)                  # Save $s3
  sw     $s4, 16($sp)                  # Save $s4
  sw     $ra, 20($sp)                  # Save $ra
  add    $s0, $0, $0                   # bool changed = false
  add    $s1, $0, $0                   # int i = 0
  move   $s3, $a0                      # &board

s_r1_oloop:
  bge    $s1, 16, s_r1_oloop_e         # Exit outer loop if(i >= 16)
  and    $s2, $0, $0                   # int j = 0

s_r1_iloop:
  bge    $s2, 16, s_r1_iloop_e         # Exit inner loop if(j >= 16)

  sll    $t0, $s1, 4
  add    $t0, $t0, $s2
  sll    $t0, $t0, 1
  add    $t0, $t0, $s3                 # &board[i][j]

  lhu    $s4, 0($t0)                   # unsigned value = board[i][j]
  move   $a0, $s4
  jal    s_has_single_bit_set
  beqz   $v0, s_r1_bit_set_skip        # Branch if(!has_single_bit_set(value))

  add    $t0, $0, 15                   # int k = GRID_SQUARED - 1

  sll    $t1, $s1, 4
  add    $t1, $t1, $t0
  sll    $t1, $t1, 1
  add    $t1, $t1, $s3                 # &board[i][k]

  sll    $t2, $t0, 4
  add    $t2, $t2, $s2
  sll    $t2, $t2, 1
  add    $t2, $t2, $s3                 # &board[k][j]

s_r1_i1loop:
  bltz   $t0, s_r1_i1loop_e            # Exit inner k loop if(k < 0)
  beq    $t0, $s2, s_r1_i11_skip       # Skip if(k == j)
  lhu    $t3, 0($t1)                   # board[i][k]
  and    $t4, $t3, $s4                 # board[i][k] & value
  beqz   $t4, s_r1_i11_skip            # Skip if((board[i][k] & value) == 0)
  sub    $t4, $0, 1
  xor    $t4, $t4, $s4
  and    $t4, $t3, $t4
  sh     $t4, 0($t1)                   # board[i][k] &= ~value
  add    $s0, $0, 1                    # changed = true

s_r1_i11_skip:
  beq    $t0, $s1, s_r1_i12_skip       # Skip if(k == i)
  lhu    $t3, 0($t2)                   # board[k][j]
  and    $t4, $t3, $s4                 # board[k][j] & value
  beqz   $t4, s_r1_i12_skip            # Skip if((board[k][j] & value) == 0)
  sub    $t4, $0, 1
  xor    $t4, $t4, $s4
  and    $t4, $t3, $t4
  sh     $t4, 0($t2)                   # board[k][j] &= ~value
  add    $s0, $0, 1                    # changed = true

s_r1_i12_skip:
  sub    $t0, $t0, 1                   # k--
  sub    $t1, $t1, 2                   # &board[i][k--]
  sub    $t2, $t2, 32                  # &board[k--][j]
  j      s_r1_i1loop                   # Jump to top of k inner loop

s_r1_i1loop_e:
  srl    $t0, $s1, 2
  sll    $t0, $t0, 2                   # int ii = get_square_begin(i);
  srl    $t1, $s2, 2
  sll    $t1, $t1, 2                   # int jj = get_square_begin(j);
  move   $t2, $t0                      # int k = ii

s_r1_i2loop:
  add    $t8, $t0, 4
  bge    $t2, $t8, s_r1_i2loop_e       # Break loop if(k >= ii + 4)
  move   $t3, $t1                      # int l = jj

  sll    $t4, $t2, 4
  add    $t4, $t4, $t3
  sll    $t4, $t4, 1
  add    $t4, $t4, $s3                 # &board[k][l,jj]

s_r1_i2iloop:
  add    $t5, $t1, 4
  bge    $t3, $t5, s_r1_i2iloop_e      # Break inner loop if(l >= jj + 4)
  bne    $t2, $s1, s_r1_i21_skip       # Skip if(k != i)
  bne    $t3, $s2, s_r1_i21_skip       # Skip if(l != j)

  add    $t3, $t3, 1                   # l++
  add    $t4, $t4, 2                   # &board[k][l++]
  j      s_r1_i2iloop                  # Jump to top of inner l loop

s_r1_i21_skip:
  lhu    $t5, 0($t4)                   # board[k][l]
  and    $t6, $t5, $s4                 # board[k][l] & value
  beqz   $t6, s_r1_i22_skip            # Skip if((board[k][l] & value) == 0)
  sub    $t6, $0, 1
  xor    $t6, $t6, $s4                 # ~value
  and    $t6, $t6, $t5                 # board[k][l] & ~value
  sh     $t6, 0($t4)                   # board[k][l] &= ~value
  add    $s0, $0, 1                    # changed = true

s_r1_i22_skip:
  add    $t3, $t3, 1                   # l++
  add    $t4, $t4, 2                   # &board[k][l++]
  j      s_r1_i2iloop                  # Jump to top of inner l loop

s_r1_i2iloop_e:
  add    $t2, $t2, 1                   # k++
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
  lw     $s0, 0($sp)                   # Restore $s0
  lw     $s1, 4($sp)                   # Restore $s1
  lw     $s2, 8($sp)                   # Restore $s2
  lw     $s3, 12($sp)                  # Restore $s3
  lw     $s4, 16($sp)                  # Restore $s4
  lw     $ra, 20($sp)                  # Restore $ra
  add    $sp, $sp, 24                  # Deallocate stack memory
  jr     $ra                           # Return changed

s_has_single_bit_set:
  beqz   $a0, s_hsbs_ret_zero          # Branch if(value == 0)
  sub    $a1, $a0, 1
  and    $a1, $a0, $a1
  bnez   $a1, s_hsbs_ret_zero          # Branch if((value & (value - 1)) == 0)
  add    $v0, $0, 1
  jr     $ra                           # Return true

s_hsbs_ret_zero:
  add    $v0, $0, $0
  jr     $ra                           # Return false
