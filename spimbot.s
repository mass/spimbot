.data

# Spimbot constants
NUM_FLAGS          = 40                # Maximum flags on the board
BASE_RADIUS        = 24                # Base radius
MAX_FLAGS          = 5                 # Maximum flags in hand
FLAG_COST          = 7                 # Energy cost to generate a flag
INVIS_COST         = 25                # Energy cost to go invisible

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
PRINT_INT          = 1
PRINT_STRING       = 4
PRINT_CHAR         = 11

.text
main:
  li     $t0, TIMER_MASK
  or     $t0, $t0, 1
  mtc0   $t0, $12                      # Enable timer interrupt

  li     $t0, 10
  sw     $t0, VELOCITY                 # SET_VELCOITY(10)

  lw     $t0, TIMER
  add    $t0, $t0, 10
  sw     $t0, TIMER                    # REQUEST_TIMER(TIMER() + 10)

infinite:
  j      infinite                      # Infinite loop

# Interrupt handler data
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
  sw     $a0, 0($k0)                   # Save $a0
  sw     $a1, 4($k0)                   # Save $a1
  sw     $v0, 8($k0)                   # Save $v0

  mfc0   $k0, $13                      # Get interrupt cause register
  srl    $a0, $k0, 2
  and    $a0, $a0, 0xf                 # Mask with ExcCode field
  bne    $a0, 0, non_interrupt         # Non-interrupt

interrupt_dispatch:
  mfc0   $k0, $13                      # Get interrupt cause register
  beq    $k0, 0, id_done               # Handled all interrupts

  and    $a0, $k0, TIMER_MASK
  bne    $a0, 0, interrupt_timer       # Handle timer interrupt

  li     $v0, PRINT_STRING
  la     $a0, unhandled_str
  syscall                              # Print unhandled interrupt message

  j      id_done                       # Finish interrupt handler

interrupt_timer:
  sw     $0, TIMER_ACKNOWLEDGE         # Acknowledge timer interrupt

  li     $v0, PRINT_INT
  lw     $a0, TIMER
  syscall                              # PRINT(TIMER())

  lw     $v0, TIMER
  add    $v0, $v0, 2000
  sw     $v0, TIMER                    # REQUEST_TIMER(TIMER() + 2000)

  j      interrupt_dispatch            # Handle further interrupts

non_interrupt:
  li     $v0, PRINT_STRING
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
