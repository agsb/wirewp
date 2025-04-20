# WireWp

It is a simple planner for wire wrap boards.

Still just a bunch of scripts.

It makes a list of pins conections for wire wrap.

##   Premisses

1. Each wire have one name,

2. Each wire connect two or more pins,

3. Each pin have one or more wires,

4. Each unit have two or more pins,

5. Mirror vertically the pinout of schematics,

## List format 

Make a primary list with: unit, pin, wire, obs,

    unit, the unit to place at board ( integer counter );
        00 is the board

    pin, the pin of unit;
        counted as in schematics

    wire, name of wire in this pin;
        must start with a letter, only power start with number

    obs, any observation about it;
        eg. schematics name of pin

Use one line for each wire on pin.

### List notes

Use " 00, 00, 00, x, y," to define the size of board.

Use " NN, 00, 00, x, y," to define the size of unit.
    

  1. use # for comments
  2. use obs for datasheet use of pin,
  3. use nc for not connected
  4. use 0V0, for VSS, gnd
  5. use 3V3, for VDD,
  6. use 5V5, for VCC,

