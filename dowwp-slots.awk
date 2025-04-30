#/usr/bin/awk

# make board and tags for wire wraps
# for protoboards of 0.100" and Dual-In-Package (DIP) sockets
# agsb@2025

# usually DIP sockets are 0.300" or 0.600", 
# using 6 of 0.100" (mils) as standart pace
# the board is divided in slots of 6 by 6 mils
# the sockets are placed and wires lenght counted
# the lower count is the best arrange

#
# define parameters
#
BEGIN {

# common

        FS = ",";

        RS = "\n";

# get the date

        str = "date --iso-8601=seconds";
        str | getline date;
        close(str);

# define a slot
        SSIZE = 6

# count wires
        wnt = 0;

# count sockets
        snt = 0;

# board in holes
        
        xb = 0  
        
        yb = 0

# board in slots

        xc = 0

        yc = 0
}

#
# loop 
#
{

# read the list of connections 
# increment cnt to keep the order
# do it later
# csv orderd by wire, socket, pin        
# socket, pin, wire, obs...

        # trim spaces
        gsub (" *, ", "," ,$0)

        $0 = $0

        # pin 00 is for specials
        if ($2 == "00") {

            # wire 00 is for sizes 
            if ($3 == "00") {
        
                sock[snt]["s"] = $1
                sock[snt]["x"] = $4
                sock[snt]["y"] = $5
                snt++
                
                # print "> " $1 " " socket[$1]["name"] " " socket[$1]["x"] " " socket[$1]["y"]

                # board size
                if ($1 == "U00") { 
                    xb = $4
                    yb = $5
                    }
                }

            # wire 01 is for order 
            if ($3 == "01") {
                socket[$1]["order"] = $4
                }

            next
            }

        # keep in order
        wire[wnt]["f"] = $0 # full
        wire[wnt]["s"] = $1 # sock
        wire[wnt]["p"] = $2 # pin
        wire[wnt]["w"] = $3 # wire
        cnt++;

} 

function do_slots( ) {
        
        # number of blocks 
   
        xc = (xb - xb % SSIZE) / SSIZE
        yc = (yb - yb % SSIZE) / SSIZE

        # must be even
        xc = xc - xc % 2
            
        xn = 0
        yn = 0

        for (k = 0; k < snt; k++) {
            n = sock[k]["s"]
            x = sock[k]["x"]
            y = sock[k]["y"]
            
            while (yn < y) {
                boem[xn][yn] = n
                boem[xn+1][yn] = n
                yn = yn + 6
                }
            xn++
            xn++
            if (xn > xc) {
                xn = 0;
                }
zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz
            }

        }



function do_costs( ) {

        w0 = ""
        p0 = ""
        s0 = ""
        b0 = 0 + 0

        costs = 0

        for (n = 0; n < cnt; n++) {
            
            w1 = wire[n]["w"]
            p1 = wire[n]["p"]
            s1 = wire[n]["s"]
        
            b1 = sock[n]["b"]

            if (n > 1) {
                costs = costs + abs(b1 - b0)
                }

            w0 = w1
            p0 = p1
            s0 = s1
            b0 = b1

            }
        }

}


END {

# sockets


# draw svg

        # left-right == 0 or right-left == 1
        mirror = 1

        do_sockets( );


  }

  

