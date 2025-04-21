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
    
    print  ">" cnt ">" $1 ">" $2 ">" $3 ">" $4 ">" $5 ">"

    if ($2 eq "00" AND $3 eq "00") {
        x = $4
        y = $5
        unit[$1][n] = $1
        unit[$1][x] = x
        unit[$1][y] = y
        if ($1 eq "U00") { # board size
            xd = x
            yd = y
            }

        next
        }
    
    cnt++;
    wire[cnt] = $0

} 


function do_canvas( ) {

# sizes

# svg is zero offset !

    xc = xd * hole

    yc = yd * hole

    xx = xc + 2 * xb

    yy = yc + 2 * yb

    print "<p> board (" xx " by " yy ") <p> <hr> <p>  " 

    print "<svg width=\"" xx + xo "\" height=\"" yy + yo "\" " 
    print " xmlns=\"http://www.w3.org/2000/svg\" >"

    }

function do_board( ) {
 
# clear a rectangle view

    print "<rect width=\"" xc + 2 * xb "\" height=\"" yc + 2 * yb "\" " 
    print "x=\"" xo "\" y=\"" yo "\" rx=\"4\" ry=\"4\" " 
    print "style=\"fill:green; stroke:black; stroke-width:2; fill-opacity:0.6; stroke-opacity:0.4\" />"

}

function do_isles( )  {
# draw isles

    tz = hole * 0.8

    for (x = 0; x < xd; x += 1) {

        xx = x * hole + xb + xo 

        txt = sprintf ("%c", (x % 26) + 65) 

        yy = hole + yo 

        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" tz "\" fill=\"white\">" txt "</text>"

        yy = yd * hole + yo + yb 

        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" tz "\" fill=\"white\">" txt "</text>"

        }

    for (y = 0; y < yd; y += 1) {
        
        yy = y * hole + yb + yo 

        y = y % 100

        txt = sprintf ("%02d", (y+1) ) 

        xx = hole + xo  

        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" tz "\" fill=\"white\">" txt "</text>"

        xx = xd * hole + xo + xb

        print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" tz "\" fill=\"white\">" txt "</text>"

        }

    for (x = 0; x < xd; x += 1) {

        xx = x * hole + xb + xo 

        for (y = 0; y < yd; y += 1) {
        
            yy = y * hole + yb + yo 

            dotcolor = "white"

            if ( !( (x + 1) % 10 ) )  { 
                dotcolor = "black"
                }
            if ( !( (y + 1) % 10 ) ) { 
                dotcolor = "black"
                }

            print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" hole "\" fill=\"" dotcolor "\">" "+" "</text>"
            
            holecolor = "white" 

            print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" hole "\" fill=\"" holecolor "\">" "O" "</text>"

            }
        }

  }

function wires( ) {
  }

function wraps( ) {
  }

END {

# init html

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

    do_isles( )

# exit htlm

    print "<hr>"
    print "</svg>"
    print "</body>"
    print "</html>"

  }

  

