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

# standart unit is 0.1 of inch

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

# svg is zero offset !
function do_canvas( ) {

    xc = xd * hole
    yc = yd * hole
    xx = xc + 3 * xb
    yy = yc + 3 * yb
    print "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
    print "<!-- Generator: Wire Wrap Toolbox, Date: " date " -->"
    print "<svg width=\"" xx + xo "\" height=\"" yy + yo "\" " 
    print "  id=\"boardwwp\" version=\"1.1\" "
    print "  xmlns=\"http://www.w3.org/2000/svg\" >"
    }

# draw a rectangle view
function do_board( ) {

    print "<rect width=\"" xc + 3 * xb "\" height=\"" yc + 3 * yb "\" " 
    print "x=\"" xo "\" y=\"" yo "\" rx=\"4\" ry=\"4\" " 
    print "style=\"fill:green; stroke:black; stroke-width:2; "
    print "fill-opacity:0.6; stroke-opacity:0.4\" />"
    }

# draw border texts
function do_texts( xxe, yye, xxf, yyf, anchore, anchorf, color, txt  )  {

    print "<text x=\"" xxe "\" y=\"" yye "\" font-size=\"" fz "\" "
    #print "alignment-baseline=\"middle\" "
    print "text-anchor=\"" anchore "\" fill=\"" color "\">" txt "</text>"

    print "<text x=\"" xxf "\" y=\"" yyf "\" font-size=\"" fz "\" "
    #print "alignment-baseline=\"middle\" "
    print "text-anchor=\"" anchorf "\" fill=\"" color "\">" txt "</text>"
    }

# mark reference
function do_reference( )  {
        
    xx = (sense == 0) ? xx = xb + xo : (xd + 1 ) * hole + xb + xo
    yy = yb + yo 
    print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" fz "\" fill=\"white\">" "." "</text>"
    print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" fz "\" fill=\"white\">" "+" "</text>"

    for (x = 1; x <= xd + 4; x += 1) {
        xx = x * hole
        for (y = 1; y <= yd + 4; y += 1) {
            yy = y * hole
            print "<text x=\"" xx "\" y=\""yy "\" font-size=\"" fz "\" "
            print "text-anchor=\"middle\" fill=\"white\">" "." "</text>"
        }
    }

}

# annotate vertical border numbers
function do_numbers( ) {

    xxe = xb + xo  
    xxf = (xd + 1) * hole + xb + xo
    for (y = 1; y <= yd; y += 1) {
        txt = sprintf ("%02d", (y % 100) ) 
        yy = y * hole + yb + yo 
        do_texts( xxe, yy, xxf, yy, "end", "start", color, txt )
        }
    }

# annotade horizontal border letters 
function do_letters( sense )  {

    color = "black"
    yye = yb + yo 
    yyf = (yd + 1) * hole + yb + yo 
    for (x = 1; x <= xd; x += 1) {
        k = (sense == 0) ? k = x % 26 : k = (xd - x) % 26 + 1 
        txt = sprintf ("%c", k + 64) 
        xx = x * hole + xb + xo 
        do_texts( xx, yye, xx, yyf, "middle", "middle", color, txt )
        }
    }

# annotade horizontal socket rows numbers 
function do_rows( sense )  {

    color = "blue"
    yye = yo + yb 
    yyf = (yd + 1) * hole + yo + yb 
    kk = 1
    for (x = 1; x <= xd; x += 1) {
        k = (sense == 0) ? k = x : k = xd - x + 1
        if ( k % 3 ) continue
        k = k - k % 3 
        txt = sprintf ("%02d", k) 
        #txt = sprintf ("%c", kk++ + 64) 
        xx = x * hole + xb + xo 
        print "<text x=\"" xx "\" y=\"" yye "\" font-size=\"" hole "\" "
        print "text-anchor=\"middle\" fill=\"" color "\">" txt "</text>"
        print "<text x=\"" xx "\" y=\"" yyf "\" font-size=\"" hole "\" "
        print "text-anchor=\"middle\" fill=\"" color "\">" txt "</text>"
        }
    }

# draw hole isles
function do_isles( sense ) {

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
            print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" hole "\" "
            print "text-anchor=\"middle\" fill=\"" dotcolor "\">" "+" "</text>"
            }
        }
    }

# reserve planes for VSS and VCC power
function do_planes( ) {

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

    #  
    split (row_name,mark,"")
    color = "red"
    k = 0
    for (x = 1; x <= xd; x += 1) {
        # cycle text
        k = (k % row_size) + 1
        if (sense != 0) {
            kk = row_size + 1 - k
            }
        tag  = mark[ kk ]
        tag = (x == 1 || x == xd) ? "x" : tag ;
        xx = (xd - x + 1) * hole + xb + xo 
        for (y = 1; y <= yd; y += 1) {
            text = (y == 1 || y == yd) ? "x" : tag ;
            yy = y * hole + yb + yo 
            print "<text x=\"" xx "\" y=\"" yy "\" font-size=\"" hole "\" "
            print "text-anchor=\"middle\" font-family=\"monospace\" "
            print "fill=\"" color "\">" text "</text>"
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

# init html
function init_html( ) {

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
    }

# exit htlm
function exit_html( ) {

    print "<hr>"
    print "</svg>"
    print "</body>"
    print "</html>"
    }

END {

# units

# leave not connected the extra holes around ?
if (0) {
    x = xd % row_size 
    xd = xd - x

    y = yd % row_size
    yd = yd - y

    xb += ( x - (x % 2) ) / 2 * hole
    yb += ( y - (y % 2) ) / 2 * hole
    }

# draw svg

    # left-right == 0 or right-left == 1
    mirror = 1

    # init_html( )

    # define svg
    do_canvas( ) 

    # draw border
    do_board( ) 

    # draw points
    do_reference( )

    # draw numbers top-down 
    do_numbers( ) 

    # draw letters mirror
    # do_letters( mirror )

    # draw counts mirror
    do_rows( mirror )

    # draw hole symbols
    do_isles( mirror )

    do_grids( mirror )
    
    print "</svg>"

    # do_planes( )

    # do_units( )

    # exit_html( )
  }

  

