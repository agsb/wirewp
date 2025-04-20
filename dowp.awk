#/usr/bin/awk

#
# define parameters
#
BEGIN {

  FS = " ";

  RS = "\n";

  SUBSEP = " ";

  cnt = 0;

#
# using 96 DPI for reference
#
# units is 0.1 of inch
 
    dip = 96 / 10

    isle = dip / 3

# border around
    
    ofx = 96; 
    
    ofy = 96; 

    dx = ofx;

    dy = ofy;

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
    print "<link rel=\"stylesheet\" type=\"text/css\" href=\"/base.css\">"
    print "</head>"
    print "<body>"

}

function do_canvas( ) {

# sizes

    bdx = dx * dpi + 2 * ofx
    
    dby = dy * dpi + 2 * ofy

    cx = 100

    cy = 100

    print "<canvas id=\"myCanvas\" width=\"" dbx "\" height=\"" dby "\" style=\"border:1px solid black;\"> </canvas>"

    print "<script>"

    print "// https://www.w3schools.com/graphics/canvas_intro.asp"

    print "const canvas = document.getElementById(\"myCanvas\");"

    print "const ctx = canvas.getContext(\"2d\");"

    }

function do_board( ) {
 
# clear a rectangle view

    print "ctx.beginPath();"

    print "ctx.clearRect(" cx ", " cy ", " dbx + cx ", " dby + cy ");"

# select a color 

    print "ctx.strokeStyle = \"rgb(00 255 / 50%)\";"

# chose width

    print "ctx.lineWidth = 5;"

# define a rectangle view

    print "ctx.Rect(" cx ", " cy ", " dbx + cx ", " dby + cy ");"

    print "ctx.Stroke();"

}

function do_isles( )  {
# draw isles

    print "ctx.lineWidth = 2;"

    for (x = 0; x < dx; x += 1) {

        xx = x * dpi + ofx
        
        for (y = 0; y < dy; y += 1) {
        
            yy = y * dpi + ofy

            print "ctx.beginPath();"

            print "ctx.Moveto ( " xx ", " yy ");"

            print "ctx.Arc( " xx ", " yy ", " isle ", 0, 2 * Math.PI)"

            print "ctx.Stroke();"

            }
        }

  }

function wires( ) {
  }

function wraps( ) {
  }

END {

    do_htmls( ) 

    dx = 100

    dy = 100

    do_canvas(  ) 

    do_board(  ) 

    do_isles(  )

    print "</script>"
    print "</body>"
    print "</html>"

  }

  

