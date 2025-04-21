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
# units is 0.1 of inch
 
    dpi = 96 

    hole = dpi / 10 

    isle = hole / 3

# border around
    
    xb = dpi / 4; 
    
    yb = dpi / 4; 

# default size

    dx = 37;

    dy = 55;

# default origin

    xo = 100

    yo = 100

# default canvas

    cx = 0

    cy = 0
}

#
# loop 
#
{


} 

function do_htmls () {

    print "<!DOCTYPE html>"
    print "<html lang=\"en-US\">"
    print "<head>"
    print "<title> Wire Wrap Method </title>"
    print "<meta charset=\"utf-8\">"
    print "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">"
    print "<meta http-equiv=\"expires\" content=\"Sat, 01 Jan 2001 00:00:00 GMT\">"
    print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/base.css\">"
    print "</head>"
    print "<body>"

}

function do_canvas( ) {

# sizes

    cx = dx * hole 
    
    cy = dy * hole

    print "<p> board (" cx + 2 * xb " by " cy + 2 * yb ") <p> <hr> <p>  " 

    print "<svg width=\"" cx + 3 * xb "\" height=\"" cy + 3 * yb "\" " 
    #print " ViewBox=\" 0 0 1000 1000 \" 
    print " xmlns=\"http://www.w3.org/2000/svg\" >"

    print "<defs>"
    print "<pattern id=\"patt1\" x=\"" xb "\" y=\"" xb "\" "
    print "width=\"" hole "\" height=\"" hole "\"patternUnits=\"userSpaceOnUse\">"
    print "<circle cx=\"" hole "\" cy=\"" hole "\" r=\"" isle "\" fill=\"red\" />"
    print "</pattern>"
    print "</defs>"
    }

function do_board( ) {
 
# clear a rectangle view

print "<rect width=\"" cx + 2 * xb "\" height=\"" cy + 2 * yb "\" x=\"" xo "\" y=\"" yo 
print "\" rx=\"4\" ry=\"4\" " 
print "style=\"fill:green; stroke:red; stroke-width:2; fill-opacity:0.1; stroke-opacity:0.9\" />"

print "<rect width=\"" cx "\" height=\"" cy "\" x=\"" xo + xb "\" y=\"" yo + yb "\" rx=\"4\" ry=\"4\" fill=\"url(#patt1)\" />" 

}

function do_isles( )  {
# draw isles

    for (x = 1; x <= dx; x += 1) {

        xx = x * hole + xb + xo - hole / 2

        
        for (y = 1; y <= dy; y += 1) {
        
            yy = y * hole + yb + yo - hole / 2

            #print "<circle r=\"" isle "\" cx=\"" xx "\" cy=\"" yy "\" fill=\"red\" />"

            }
        }

  }

function wires( ) {
  }

function wraps( ) {
  }

END {

    do_htmls( ) 

    xo = 10

    yo = 10

    dx = 37

    dy = 55

    do_canvas(  ) 

    do_board(  ) 

    do_isles(  )

    print "</svg>"
    print "</body>"
    print "</html>"

  }

  

