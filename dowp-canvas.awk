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
    
    xb = dpi; 
    
    yb = dpi; 

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

    cx = dx * hole + 2 * xb
    
    cy = dy * hole + 2 * yb

    print "<canvas id=\"myCanvas\" width=\"" cx "\" height=\"" cy "\" style=\"border:1px solid black;\"> </canvas>"

    print "<script>"

    print "// https://www.w3schools.com/graphics/canvas_intro.asp"

    print "const canvas = document.getElementById(\"myCanvas\");"

    print "const ctx = canvas.getContext(\"2d\");"

    }

function do_board( ) {
 
# clear a rectangle view

    print "ctx.beginPath();"

    print "ctx.clearRect(" xo ", " yo ", " cx ", " cy ");"

# select a color 

    print "ctx.strokeStyle = \"rgb(00 255 / 50%)\";"

# chose width

    print "ctx.lineWidth = 15;"

# define a rectangle view

    print "ctx.Rect(" xo ", " yo ", " cx ", " cy ");"

    print "ctx.Stroke();"

    print "ctx.closePath();"
}

function do_isles( )  {
# draw isles

    print "ctx.lineWidth = 2;"

    for (x = 0; x < dx; x += 1) {

        xx = x * hole + xb
        
        for (y = 0; y < dy; y += 1) {
        
            yy = y * hole + yb

            print "ctx.beginPath();"

            print "ctx.Moveto ( " xx ", " yy ");"

            print "ctx.Arc( " xx ", " yy ", " isle ", 0, 2 * Math.PI)"

            print "ctx.Stroke();"

            print "ctx.closePath();"
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

    print "</script>"
    print "</body>"
    print "</html>"

  }

  

