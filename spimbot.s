.data

# spimbot constants
NUM_FLAGS   = 40	# maximum flags you can ever have on the board
BASE_RADIUS = 24
MAX_FLAGS   = 5		# maximum flags you can have in hand (might not be optimal though)
FLAG_COST   = 7
INVIS_COST  = 25

# memory-mapped I/O
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

# interrupt memory-mapped I/O
TIMER              = 0xffff001c
BONK_ACKNOWLEDGE   = 0xffff0060
COORDS_ACKNOWLEDGE = 0xffff0064
TIMER_ACKNOWLEDGE  = 0xffff006c
TAG_ACKNOWLEDGE    = 0xffff0070
INVIS_ACKNOWLEDGE  = 0xffff007c

# interrupt masks
TAG_MASK           = 0x400
INVIS_MASK         = 0x800
BONK_MASK          = 0x1000
COORDS_MASK        = 0x2000
TIMER_MASK         = 0x8000

# syscall constants
PRINT_INT = 1
PRINT_STRING = 4
PRINT_CHAR = 11

.text
main:
	# the world is your oyster
	jr	$ra
