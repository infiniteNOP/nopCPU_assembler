#!/usr/bin/tclsh
# nopCPU assembler!
# Copyright (C) 2016 John Tzonevrakis 
# Licensed under the CDDL. For more details, see the COPYING file.

# Begin subroutines

# proc lut_msb {input}
# proc lut_lsb {input}
# These are Look-Up-Tables (LUTs) used to convert the arguments of instructions
# acting on registers to the LSB operands of the final instruction.

proc lut_msb {input} {
    switch $input {
        "a" {return 0x0}
        "b" {return 0x4}
        "c" {return 0x8}
        "d" {return 0xc}
        default {return -1}
    }
}
proc lut_lsb {input} {
    switch $input {
        "a" {return 0x0}
        "b" {return 0x1}
        "c" {return 0x2}
        "d" {return 0x3}
        default {return -1}
    }
}

# proc operandDecode {operands}
# Converts the operands of instructions acting on the register file to 
# LSB bytes which will be ORed with the MSB to create the final instruction.

proc operandDecode {operands} {
    # Operands are separated with commas, so we have to split them first:
    set commaSplit [split $operands ","]
    # This function only works when the operands refer to registers.
    # Source & target registers are encoded in the LSB of the instruction.
    if {[llength $commaSplit] == "2"} {
        set regA [lindex $commaSplit 0]
        set regB [lindex $commaSplit 1]
    } else {
        return -code error -errorinfo "Fatal: Too many or too few operands." -errorcode "-2"
    }
    set a  [lut_msb $regA]
    set b  [lut_lsb $regB]
    return [expr {$a | $b}]
}

# proc instrDecode {line}
# Returns a list containing bytecode.
# Decodes the instructions, converting it to bytecode.

proc instrDecode {line} {
    set parts [split $line " "]
    if {[llength $parts] == "2"} {
        set instruction [lindex $parts 0]
        set operands [lindex $parts 1]
        set o_regs [string range $operands 0 end-3]
        set o_addy [string range $operands 4 end]
        set o_addy_ldu [string range $operands 2 end]
    } else {
        return -code error -errorinfo "Invalid instruction length" -errorcode "-1"
    }
    # Everything is alright! We can begin decoding our instruction.
    set lsb [operandDecode $operands]
    switch $instruction {
        "or" {set msb 0x00}
        "and" {set msb 0x10}
        "not" {set msb 0x20}
        "xor" {set msb 0x30}
        "add" {set msb 0x40}
        "sub" {set msb 0x50}
        "rshift1" {set msb 0x60}
        "rshiftn" {set msb 0x70}
        "ld" {set msb "0x80 [expr {$operands}]"}
        "jmp" {set msb "0x90 [expr {$operands}]"}
        "nop" {set msb 0x9f}
        "call" {set msb "0xa0 [expr {$operands}]"}
        "rts" {set msb 0xb0}
        "beq" {set msb "[expr {0xc0 | [lut_msb $o_regs]}] [expr {$o_addy}]"}
        "bne" {set msb "[expr {0xd0 | [lut_msb $o_regs]}] [expr {$o_addy}]"}
        "st" {set msb "[expr {0xe0 | [lut_msb $o_regs]}] [expr {$o_addy}]"} 
        "ldumem" {set msb "[expr {0xf0 | [lut_msb $o_regs]}] [expr {$o_addy_ldu}]"}
    }
    if {$lsb == -1} {
        if {$msb > 0x70} {
            return $msb
        }
        else {
            return -code error -errorinfo "Fatal: Unknown operands" -errorcode "-3"
        }
    } 
    return [expr {$msb | $lsb}]
}
# End subroutines.


# Begin main code:

if {$argc < 2} {
        return -code error -errorinfo "Fatal: Too few arguments." -errorcode "-4"
}

# We need a disclaimer, because this is possible in tcl:
# set a pu
# set b ts
# $a$b "Hello, World!"
# (And I don't know if I have properly prevented such situations.

if {[lindex $argv 2] != "y"} {
    puts "DISCLAIMER! PLEASE READ!\n"
    puts "BEWARE! The author admits that he isn't very familiar with TCL.\n"
    puts "This program was written immediately after I learned TCL (in one hour).\n"
    puts "AS SUCH, USER INPUT SANITIZATION MIGHT NOT OCCUR PROPERLY!\n"
    puts "The author recommends that you check your input file for potentially"
    puts "dangerous strings before using this program.\n"
    puts "REMEMBER: In case something bad happens, *YOU ARE ON YOUR OWN*!\n"
    puts "This program does not come with any warranties,"
    puts "and the author is *NOT* responsible for any damages, *INCLUDING* damages"
    puts "to life or property as a result of using this program.\n"
    puts "This program is licensed under the CDDL. For more details, see the"
    puts "COPYING file.\n"
    puts "If you agree with this, then please press RETURN to proceed."
    puts "In case you don't want to see this disclaimer again, please append y to"
    puts "the end of your command line arguments.\n"
    puts "Otherwise, please press CONTROL+C to quit:\n"
    gets stdin
}

# Initialize our eeprom list. This is where the assembled bytecode will be stored.
set eeprom ""

for {set i 0} {$i < 256} {incr i} {
    # Pre-fill our EEPROM with NOPs
    set eeprom [concat $eeprom 159]
}

# The user has most probably accepted our disclaimer.
# Try to open our input file:
set z 0
set infile [open [lindex $argv 0] r]
while {[gets $infile data] >= 0} {
    set line [string trim $data]
    set eeprom [lreplace $eeprom $z $z [instrDecode $line]]
    incr z
}
close $infile

# Try to open our output file:

set outfile [open [lindex $argv 1] w]

# Write COE boilerplate stuff:

puts $outfile "; COE file auto-generated by nopCPU assembler."
puts $outfile "memory_initialization_radix=10;"
puts $outfile "memory_initalization_vector="
foreach x $eeprom {
    puts $outfile "$x,"
}
puts $outfile ";"
close $outfile
