# WireWp

( not finish, version 0.1 )

It is a simple planner for wire wrap boards.

Still just a bunch of scripts.

It makes a list of pins conections for wire wrap.

Uses sort for group wires to wrap 

##   Premisses

1. Each wire have one name,

2. Each wire connect two or more pins,

3. Each pin have one or more wires,

4. Each unit have two or more pins,

## List format 

Make a primary CSV list with: unit, pin, wire, obs,

_unit, the unit to place at board ;_
        00 is the board

_pin, the pin of unit;_
        counted as in schematics

_wire, name of wire to wrap at this pin;_
        must start with a letter, only power wires start numbers

_obs, any observation about it;_
        eg. schematics name of pin

Use one line for each wire on pin.

Use # at start of line, for comments.

### List notes

1. unit 00 is reserved for the board;
1. pin 00 is reserved for specials;
1. use obs for more information, eg.  sizes, color, datasheet use/name of pin;

#### wires reserved

Use:

    "NN, 00, 00, x, y," to define the size of unit;    
    0V0, for VSS, GND;
    3V3, for VDD;
    5V0, for VCC;
    nc, for not connected;

### Wire wrap

1. The units are placed at top of board and the wires at bottom;
2. The units are mirror vertically the pinout of schematics;
3. The first pin is at TOP RIGHT, last pin is at TP LEFT;
4. Leave at least 2 spaces between rows of pins;





