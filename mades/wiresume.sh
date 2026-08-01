

cat $1 | \
sort -t',' -k1,1 -k2,2 > $1.tmp
grep '1-1' $1.tmp > $1.s11
grep '1-2' $1.tmp > $1.s12
grep '2-1' $1.tmp > $1.s21
grep '2-2' $1.tmp > $1.s22
wc $1.s*



