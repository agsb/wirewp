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

        if ( $1 ~ /^#/) {
            next
            }

        # trim spaces
        gsub (" *, ", "," ,$0)

        $0 = $0

        # pin 00 is for specials
        if ($2 == "00") {

            # wire 00 is for sizes 
            if ($3 == "00") {
                
                s = $1
                slot[s]["px"] = $4
                slot[s]["py"] = $5
                
                # print " s " s " px " slot[s]["px"] " py " slot[s]["py"]
                
                # board size
                if ($1 == "U00") { 
                    xb = $4
                    yb = $5
                    }
                else {
                # default order for place
                    snt++
                    order[snt] = s
                    }

                }

            # wire 01 is for order 
            if ($3 == "01") {
                # never touch "+0"
                n = $4 +0
                order[n] = $1
                }

            next
            }

        # keep wires in order
        wire[wnt]["f"] = $0 # full
        wire[wnt]["s"] = $1 # sock
        wire[wnt]["p"] = $2 # pin
        wire[wnt]["w"] = $3 # wire

        # print "> " wnt " " wire[wnt]["s"] " " wire [wnt]["p"] " " wire[wnt]["w"] 

        wnt++;

} 

function do_slots( ) {
       
        xc = xb
        yc = yb 

        xn = 1
        yn = 1
        lasty[xn] = yn

        for (j = 1; j <= snt; j++) {
               
                i = j

                s = order[i]
                               
                # skip board
                if (s == "U00") continue

                x = slot[s]["px"]
                y = slot[s]["py"]

                # use unit size
                xm = SSIZE 

                # use half size
                ym = y / 2;

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

                slot[s]["x1"] = xn        
                slot[s]["y1"] = yn        
                
                print  "> " i ", " s ", " x ", " y ", " xn ", " yn

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
        ncost = 0

        for (n = 0; n < wnt; n++) {
            
            # take the wire
            w1 = wire[n]["w"]
            s1 = wire[n]["s"]
            p1 = wire[n]["p"]

            # where starts
            x1 = slot[s1]["x1"]
            y1 = slot[s1]["y1"]
        
            # what sizes
            xd = slot[s1]["px"]
            yd = slot[s1]["py"]
            
            if ( p1 < (y1 / 2) ) { 
                x1 = x1 + 0
                y1 = y1 - 1 + (pin) 
                }
            else {    
                x1 = x1 + xd
                y1 = y1 - 1 + (yd - p1)
                }

            if (w1 == w0) {

                dist = sqrt ( (x1-x0)*(x1-x0) + (y1-y0)*(y1-y0) )

                print "= " w0 ", " s0 ", " p0 ", " s1 ", " p1 ", " dist
                costs = costs + dist
                ncost++
                }
            else {
                print " w: " w0 " costs: " costs " n: " ncost
                }

            w0 = w1
            p0 = p1
            s0 = s1
            x0 = x1
            y0 = y1

            }

        print "= " w0 ", " s0 ", " p0 ", " s1 ", " p1 ", " dist
        print " w: " w0 " costs: " costs " n: " ncost

}

END {

# sockets

        #do_rolette();

        do_slots( );

        do_costs();

  }

  

