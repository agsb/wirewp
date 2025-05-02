#/usr/bin/awk

# make board and tags for wire wraps
# for protoboards of 0.100" and Dual-In-Package (DIP) sockets
# agsb@2025

# DIP sockets are 0.300" or 0.600", 
# using 6 of 0.100" (mils) as standart pace
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

# define slots as wide 6 * 0.100"
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
                sock[snt]["px"] = $4
                sock[snt]["py"] = $5
                
                #print "sz  " $1 " " sock[snt]["s"] " " sock[snt]["x"] " " sock[snt]["y"]

                order[snt] = snt

                snt++

                # board size
                if ($1 == "U00") { 
                    xb = $4
                    yb = $5
                    }
                }

            # wire 01 is for order 
            if ($3 == "01") {
                order[$4] = $1
                # print "od  " $4 " " $1
                }

            next
            }

        # keep in order
        wire[wnt]["f"] = $0 # full
        wire[wnt]["s"] = $1 # sock
        wire[wnt]["p"] = $2 # pin
        wire[wnt]["w"] = $3 # wire

        #print "> " wnt " " wire[wnt]["s"] " " wire [wnt]["p"] " " wire[wnt]["w"] 

        wnt++;

} 

function do_slots( ) {
       
        xc = xb
        yc = yb 

        xn = 1
        yn = 1
        lasty[xn] = yn

        for (i = 0; i < snt; i++) {
                j = order[i];
                s = sock[j]["s"]

                if (s == "U00") continue

                x = sock[j]["px"]
                y = sock[j]["py"]

                # use unit size
                xm = SSIZE 

                # use half size
                ym = y / 2;

                print "sk " s " " x " " y " " ym

                if ((yn + ym + 1) > yc) {
                        print " y cross "
                        xn = xn + xm
                        yn = 1
                        }

                if ((xn + SSIZE + 1) > xc ) {
                        print " x cross "
                        xn = 1
                        yn = lasty[xn]
                        }

                sock[j]["x"] = xn        
                sock[j]["y"] = yn        
                
                print " sock: " s " pin: 1  x: " xn " y: " yn

                lasty[xn] = yn + ym + 1
                xn = xn + xm + 1

                }
        }

function do_costs( ) {

        w0 = ""
        p0 = ""
        s0 = ""
        x0 = ""
        y0 = ""

        costs = 0

        for (n = 0; n < wnt; n++) {
            
            w1 = wire[n]["w"]
            s1 = wire[n]["s"]
            p1 = wire[n]["p"]
            x1 = sock[n]["x"]
            y1 = sock[n]["y"]
        
            if (w1 == w0) {

                
                if (n > 1) {
                    costs = costs + abs(b1 - b0)
                    }
                    
                }

            w0 = w1
            p0 = p1
            s0 = s1
            x0 = x1
            y0 = y1
            b0 = b1

            }
        }

END {

# sockets


# draw svg

        # left-right == 0 or right-left == 1
        mirror = 1

        do_slots( );


  }

  

