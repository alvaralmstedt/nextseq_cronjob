#!/bin/bash -l


DATE=$(date | sed 's/ /_/g' | sed 's/:/_/'g | cut -d"_" -f-6)
OLD=$(readlink -f /tmp/nextseq_cronjob/NextSeq500175/*)


NS75=/jumbo/Nextseq500175

ls $NS75 > /tmp/nextseq_cronjob/NextSeq500175/lsNS75.${DATE}.tmp
NEW=/tmp/nextseq_cronjob/NextSeq500175/lsNS75.${DATE}.tmp

diff $OLD $NEW | grep ">" | cut -f 2 -d " " > /tmp/nextseq_cronjob/NextSeq500175/differences_$DATE
DIFF_FILE=/tmp/nextseq_cronjob/NextSeq500175/differences_$DATE
DIFFERENCES=$(wc -l /tmp/nextseq_cronjob/NextSeq500175/differences_$DATE | cut -f 1 -d " ")
echo $DIFFERENCES
if [ $DIFFERENCES > 0 ] ; then
    rm $OLD
    COUNTDIFF=1
    for i in $DIFFERENCES ; do
        RUN=$(sed "${COUNTDIFF}q;d" $DIFF_FILE)
#_______________

        #cd /jumbo/WorkingDir/Runs
        #mkdir $RUN


        #module load bcl2fastq/2.17.1.14

        #nohup bcl2fastq  --runfolder-dir /jumbo/Nextseq500175/$RUN -o /jumbo/WorkingDir/Runs/$RUN -r4 -p4 -d4 -w4 --barcode-mismatches 1 --no-lane-splitting --min-log-level TRACE > /jumbo/WorkingDir/Runs/${RUN}/${RUN}_nohup.txt
        #cp /jumbo/Nextseq500175/${RUN}/SampleSheet.csv ${RUN}/.
        #time /jumbo/WorkingDir/Programs/NextSeq/NS_FastqMergeQC_3.pl $RUN >> /jumbo/WorkingDir/Runs/${RUN}/${RUN}_nohup.txt
        #time /jumbo/WorkingDir/Programs/NextSeq/NS_createRunReport_3.pl MD $RUN >> /jumbo/WorkingDir/Runs/${RUN}/${RUN}_nohup.txt


        echo $RUN >> /tmp/nextseq_cronjob/test/test
        COUNTDIFF=$(($COUNTDIFF+1))
done
fi
#rm $DIFF_FILE








#______________
