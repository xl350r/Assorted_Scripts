#!/bin/bash
## Author: Daniel Hoberecht
##nmap prefixes file installed from brew is at /usr/local/Cellar/nmap/7.60/share/nmap/nmap-mac-prefixes
##OS: OSX
##
$nmap_prefixes_file =' location of nmap-mac-prefixes'

arptable() { arp -a $@ | cut -d " " -f2,4 | tr -d ")(" | tr " " "\t" | egrep -v "^224|^255|255\t"; }

arpid() {
MACS=$(arptable | awk -F "\t" '{print $2}' | egrep -v "incomplete" | awk -F ":" '{if (length($1) == 
1) {a = 0$1}  else {a = $1} if (length($2) == 1) {b =  0$2} else {b = $2} if (length($3) == 1) {c = 
0$3} else {c = $3} print a,b,c }' | tr -d " "  | tr "\n" ' ' )

for i in $MACS
do
        cat $nmap_prefixes_file | grep -i $i
done

}

