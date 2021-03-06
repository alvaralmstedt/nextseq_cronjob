#!/bin/bash -l 
ls -hla $1 | grep -e "drwxr" | sed -r 's/ +/|/g' | cut -d"|" -f9- > dirlist.tmp
NUMDIRS=$(wc -l dirlist.tmp | cut -d" " -f1)
NUM=0
for i in $(seq 1 $NUMDIRS);
do
NUM=$(($NUM+1))
DIR=$(sed "${NUM}q;d" dirlist.tmp)
grep -e "Investigator Name," ${1}$DIR/SampleSheet.csv | cut -d"," -f2 >> investigatorinitials.tmp
done
sort -u investigatorinitials.tmp >> investigatorinitials_unique
rm investigatorinitials.tmp
rm dirlist.tmp
