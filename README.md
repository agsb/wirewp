# WireWp

( sure not finish, version 0.1 )
Sorry, this is not about jewels.

I want easy make hobby eletronic circuits and the best way is 
using wire wrap, but can not found a program to design boards around 
(in the internet), then maybe I try make this one.

It is a simple planner for wire wrap circuits in boards.

It makes a list of pins conections for wire wrap.

Still just a bunch of scripts, that uses a sort for group wires to wrap
and a awk script to make a SVG draw of board and wires.

PS. I know about PCB manufacturing companies, 
but do not want expend time in draw schematics and routes, 
for "one shot" circuits.  

## What is wire wrap ?

[^1]

[^2]

### Macintosh

[^3]

[^4]

### IBM PC

[^5]

[^6]

## Design and Planner

I found some documentation about a program for wirewrap connections at
NRAO [^7], but no sources.

##  My Rules

> Each unit have two or more pins;

> Each pin have none or one or more wires;

> Each wire connects two or more pins;

> Each wire have one name (only);

## Input format 

Make a primary CSV list with: unit, pin, wire, comment,

_unit, the unit to place at board ;_
        (numeric) 00 is the board, 01 first unit, etc

_pin, the pin of unit;_
        (numeric) NN, counted as in schematics, 00 is reserved

_wire, name of wire to wrap at this pin;_
        (text) must start with a letter, only power wires start numbers

_comment, any comments about it;_
        (text) eg. schematics name of pin, sizes, etc 

Use one line for each wire on pin.

Use # at start of line, for comments.

### List notes

1. _unit_ 00 is reserved for the board;
1. _pin_  00 is reserved for specials;
1. use _comments_ for more information, 
eg. sizes, color, datasheet use/name of pin;

### wires reserved

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

## Wire Wrap SVG

### Power Planes

To reduce the noise and interference [^1], some boards uses power (Vcc) on 
components side and ground (Vss) on wires side, 
using more thicker wires.

Or both at wire side, as lines with two rows (of holes), one
with Ground (VSS) and other with Power (VCC).

Most of vendor's wirewrap PCB boards does a sequence of

    [V V x o o o G G o o o x] or [G G x o o o V V o o o x]

    __V__ vcc, __G__ vss (gnd), __x__ not connect, 
    __o__ isle for pin of sockets 

### Board

I made a mix over above concepts: 

    coordenade X is the smaller side and Y is longest side of board;

    a sequence of isles around board is left without connections;

    the identification is done at wire side of board;

    a sequence of (x x o p3 v o p2 x g p1 o x) where:
            __x__ is not connected, __o__ is for hole for long pin, 
            __p1__, __p2__, are holes socket for slim DIP, 
            __p1__, __p3__, are holes socket for wide DIP,
            __g__, is the vss line,
            __v__, is the vcc line,

            if sockets have long pins, __o__ is not connected

For common pcb protoboards, a FR4 plate with isles in both sides, 
I use long pin headers at sides of common round pin sockets, in paralel, 
as cheap substitute for special wire-wrap long pins sockets. 
Must soldering to fix both and join pins.

1. The units are placed at top of board and the wires at bottom;
2. The units are mirror vertically the pinout of schematics;
3. The first pin is at TOP RIGHT, last pin is at TOP LEFT, counts clockwise;
4. Leave at least 2 spaces between rows of pins;

## More

What about ?

1. a library of components (chips, transistors and passives)
1. auto position of units at board, with defined especifications, 
eg. bigger units at top, two rows of separation, lesser wires, etc
1. auto create power and ground planes with wires
1. define colors for group of wires, a0-a15 addresses, d0-d7 data, 
VCC, VDD, VSS, GND, etc
1. group passives in sockets, except decouple capacitors
1. place headers for extensions boards 

## References

[^1](https://schematicsforfree.com/files/Manufacturing%20and%20Design/Prototyping/Wire%20Wrapping%20Techniques.pdf)

[^2](https://www.reddit.com/r/electronics/comments/yw0an0/mid_1980s_286_single_board_computer_done/)

[^3](https://www.digibarn.com/collections/parts/mac-wirewrap5-board/index.html)

[^4](https://folklore.org/PC_Board_Esthetics.html)

[^5](https://vintagecomputer.ca/ibm-5100-in-pictures/)

[^6](https://www.puntogeek.com/2007/11/17/first-motherboard/)

[^7](https://www.gb.nrao.edu/electronics/edir/edir163.pdf.)

[^8](https://www.sierraassembly.com/blog/what-is-pcb-ground-plane/)

