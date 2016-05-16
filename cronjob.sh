#!/bin/bash -l


DATE=$(date | sed 's/ /_/g' | sed 's/:/_/'g | cut -d"_" -f-6)
OLD=$(readlink -f /jumbo/apps/misc-scripts/nextseq_cronjob/nextseq_500175_dirlist/*)

NS75=/jumbo/Nextseq500175

ls $NS75 > /jumbo/apps/misc-scripts/nextseq_cronjob/nextseq_500175_dirlist/lsNS75.${DATE}.tmp
NEW=/jumbo/apps/misc-scripts/nextseq_cronjob/nextseq_500175_dirlist/lsNS75.${DATE}.tmp

TMP_LOC=/jumbo/apps/misc-scripts/nextseq_cronjob/tmp-files/nextseq_500175
diff $OLD $NEW | grep ">" | cut -f 2 -d " " > ${TMP_LOC}/differences_$DATE
DIFFERENCES=$(wc -l ${TMP_LOC}/differences_$DATE | cut -f 1 -d " ")

if [ $DIFFERENCES > 0 ] ; 
then
	rm $OLD
	COUNTDIFF=1
	cd /jumbo/WorkingDir/Runs
	
    	for i in $(seq 1 $DIFFERENCES) ; do
        RUN=$(sed "${COUNTDIFF}q;d" $DIFF_FILE)
        
	#--------CHECK IF SAMPLESHEET EXISTS-------------->

	SHEETCHECK=(ls /jumbo/Nextseq500175/${RUN} | grep -e "SampleSheet.csv)
        if [ !-z $SHEETCHECK ] ; 
	then
		
		#------------REMOVE ILLEGAL CHARACTERS FROM SAMPLESHEET---------->
		
		cp /jumbo/Nextseq500175/${RUN}/SampleSheet.csv ${TMP_LOC}/old.csv
		DATALINE=$(cat -n ${TMP_LOC}/old.csv | grep -e "Data" | sed -r 's/ +/ /g' | cut -f1)
		UPTO=$(($DATALINE-1))
		sed -n "$DATALINE"',$p' ${TMP_LOC}/old.csv > ${TMP_LOC}/DATA_tmp
		ILLEGALCHARS=$(echo "?- -(-)-[-]-/-\\-=-+-<->-:-;-\"-'-,-*-^-|-&-.")
		for k in $(seq 1 22);
		do
		CHAR=$(echo $ILLEGALCHARS | cut -f${k})
		if [ "$CHAR" == "\" ] ;
		then
			CHAR=\\\\
		fi
		
		head -n${UPTO} ${TMP_LOC}/old.csv > ${TMP_LOC}/old.csv
            	
		#-------------------RUN BCL2FASTQ AND FASTQC-------------------->
		mkdir $RUN
                RUNLOC=/jumbo/WorkingDir/Runs
                module load bcl2fastq/2.17.1.14


		nohup bcl2fastq  --runfolder-dir /jumbo/Nextseq500175/$RUN -o ${RUNLOC}/$RUN -r4 -p4 -d4 -w4 --barcode-mismatches 1 --no-lane-splitting --min-log-level TRACE > ${RUNLOC}/${RUN}/${RUN}_nohup.txt
        	cp ${TMP_LOC}/SampleSheet.csv ${RUNLOC}/${RUN}/.
        	time /jumbo/WorkingDir/Programs/NextSeq/NS_FastqMergeQC_3.pl $RUN >> ${RUNLOC}/${RUN}/${RUN}_nohup.txt
        	time /jumbo/WorkingDir/Programs/NextSeq/NS_createRunReport_3.pl MD $RUN >> ${RUNLOC}/${RUN}_nohup.txt

		MAILNOTE=$(echo "Find data and fastqc-report at: ${RUNLOC}/${RUN}")

        	COUNTDIFF=$(($COUNTDIFF+1))
		INITALS=$(grep -e "Investigator Name," ${RUNLOC}/${RUN}/SampleSheet.csv | cut -f2 -d",")
        	EXPERIMENT_NAME=$(grep -e "Experiment Name," ${RUNLOC}/${RUN}/SampleSheet.csv | cut -f2 -d",")
        	EMAIL_ADDRESS=$(grep -e "${INITIALS}|" /jumbo/apps/misc-scripts/nextseq_cronjob/investigators/investigators.txt | cut -d"|" -f2)
        	INVESTIGATOR_NAME=$(grep -e "${INITIALS}|" /jumbo/apps/misc-scripts/nextseq_cronjob/investigators/investigators.txt | cut -d"|" -f3)
	else
            	EMAIL_ADDRESS=$(grep -e "ADMIN|" /jumbo/apps/misc-scripts/nextseq_cronjob/investigators/investigators.txt | cut -d"|" -f2)
                INVESTIGATOR_NAME=$(grep -e "ADMIN|" /jumbo/apps/misc-scripts/nextseq_cronjob/investigators/investigators.txt | cut -d"|" -f3)
		MAILNOTE=$(echo "Error: Bcl2fastq and FastQC did not run - no SampleSheet.csv in $RUN")
	fi
	EMAIL=$"""From: \"NextSeq500175\" <NextSeq500175.noreply@medair.sahlgrenska.gu.se>
To: \"$INVESTIGATOR_NAME\" <$EMAIL_ADDRESS>
Subject: Your Sequencing job $EXPERIMENT_NAME has finished!
MIME-Version: 1.0
Content-Type: text/plain

$MAILNOTE

$EXPERIMENT_NAME finished at `date`
"""

    echo "$EMAIL" | /usr/sbin/sendmail -i -t

done
fi
rm ${TMP_LOC}/differences_$DATE

