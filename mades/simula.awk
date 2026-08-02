#!/usr/bin/awk -f
# vim: set paste ts=4 sts=4 sw=4 et :vim

BEGIN {
}

/^COB / {
	names[$2] = $3
	next
	}

cob = $1
pin = $2
wir = $3

	pinos[cob, pin] = wir

	wires[cob, wir] = pin

END {

# barramentos

	data = [D0,D1,D3,D3,D4,D5,D6,D7]

	addr = [A0,A1,A2,A3,A4,A5,A6,A7,A8,A9,A10]

}

