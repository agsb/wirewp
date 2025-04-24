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

## What is wire wrap ?

It is a easy and fast way to prototype circuits using long headers 
and thin wires. 

Use a simple tool to wrap[^10] or make one [^11]. 

Some details[^9], technics[^1], standarts[^12] and tips[^13].

Why use it [^8]?

PS. I know about PCB manufacturing companies, 
but do not want expend time in draw schematics and routes, 
for "one shot" circuits.  

### Classics

Some images of IBM-PC [^3] [^4] [^7] and first Macintosh [^2]

## Design and Planner

I found some documentation about a program for wirewrap connections at
NRAO[^5] (1975) and DTIC[^14] (1982), but no sources.

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

The chips of 8 to 24 pins uses slim (0,300") form and 24 to 48 uses wide (0,600") inter rows space.

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

To reduce the noise and interference [^6], some boards uses power (Vcc) on 
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


The headers and sockets with long pins for wire-wrap boards[^15] are more expensive
than common round sockets and common pin headers.

For common pcb protoboards, a FR4 plate with isles in both sides, 
I use long pin headers at sides of common round pin sockets, in paralel, 
as cheap substitute for special wire-wrap long pins sockets. 
Must soldering to fix both and join pins.

1. The units are placed at top of board and the wires at bottom;
2. The units are mirror vertically the pinout of schematics;
3. The first pin is at TOP RIGHT, last pin is at TOP LEFT, counts clockwise;
4. Leave at least 2 spaces between rows of pins;

### Chips

| pins  | spaced | Number Designator |
| :---: | :---: | :---: |
| 6 | 0.300" | 1 |
| 8 | 0.300" | 2 |
| 14 | 0.300" | 3 |
| 16 | 0.300" | 4 |
| 18 | 0.300" | 5 |
| 20 | 0.300" | 6 |
| 24 | 0.300" | 7 |
| 24 | 0.600" | 8 |
| 28 | 0.600" | 9 |
| 40 | 0.600" | 10 |
| 48 | 0.600" | 11 |


### Colors

| Colour | Number Designator |
| :---: | :---: |
| Black | 0 | 
| Brown | 1 |
| Red | 2 |
| Orange | 3 |
| Yellow | 4 |
| Green | 5 |
| Blue | 6 |
| Violet (Purple) | 7 |
| Grey (Slate) | 8 |
| White | 9 |

From [Table 1-A-5 Colour Code](https://www.casa.gov.au/sites/default/files/2021-09/advisory-circular-21-99-aircraft-wiring-bonding.pdf)

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

[^1]:(https://schematicsforfree.com/files/Manufacturing%20and%20Design/Prototyping/Wire%20Wrapping%20Techniques.pdf)

[^2]:(https://www.digibarn.com/collections/parts/mac-wirewrap5-board/index.html)

[^3]:(https://www.reddit.com/r/electronics/comments/yw0an0/mid_1980s_286_single_board_computer_done/)

[^4]:(https://www.puntogeek.com/2007/11/17/first-motherboard/)

[^5]:(https://www.gb.nrao.edu/electronics/edir/edir163.pdf.)

[^6]:(https://www.sierraassembly.com/blog/what-is-pcb-ground-plane/)

[^7]:(https://bsky.app/profile/tubetime.bsky.social/post/3k5edfr6gxp2w)

[^8]:(https://wirewrapodyssey.com/index.html#construction)

[^9]:(https://tecratools.com/pages/tecalert/wirewrap_guide.html)

[^10]:(https://learn.sparkfun.com/tutorials/working-with-wire/how-to-use-a-wire-wrap-tool)

[^11]:(https://www.instructables.com/Wire-Wrapping-Tool-CHEAP-QUALITY-AND-EASY/)

[^12]:(https://workmanship.nasa.gov/lib/insp/2%20books/links/sections/files/301.pdf)

[^13]:(https://www.ecb.torontomu.ca/~jkoch/prototype/Proto.htm)

[^14]:(https://apps.dtic.mil/sti/tr/pdf/ADA113439.pdf)

[^15]:(https://www.peconnectors.com/wire-wrap-sockets-and-headers/)

[^16]:(https://onlinelibrary.wiley.com/doi/epdf/10.1002/spe.4380150304)

- - - 




