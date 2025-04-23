#/usr/bin/awk

#
# define parameters
#
BEGIN {

# common

  FS = ",";

  RS = "\n";

  cnt = 0;

#
# using 96 DPI for reference
#
 
    dpi = 96

# standart unit is 0.1 of inch

    hole = dpi / 10 

# circles around holes

    isle = hole / 3

# border around holes
    
    xb = hole * 2  
    
    yb = hole * 2

# sizes

    tz = hole * 0.8

# default origin

    xo = 100

    yo = 100

# default size

    xd = 0;

    yd = 0;

# default canvas

    xc = 0;

    yc = 0;

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
            
            unit[$1]["name"] = $4
            unit[$1]["x"] = x
            unit[$1]["y"] = y
            
            if ($1 == "U00") { # board size
                xd = x
                yd = y
                }
            }

        # order 
        if ($3 == "01") {
        
            unit[$1]["order"] = $4
            
            }

        next
        }
    

    cnt++;
    wire[cnt] = $0

    #print  ">" cnt ">" $1 ">" $2 ">" $3 ">" $4 ">" $5 ">"

} 

function do_canvas( ) {

# sizes

# svg is zero offset !

    xc = xd * hole

    yc = yd * hole

    xx = xc + 2 * xb

    yy = yc + 2 * yb

    print "<p> board (" xd " by " yd ") <p> <hr> <p>  " 

    print "<svg width=\"" xx + xo "\" height=\"" yy + yo "\" " 
    print " xmlns=\"http://www.w3.org/2000/svg\" >"

    }

function do_board( ) {
 
# clear a rectangle view

    print "<rect width=\"" xc + 2 * xb "\" height=\"" yc + 2 * yb "\" " 
    print "x=\"" xo "\" y=\"" yo "\" rx=\"4\" ry=\"4\" " 
    print "style=\"fill:green; stroke:black; stroke-width:2; fill-opacity:0.6; stroke-opacity:0.4\" />"

}

function do_marks( )  {

        xx = ( xd + 1 ) * holes + xb + xo 
        yy = yb + yo 

        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" tz "\" fill=\"white\">" "." "</text>"
        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" tz "\" fill=\"white\">" "+" "</text>"

    for (x = 1; x <= xd; x += 1) {

        xx = x * hole + xb + xo 

        txt = sprintf ("%c", (x % 26) + 64) 

        yy = yb + yo 

        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" tz "\" fill=\"white\">" txt "</text>"

        yy = (yd + 1) * hole + yb + yo 

        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" tz "\" fill=\"white\">" txt "</text>"

        }

  }

function do_numbers( ) {

    for (y = 1; y <= yd; y += 1) {
        
        yy = y * hole + yb + yo 

        y = y % 100

        txt = sprintf ("%02d", (y) ) 

        xx = xb + xo  

        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" tz "\" fill=\"white\">" txt "</text>"

        xx = (xd + 1) * hole + xb + xo

        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" tz "\" fill=\"white\">" txt "</text>"

        }
    }

function do_letters( sense )  {

    # mark reference

        yy = yb + yo 
        
        if (sense == 0) {
            xx = xb + xo 
            }
        else {
            xx = (xd + 1 ) * hole + xb + xo 
            }

        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" tz "\" fill=\"white\">" "." "</text>"
        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" tz "\" fill=\"white\">" "+" "</text>"

    # annotade 

    for (x = 1; x <= xd; x += 1) {

        xx = x * hole + xb + xo 

        if (sense == 0) {
            txt = sprintf ("%c", (x % 26) + 64) 
            }
        else {
            txt = sprintf ("%c", ((xd - x ) % 26 + 1) + 64) 
            }

        yy = yb + yo 

        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" tz "\" fill=\"white\">" txt "</text>"

        yy = (yd + 1) * hole + yb + yo 

        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" tz "\" fill=\"white\">" txt "</text>"

        }
}

function do_isles( sense ) {

    holecolor = "white" 

    for (x = 1; x <= xd; x += 1) {

        xx = x * hole + xb + xo 

        for (y = 1; y <= yd; y += 1) {
        
            yy = y * hole + yb + yo 

            dotcolor = "white"

            if ( !( y % 10 ) )  { 
                dotcolor = "black"
                }

            if (sense == 0) {
                if ( !( x % 10 ) )  { 
                    dotcolor = "black"
                    }
                }
            else  {

                if ( !( (xd - x + 1) % 10 ) )  { 
                    dotcolor = "black"
                    }
               }

            print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" hole "\" fill=\"" dotcolor "\">" "+" "</text>"
            
            }
        }
  }

function do_planes( ) {
    # reserve planes for VSS and VCC power


    for (x = 1; x <= xd; x += 1) {

        xx = x * hole + xb + xo 

        yy = 1 * hole + yb + yo 
            
        gnd_color = "black"

        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" hole "\" fill=\"" gnd_color "\">" "X" "</text>"

        yy = yd * hole + yb + yo 
            
        gnd_color = "red"

        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" hole "\" fill=\"" gnd_color "\">" "X" "</text>"

        }

    for (x = 5; x <= xd; x += 5) {

        gnd_color = "black"

        if ( !(x % 10) ) {

            gnd_color = "red"

            }

        xx = x * hole + xb + xo 

        for (y = 2; y < yd; y++) {

            yy = y * hole + yb + yo 
            
            print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" hole "\" "
            print "fill=\"" gnd_color "\">" "X" "</text>"

            }
        }

}

function do_grids( sense ) {

    #       opVopxgpox
    split ("osVosxGsox",mark,"")

    color = "red"

    k = 0

    for (x = 1; x <= xd; x += 1) {

        # cycle 1 to 10
        k = (k % 10) + 1

        if (sense != 0) {
            kk = 11 - k
            }

        tag  = mark[ kk ]

        tag = (x == 1 || x == xd) ? "x" : tag ;

        xx = (xd - x + 1) * hole + xb + xo 

        for (y = 1; y <= yd; y += 1) {

            text = (y == 1 || y == yd) ? "x" : tag ;

            yy = y * hole + yb + yo 

            print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" hole "\" "
            print "font-family=\"monospace\" fill=\"" color "\">" text "</text>"

            }
        }

}

function do_units( ) {

    # wire wrap mirror datasheets pinouts

    # leave space outer ground 

    xbb = 2
    ybb = 2

    cs = 1

    for (u in unit ) {

        if (u == "U00") {
            continue
            }

    # more two rows for long wires (paralel to socket)
    # and more two between those

    # for easy all space are blocked in 8 holes 
        xu = unit[u]["x"] 
        yu = unit[u]["y"] 

        txt = sprintf ("%02d", cs ) 

        for ( y = 0; y < yu; y++) {

            yy = (y + ybb) * hole + yb + yo

            xx = (0 + xbb) * hole + xb + xo 

            print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" hole "\" "
            print " fill=\"" "blue" "\">" txt "</text>"

            xx = (xu + xbb) * hole + xb + xo

            print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" hole "\" "
            print " fill=\"" "blue" "\">" txt "</text>"

            }

        xbb += xu + 2

        if (xbb > xd) { 

            xxb = 2

            ybb += yu + 2

            }

        }   
  }

function wires( ) {
  }

function wraps( ) {
  }

END {

# init html

    print " < " xd " == " yd " > "

    print "<!DOCTYPE html>"
    print "<html lang=\"en-US\">"
    print "<head>"
    print "<title> Wire Wrap Planner </title>"
    print "<meta charset=\"utf-8\">"
    print "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
    print "<meta http-equiv=\"expires\" content=\"Sun, 01 Jan 2001 00:00:00 GMT\">"
    print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/mystyles.css\">"
    print "</head>"
    print "<body>"

#    could use this for define dpi
#    print "<div id="dpi"></div>"
#    print "#dpi { height: 1in; width: 1in; left: -100%; top: -100%; position: absolute; }"
#    print "alert(document.getElementById(\"dpi\").offsetHeight);"

# units

    #xd = 0

    #yd = 0

# draw 

    do_canvas( ) 

    do_board( ) 

    do_numbers( ) 

    do_letters( 1 )

    do_isles( 1 )

    do_grids( 1 )
    
    # do_planes( )

    # do_units( )

# exit htlm

    print "<hr>"
    print "</svg>"
    print "</body>"
    print "</html>"

  }

  

