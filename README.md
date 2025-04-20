# WireWp

It is a simple planner for wire wrap boards.

Still just a bunch of scripts.

It makes a list of pins conections for wire wrap.

##   Premisses

1. Each wire have one name,

2. Each pin have one or more wires,

3. Each wire connect two or more pins,

4. Each unit have two or more pins,

## List format 

Make a primary list with: unit, pin, wire, obs,

    unit, the unit to place at board ( integer counter );
    pin, the pin of unit;
    wire, name of wire in this pin;
    obs, any observation about it;

Use one line for each wire on pin.

Use "unit, 00, 00, x, y," for define the size of unit.
    
### List notes

  1. use # for comments
  2. use obs for datasheet use of pin,
  3. use nc for not connected
  4. use 0V0, for VSS, gnd
  5. use 3V3, for VDD,
  6. use 5V5, for VCC,

