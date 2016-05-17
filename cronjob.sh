#!/bin/bash -l

# Function for checking the exit code of a child process
checkExit() {
if [ "$1" == "0" ]; then
    echo "[Done] $2 `date`";
else
    err "[Error] $2 returned non-0 exit code $1";
fi
}

DATE=$(date | sed 's/ /_/g' | sed 's/:/_/'g | cut -d"_" -f-6)

OLD=$(readlink -f /jumbo/apps/misc-scripts/nextseq_cronjob/nextseq_500175_dirlist/*)

NS75=/jumbo/Nextseq500175

ls $NS75 > /jumbo/apps/misc-scripts/nextseq_cronjob/nextseq_500175_dirlist/lsNS75.${DATE}.tmp
checkexit $? "ls1"

NEW=/jumbo/apps/misc-scripts/nextseq_cronjob/nextseq_500175_dirlist/lsNS75.${DATE}.tmp

TMP_LOC=/jumbo/apps/misc-scripts/nextseq_cronjob/tmp-files/nextseq_500175

diff $OLD $NEW | grep ">" | cut -f 2 -d " " > ${TMP_LOC}/differences_$DATE
checkexit $? "diff1"

DIFFERENCES=$(wc -l ${TMP_LOC}/differences_$DATE | cut -f 1 -d " ")

if [ $DIFFERENCES > 0 ] ; 
then
	rm $OLD
    checkexit $? "rm1"
	COUNTDIFF=1
	cd /jumbo/WorkingDir/Runs
	
    	for i in $(seq 1 $DIFFERENCES) ; do
        RUN=$(sed "${COUNTDIFF}q;d" ${TMP_LOC}/differences_$DATE)
        
	    #--------CHECK IF SAMPLESHEET EXISTS-------------->

	        SHEETCHECK=$(ls /jumbo/Nextseq500175/${RUN} | grep -e "SampleSheet.csv")

            if [ ! -z "$SHEETCHECK" ] ; 
	        then
		
		    #------------REMOVE ILLEGAL CHARACTERS FROM SAMPLESHEET---------->
            
            cp /jumbo/Nextseq500175/${RUN}/SampleSheet.csv ${TMP_LOC}/old.csv
            checkexit $? "cp samplesheet1"

            DATALINE=$(cat -n ${TMP_LOC}/old.csv | grep -e "Data" | sed -r 's/ +/ /g' | cut -f1)
            
            UPTO=$(($DATALINE+1))
            
            sed -n "$UPTO"',$p' ${TMP_LOC}/old.csv > ${TMP_LOC}/DATA_tmp
            checkexit $? "sed datafield"

            ILLEGALCHARS=$(echo "?- -(-)-\[-]-\/-\\-=-+-<->-:-;-\"-'-*-\^-|-&-\.")
            
            for k in $(seq 1 21);
            do
            
            CHAR=$(echo $ILLEGALCHARS | cut -d"-" -f${k})
                if [ "$CHAR" == "\\" ] ;
                then
                    CHAR=\\\\
                fi
                checkexit $? "illegalcharacters"
                
                sed -i "s/${CHAR}/_/g" ${TMP_LOC}/DATA_tmp
                checkexit $? "sed underscores"
		done
		
        head -n${DATALINE} ${TMP_LOC}/old.csv > ${TMP_LOC}/SampleSheet.csv
        checkexit $? "head old csv"

        cat ${TMP_LOC}/DATA_tmp >> ${TMP_LOC}/SampleSheet.csv
		checkexit $? "cat DATA_tmp"

        cp ${TMP_LOC}/SampleSheet.csv /jumbo/Nextseq500175/${RUN}/.
        checkexit $? "copy samplesheet2"

		#-------------------RUN BCL2FASTQ AND FASTQC-------------------->

		mkdir $RUN
        RUNLOC=/jumbo/WorkingDir/Runs
        module load bcl2fastq/2.17.1.14
        checkexit $? "module load"

		nohup bcl2fastq  --runfolder-dir /jumbo/Nextseq500175/$RUN -o ${RUNLOC}/$RUN -r4 -p4 -d4 -w4 --barcode-mismatches 1 --no-lane-splitting --min-log-level TRACE > ${RUNLOC}/${RUN}/${RUN}_nohup.txt
		checkexit $? ""

        cp /jumbo/Nextseq500175/${RUN}/SampleSheet.csv ${RUNLOC}/${RUN}/.
		checkexit $? "cp samplesheet"

        time /jumbo/WorkingDir/Programs/NextSeq/NS_FastqMergeQC_3.pl $RUN
        checkexit $? "NS_FastMergeQC_3.pl"

        time /jumbo/WorkingDir/Programs/NextSeq/NS_createRunReport_3.pl MD $RUN
        checkexit $? "NS_createRunReport_3.pl"

		MAILNOTE=$(echo "Find data and fastqc-report at: ${RUNLOC}/${RUN}")

        COUNTDIFF=$(($COUNTDIFF+1))
		INITALS=$(grep -e "Investigator Name," ${RUNLOC}/${RUN}/SampleSheet.csv | cut -f2 -d",")
        EXPERIMENT_NAME=$(grep -e "Experiment Name," ${RUNLOC}/${RUN}/SampleSheet.csv | cut -f2 -d",")
        EMAIL_ADDRESS=$(grep -e "${INITIALS}|" /jumbo/apps/misc-scripts/nextseq_cronjob/investigators/investigators.txt | cut -d"|" -f2)
        INVESTIGATOR_NAME=$(grep -e "${INITIALS}|" /jumbo/apps/misc-scripts/nextseq_cronjob/investigators/investigators.txt | cut -d"|" -f3)
        checkexit $? "grep1"
	else
        EMAIL_ADDRESS=$(grep -e "ADMIN|" /jumbo/apps/misc-scripts/nextseq_cronjob/investigators/investigators.txt | cut -d"|" -f2)
        INVESTIGATOR_NAME=$(grep -e "ADMIN|" /jumbo/apps/misc-scripts/nextseq_cronjob/investigators/investigators.txt | cut -d"|" -f3)
		MAILNOTE=$(echo "Error: Bcl2fastq and FastQC did not run - no SampleSheet.csv in ${RUN}")
        checkexit $? "grep2"
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
    checkexit $? "sendmail"
        done
fi
rm ${TMP_LOC}/differences_$DATE
checkexit $? "rm_differences"
