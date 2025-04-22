# WireWp

( not finish, version 0.1 )

It is a simple planner for wire wrap circuits in boards.

It makes a list of pins conections for wire wrap.

Still just a bunch of scripts.

Uses sort for group wires to wrap. 

##  Rules

> Each unit have two or more pins;

> Each pin have none or one or more wires;

> Each wire connects two or more pins;

> Each wire have one name (only);

## Howto

#### List format 

Make a primary CSV list with: unit, pin, wire, obs,

_unit, the unit to place at board ;_
        U00 is the board, U01 first unit, etc

_pin, the pin of unit;_
        NN, counted as in schematics, 00 is reserved

_wire, name of wire to wrap at this pin;_
        must start with a letter, only power wires start numbers

_obs, any observation about it;_
        eg. schematics name of pin, sizes, etc 

Use one line for each wire on pin.

Use # at start of line, for comments.

#### List notes

1. _unit_ 00 is reserved for the board;
1. _pin_ 00 is reserved for specials;
1. use _obs_ for more information, eg. sizes, color, datasheet use/name of pin;

#### wires reserved

    (still a primitive sintax)

    - "NN, 00, 00, x, y," define the size of unit, top-right origin;    

    - "NN, 00, 01, t," define separation between socket pin and wired pin;    
    
    - "NN, 00, 02, t," define border ground, 0 none, 1 around, 2 interleaved;    
    
    - "NN, 00, 03, t," define separation between rows of wired pins;   
    
    - "NN, 00, 04, color, size," define color and awg of wire, 0 black, 0 30 awg

For power lines:

    0V0, for VSS, GND;
    3V3, for VDD;
    5V0, for VCC;

    nc, for not connected;

### Wire Wrap SVG

1. The units are placed at top of board and the wires at bottom;
2. The units are mirror vertically the pinout of schematics;
3. The first pin is at TOP RIGHT, last pin is at TOP LEFT, counts clockwise;
4. Leave at least 2 spaces between rows of pins;

## More

What about ?

1. auto position of units at board, with defined especifications, eg. bigger units at top, two rows of separation, lesser wires, etc
1. auto create power and ground planes with wires
1. define colors for group of wires, a0-a15 addresses, d0-d7 data, VCC, VDD, VSS, GND, etc
1. group passives in sockets, except decouple capacitors
1. place headers for extensions boards 


