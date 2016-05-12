#!/bin/bash


DATE=$(date | sed 's/ /_/g' | sed 's/:/_/'g | cut -d"_" -f-6)
OLD=$(readlink -f /tmp/nextseq_cronjob/NextSeq500175/*)


NS75=/jumbo/Nextseq500175

ls $NS75 > /tmp/nextseq_cronjob/lsNS75.${DATE}.tmp
NEW=/tmp/nextseq_cronjob/lsNS75.${DATE}.tmp

diff $OLD $NEW > /tmp/nextseq_cronjob/NextSeq500175/differences_$DATE

DIFFERENCES=$(wc -l /tmp/nextseq_cronjob/NextSeq500175/differences_$DATE | cut -f 1 -d " ")

if [ $DIFFERENCES > 0 ] ; then
    rm $OLD
#_______________












#______________
