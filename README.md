# Karel J. Spimbot
> The distance between insanity and genius is measured only by success. -Bruce Feirstein

## Strategy
See `writeup.txt` for stategy details.

## Code Style

### Indentation
In order to align the main components of MIPS code, we will start the componets at a specific column of the file. 

**Use spaces for tabs.**

Compents | Column | Example
--- | --- | ---
Labels / Segments | 0 | `.globl total_mass`
Instructions | 3 | `move` |
Registers / Jump Targets | 10 | `$sp, $sp, 16`
Comments | 40 | `# Save $s2`

### Registers
Whenever possible, use the callee-saved `$s0-$s7` registers at the beginning of the function.

### Comments
Try to comment as much as possible so everyone knows what the code is doing. Comments can be the `C` equivalent of the instruction or several subsequent instructions, or just a general description of what the assembly is doing.

### Example
```
.globl total_mass
total_mass:
  sub    $sp, $sp, 16                  # Allocate stack memory
  sw     $s0, 0($sp)                   # Save $s0
  sw     $s1, 4($sp)                   # Save $s1
  sw     $s2, 8($sp)                   # Save $s2
  sw     $ra, 12($sp)                  # Save $ra
  li     $s0, 0                        # int mass = 0
  li     $s1, 0                        # int i = 0
```
