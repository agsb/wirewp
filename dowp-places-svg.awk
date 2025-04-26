#/usr/bin/awk

# make board and tags for wire wraps
# agsb@2025

#
# define parameters
#
BEGIN {

# common

    FS = ",";

    RS = "\n";

    cnt = 0;

    str = "date --iso-8601=seconds";
    str | getline date;
    close(str);

#
# using 96 DPI for reference
#
 
    dpi = 96

# standart socket is 0.1 of inch

    hole = dpi / 10 

# circles around holes

    isle = hole / 3

# border around holes
    
    xb = hole * 1  
    
    yb = hole * 1

# font size

    fz = hole * 0.8

# standart board using round pin sockets and long pin headers
# x not connected, o row of headers, s row of sockets,
# g Vss (GND), v vcc, t 

    row_name = "txosvosxgsox"

    row_size = length (row_name)

# default origin

    xo = 0

    yo = 0

# default size

    xd = 0;

    yd = 0;

# default canvas

    xc = 0;

    yc = 0;

    xm = 0;

    ym = 0;
}

#
# loop 
#
{

# read the list of connections 
# increment cnt to keep the order
# do it later
    
    # trim spaces
    gsub (" *, ", "," ,$0)

    # specials
    if ($2 == "00") {

        # sizes 
        if ($3 == "00") {
    
            x = $4
            y = $5
            
            socket[$1]["name"] = $4
            socket[$1]["x"] = x
            socket[$1]["y"] = y
            
            # print "> " $1 " " socket[$1]["name"] " " socket[$1]["x"] " " socket[$1]["y"]

            if ($1 == "U00") { # board size
                xd = x
                yd = y
                }
            }

        # order 
        if ($3 == "01") {
        
            socket[$1]["order"] = $4
            
            }

        next
        }
    

    cnt++;
    wire[cnt] = $0

} 

function do_sockets( ) {

    # 
    
    xn = xd

    yn = yd

    ym = 0
    
    for (u in socket ) {

        if (u == "U00") {
            continue
            }

        x = socket[u]["x"] 
        y = socket[u]["y"] 

        # minimal 
        if (yn > y && y > 4) {
            yn = y
            }

        # maximal 
        if ( ym < y ) {
            ym = y
            }

        }
    
    # how many horizontal slots of standart block
    # [xosgosovsoxx] [xxoxxosvosogsox]
    xn = ( xn - xn % 12 ) / 12

    # use a half for calculate, (never odd)
    # and leave a space around .[s...s].
    yn = ( yn / 2 ) + 2 

    # how many vertical slots of smalest socket 
    yn = ( yd - yd % yn ) / yn

    # print " slots " xn " in X and " yn " in Y "

    # order by count connections 
    w = ""
    u = ""
    p = 0
    k = 0

    for (n = 1; n <= cnt; n++) {

        $0 = wire[n]
        # trim spaces
        gsub (" *, ", "," ,$0)
        $0 = $0

        # next wire 
        if ( w != $3 ) {
            pri[w] = k
            u = $1
            p = $2
            w = $3
            k = 0
            continue
            }

        if ( u == $1 ) {
            continue
            }

        print " " u ", " $1
        #print " " $1 ", " u

        k++ 
        u = $1

        }
    
    print " " u ", " $1
    #print " " $1 ", " u

    pri[w] = k

    " mktemp " | getline file

    for (n in pri) {
        print  n "," pri[n] > file
        }
        
    " sort -t',' -k 2 < $file > $file.ss " 
  }


END {

# sockets


# draw svg

    # left-right == 0 or right-left == 1
    mirror = 1

    do_sockets( );


  }

  

