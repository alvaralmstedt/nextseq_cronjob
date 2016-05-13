#!/bin/bash -l


DATE=$(date | sed 's/ /_/g' | sed 's/:/_/'g | cut -d"_" -f-6)
OLD=$(readlink -f /jumbo/apps/misc-scripts/nextseq_cronjob/nextseq_500175_dirlist/*)

NS75=/jumbo/Nextseq500175

ls $NS75 > /jumbo/apps/misc-scripts/nextseq_cronjob/nextseq_500175_dirlist/lsNS75.${DATE}.tmp
NEW=/jumbo/apps/misc-scripts/nextseq_cronjob/nextseq_500175_dirlist/lsNS75.${DATE}.tmp

DIFF_FILE=/jumbo/apps/misc-scripts/nextseq_cronjob/tmp-files/nextseq_500175/differences_$DATE
diff $OLD $NEW | grep ">" | cut -f 2 -d " " > $DIFF_FILE
DIFFERENCES=$(wc -l $DIFF_FILE | cut -f 1 -d " ")

if [ $DIFFERENCES > 0 ] ; then
    rm $OLD
    COUNTDIFF=1
    for i in $(seq 1 $DIFFERENCES) ; do
        RUN=$(sed "${COUNTDIFF}q;d" $DIFF_FILE)

        RUNLOC=/jumbo/WorkingDir/Runs
        mkdir ${RUNLOC}/$RUN

        module load bcl2fastq/2.17.1.14

        nohup bcl2fastq  --runfolder-dir /jumbo/Nextseq500175/$RUN -o ${RUNLOC}/$RUN -r4 -p4 -d4 -w4 --barcode-mismatches 1 --no-lane-splitting --min-log-level TRACE > ${RUNLOC}/${RUN}/${RUN}_nohup.txt
        cp /jumbo/Nextseq500175/${RUN}/SampleSheet.csv ${RUNLOC}/${RUN}/.
        time /jumbo/WorkingDir/Programs/NextSeq/NS_FastqMergeQC_3.pl $RUN >> ${RUNLOC}/${RUN}/${RUN}_nohup.txt
        time /jumbo/WorkingDir/Programs/NextSeq/NS_createRunReport_3.pl MD $RUN >> /jumbo/WorkingDir/Runs/${RUN}/${RUN}_nohup.txt

        COUNTDIFF=$(($COUNTDIFF+1))
        INITALS=$(grep -e "Investigator Name," ${RUNLOC}/${RUN}/SampleSheet.csv | cut -f2 -d",")
        EXPERIMENT_NAME=$(grep -e "Experiment Name," ${RUNLOC}/${RUN}/SampleSheet.csv | cut -f2 -d",")
        EMAIL_ADDRESS=$(grep -e "${INITIALS}|" /jumbo/apps/misc-scripts/nextseq_cronjob/investigators/investigators.txt | cut -d"|" -f2)
        INVESTIGATOR_NAME=$(grep -e "${INITIALS}|" /jumbo/apps/misc-scripts/nextseq_cronjob/investigators/investigators.txt | cut -d"|" -f3)
        EMAIL=$"""From: \"NextSeq500175\" <NextSeq500175.noreply@medair.sahlgrenska.gu.se>
To: \"$INVESTIGATOR_NAME\" <$EMAIL_ADDRESS>
Subject: Your Sequencing job $EXPERIMENT_NAME has finished!
MIME-Version: 1.0
Content-Type: text/plain

Find data and fastqc-report at: /jumbo/WorkingDir/Runs/${RUN}

$EXPERIMENT_NAME finished at `date`
"""

    echo "$EMAIL" | /usr/sbin/sendmail -i -t

done
fi
rm $DIFF_FILE

