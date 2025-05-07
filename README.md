# WireWp

( sure not finish, near to version 0.1 )

Sorry, but this is not about jewels.

I like make electronic circuits as a hobby and the best way to do is using the wire wrap. 

I need a program to design wire-wrap on standart universal protoboards, 
using standart round Dual In-line Package (DIP) sockets and standart square pins headers. 

I found some documentation about programs for planning wirewrap connections 
at NRAO[^5] (1975) and DTIC[^14] (1982), for proto-tipical boards, but no sources.

Then I decided to do this one.

It is a simple planner for wire wrap circuits that accepts a list of sockets, pins and named wires, 
then makes a simple list of pins conections for wire wrap, grouped by wire name.

Still just a bunch of scripts, that uses a sort for group wires to wrap
and a awk script to make a SVG draw of board and wires.

## What is wire wrap ?

It is a easy and fast way to prototype circuits using long headers 
and thin wires. 

It uses a simple tool to wrap[^10],  or make one [^11]. 

Some details[^9], technics[^1], standarts[^12], tips[^13] and guide[18].

Why use it [^8]?

PS. I know about PCB manufacturing companies, 
but do not want expend time in draw schematics and routes, 
for "one shot" circuits.  

## Classics

Some images of IBM-PC [^3] [^4] [^7] and first Macintosh [^2]

## Design and Planner

###  My Rules

> Each socket have two or more pins;

> Each pin have none or one or more wires;

> Each wire connects two or more pins;

> Each wire have one name (only);

### Input format 

Make a primary CSV list with: sock, pins, wire, comment,

_sock, the socket to place a unit at board ;_ Sock is just an abbreviation for socket.
        (numeric) 00 is the board, 01 first unit, etc

_pins, the pin of unit ;_
        (numeric) NN, counted as in schematics, 00 is reserved

_wire, name of wire to wrap at this pin ;_
        (text) must start with a letter, only power wires start numbers

_comment, any comments about it ;_
        (text) eg. schematics name of pin, sizes, etc 

Use one line for each wire on pin.

Use # at start of line, for comments.

Anywhere any pin not connected is marked as nc (not connected).

The sockets of 6 to 28 pins uses slim (0.300") form and 24 to 64 uses wide (0,600") inter rows space.

Use _comments_ for more information, eg. sizes, color, datasheet use/name of pin;

### Wires reserved

(still a primitive sintax, NN is a socket desigator)

- NN, 00, 00, x, y,      define the type of DIP socket ( 3 or 6) and number of pins, top-right origin;
- NN, 00, 01, n,         defines the order to place in board 
- NN, 00, 02, t,         define separation between socket pin and wired pin;    RESERVED, NOT USED
- NN, 00, 03, t,"        define border ground, 0 none, 1 around, 2 interleaved;    RESEVED, NOT USED
- NN, 00, 04, t,"        define separation between rows of wired pins;   RESERVED, NOT USED
- NN, 00, 05, color, size," define color and awg of wire, 0 black,  30 awg; RESERVED, NOT USED

### Power lines

On circuits we find references for power, as Vcc and Vee refer to circuits built on bipolar transistors, 
hence the letters C (collector, collector) and E (emitter, emitter), and as Vdd and Vss refer to circuits built on field-effect transistors,
hence the letters D (drain, drain) and S (source, source). 

Usually on old circuits, VCC is  +5 V, VDD is +12 V, VEE is -5 V and VSS is 0V0 (GND)  [^17]

Then I prefer explicity the values as using V for positive 12V0, 5V0, 3V3, 2V7, append a suffix N for negative 12V0N, 5V0N, 3V3N, 2V7N and 
use GND (0V0) for reference ground potencial.
        
### Power Planes

To reduce the noise and interference [^6], some boards uses power (V) on components side and ground (G) on wires side, using more thicker wires.

Or both at wire side, as lines with two rows (of holes), one with ground (G) and other with power (V).

Most of vendor's wirewrap PCB boards does a sequence of  [V=V x o=o=o G=G o=o=o x] or [G=G x o=o=o V=V o=o=o x],
where __V__ power, __G__ gnd, __x__ not connect and __o=o__ isle for pin of sockets connected 

I made a mix over above concepts: 

    coordenade X is the smaller side and Y is longest side of board;

    the identification is done at both sides ( component and wire) of board;

    a sequence of (x x o=p3 v o=p2 x g p1=o x) at wire wrap side:
        __x__ is not connected, __o__ is for hole for long pin, 
        __p1__, __p2__, are holes socket for slim DIP, 
        __p1__, __p3__, are holes socket for wide DIP,
        __=__, is always conected,
        __g__, is the vss line, __v__, is the vcc line,

        if socket have long pins, __o__ is not used

### Board

The headers and sockets with long pins for wire-wrap boards[^15] are more expensive
than common round sockets and common pin headers.

For common pcb protoboards, a FR4 plate with isles in both sides, 
I use long pin headers at sides of common round pin sockets, in paralel, 
as cheap substitute for special wire-wrap long pins sockets, soldering to fix both and join pins.

The sockets are placed at top of board and the wires at bottom. 
At the wires side, the sockets are mirrored vertically the pinout of schematics, 
so the first pin is at TOP RIGHT, last pin is at TOP LEFT, counts clockwise;

A prototype SVG drawing of the board, with sockets, connectors and wires, is in the testing phase.

### Protoboard

Some 10 x 10 cm2 wire wrap protoboards done with kicad, it reserves rows to use of headers in paralel with sockets, 
for "poor man wire wraps" just solder the pins to protoboard. 

The sockets side are marked as I H G F E D C B A and wire wrap side with A B C D E F G H I, rows for conectors as CON.

Those prototypes are still not tested in real FR4. Please check before order.

Protoboard type I, for maximum sockets with triple isles and 2 conectors with 2 rows, in [version 1.0](https://github.com/agsb/wirewp/tree/40e1aa6ff126634400b46e8b2a6ddee23b6c2398/wirewrap%20board%20v1) Free socket use.

Protoboard type II, for spaced sockets with extra header, lines for gnd and vcc and 2 connectors with 2 rows each, in [version 2.0](https://github.com/agsb/wirewp/tree/40e1aa6ff126634400b46e8b2a6ddee23b6c2398/wirewarp%20board%20v2) Use rows K, H, F and B for left side of socket.

Protoboard type III, for spaced sockets with extra header, conected lines for gnd and vcc and 2 connectors with 4 rows each, in [version 3.0](https://github.com/agsb/wirewp/tree/62398a8cee20bd1393776733a083bdba2ebc7329/wirewarp%20board%20v3) Use rows I, F and C for left side of socket. 

## Places

Where or How to place the sockets on the board ?

### Easy way 

By using blocks of 6 by 6 isles:

1. Do optimize by calculate the size of wires pin to pin, with some coordenate system.
1. Divide the board in blocks with 6 holes in X and by 6 holes in Y.
1. Place the sockets, in X, with left row (pin 1) in a odd block and right row in a even block, in Y with 2 rows between sockets.
1. Group the pins using blocks as coordenates
1. Count the connections from-into by sockets by blocks 
1. Then minimize the distance count.
1. repeat 3 until best minimum count

```
        eg. a 10 x 10 cm board with 37 x 37 holes
        socket 01 is 40 pins and 02, 03 is 8 pins, 04 14 pins

        1          12          24          36
        +-----------+-----------+-----------+x
        |     04    |    01     |    02      |
        +-----------+-----------+-----------+x
        |     04    |    01     |    02     |
        +-----------+-----------+-----------+x12
        |           |    01     |    03     |
        +-----------+-----------+-----------+x
        |           |    01     |    03     |
        +-----------+-----------+-----------+x24
        |           |           |           |
        +-----------+-----------+-----------+x
        |           |           |           |
        +-----------+-----------+-----------+x36

```
    
1. Place the bigger DIP at top and center, and move the others around
2. Place small passives on a DIP
3. Place capacitors 100nF Voltage to GND, for each DIP internaly to pins of DIP

Better way, using a script to do the distance "pin to pin", with a coordenate system of isles on board. 

### Script Way

In development.

I made a simple awk script to calculate the position of pins, 
relative to top left on wire wrap side. 

It loads a list of wire connections, type of sockets and order to place,
produces a list of board pins connections, with sockets and wires.

That could also be used to evaluate the order of sockets and sum of wire used.

Why do not leave the script find the best form all possible permutations ? 
Just eight sockets does 40,320 diferent permutations, ten sockets does 3,628,800, 
so better define some rules to avoid brute force.

Need more rules for evaluate, only the sum of wires is not a unbias criteria.

Any sugestions ?

### Simplifly

DIP sockets have a left side (1) and a right side (2), considering only two sockets (A and B), the possible connections between the pins are: a) A1-B1, b) A1-B2, c) A2-B1 and d) A2-B2, depending on which pins are connected.

When the sockets are placed in horizontal sequence, types a and d always pass over another side, regardless of the order, whether A-B or B-A, while type b passes over two other sides, and type c does not pass over any side. The arrangement order A-B or B-A inverts types b and c.

When the sockets are placed in vertical sequence, types a and d never pass over other sides and types b and c always pass over another side, regardless of the order, whether A-B or B-A.

Then classify the list of conections using the type of socks and pins numbers as one of _a, b, c, d_ above, allow to quantify the better orientation for placing the socks, or horizontaly (more b and c), or verticaly (more a and d).

## More

### Sockets in Dual in-line Package

"DIP parts have standard sizes that follow JEDEC rules. 
The space between two pins (called pitch) is 0.1 inches (2.54 mm). 
The space between two rows of pins depends on how many pins are in the package. 
Common row spacings are slim with 0.3 inches (7.62 mm) or wide 0.6 inches (15.24 mm)"

Sockets uses a designator with spacing ( 1 to 4 or 1 to 7 ) and number of pins (slim, 6 to 28 or wide, 24 to 64)

### Wire Colors

There are any consensus about colors of wires ? 
Which color for VSS, for VCC, for Address, Data, Controls, Inputs, Outputs ? 
But for wire colors there is a designator, and some tips for using.

| Colour | Number Designator | Use |
| :---: | :---: | :---: |
| Black | 0 | GND |
| Brown | 1 |  Output |
| Red | 2 | 5V0 |
| Orange | 3 | 3V3 |
| Yellow | 4 | Control |
| Green | 5 | Data |
| Blue | 6 | Adress |
| Violet (Purple) | 7 | Clock |
| Grey (Slate) | 8 |  |
| White | 9 | Input |

adapted from [Table 1-A-5 Colour Code](https://www.casa.gov.au/sites/default/files/2021-09/advisory-circular-21-99-aircraft-wiring-bonding.pdf)

PS. Note this color squema is for digital circuits, not and never for home wiring.

### Design Tips (?)

### What about (?)

1. a library of components (chips, transistors and passives)
1. auto position of units at board, with defined especifications, 
eg. bigger units at top, two rows of separation, lesser wires, etc
1. auto create power and ground planes with wires
1. define colors for group of wires, a0-a15 addresses, d0-d7 data, 
VCC, VDD, VSS, GND, etc
1. group passives in sockets, except decouple capacitors
1. place headers for extensions boards 
1. make svg draw of board

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

[^17]:(https://woopcb.com/blog/what-is-vcc-vss-vdd-vee-in-electronics)

[^18]:(https://www.jmargolin.com/making/jm_making.htm#p4)

 




