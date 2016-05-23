#!/bin/bash -l

# Print some informative error messages
err() {
        echo "$1 exited unexpectedly";
            exit 1;
}

# Function for checking the exit code of a child process
checkExit() {
if [ "$1" == "0" ]; then
    echo "[Done] $2 `date`";
else
    err "[Error] $2 returned non-0 exit code $1";
fi
}

sendMail() {       #Email to be sent
	EMAIL=$"""From: \"Nextseq501351\" <Nextseq501351.noreply@medair.sahlgrenska.gu.se>
To: \"$1\" <$2>
Subject: Your Sequencing job $3 has finished!
MIME-Version: 1.0
Content-Type: text/plain

$4

$3 finished at `date`
Your sequencing run was completed with status: $5

"""
    #Send email
    echo "$EMAIL" | /usr/sbin/sendmail -i -t
    checkExit $? "sendmail to $EMAIL_ADDRESS"
}

#Format the date output
DATE=$(date | sed 's/ /_/g' | sed 's/:/_/'g | cut -d"_" -f-6)

#Check status of base directory
OLD=$(readlink -f /jumbo/apps/misc-scripts/nextseq_cronjob/nextseq_501351_dirlist/*)

NS51=/jumbo/Nextseq501351

#Create temporary file list
ls -d $NS51/*/ > /jumbo/apps/misc-scripts/nextseq_cronjob/nextseq_501351_dirlist/lsNS51.${DATE}.tmp
checkExit $? "ls1"

#New file list
NEW=/jumbo/apps/misc-scripts/nextseq_cronjob/nextseq_501351_dirlist/lsNS51.${DATE}.tmp

TMP_LOC=/jumbo/apps/misc-scripts/nextseq_cronjob/tmp-files/nextseq_501351

#Check differences between new and old file list as save
diff $OLD $NEW | grep ">" | cut -f 2 -d " " > ${TMP_LOC}/differences_$DATE
checkExit $? "diff1"

DIFFERENCES=$(wc -l ${TMP_LOC}/differences_$DATE | cut -f 1 -d " ")

#If there are any changes, enter this if statement
if [ $DIFFERENCES > 0 ] ; 
then
	#Remove old filelist
	rm $OLD
	checkExit $? "rm1"
	COUNTDIFF=1
	
	#-------------START LOOP FOR EVERY NEW SEQUENCING RUN DISCOVERED-------->

	#For every new directory in the new filelist
	for i in $(seq 1 $DIFFERENCES) ; do
	RUN=$(sed "${COUNTDIFF}q;d" ${TMP_LOC}/differences_$DATE | cut -d"/" -f4)
	
	#Check if file has CompletionStatus=Completed
	while [ ${NS75}/${RUN}/RunCompletionStatus.xml == 0 ]
	do
        echo "Sequencing job:$RUN detected but still in progress. Waiting for completion signal."
        sleep 20m
	done	
	STATUSCHECK=$(grep -e "<CompletionStatus>" ${NS75}/${RUN}/RunCompletionStatus.xml | cut -d">" -f2 | cut -d"<" -f1)
	checkExit $? "While checking status of sequencingjob"
	
	#Check if run has finished being transferred
	DSIZE1=0
	DSIZE2=1
	while [ $DSIZE1 != $DSIZE2 ]
	do
		DSIZE1=$(du -s ${NS51}/${RUN} | cut -f1)
		sleep 5m
		DSIZE2=$(du -s	${NS51}/${RUN} | cut -f1)
	done
        checkExit $? "While dirsize check"

	#----------CHECK IF SAMPLESHEET EXISTS-------------->
	
        SLEEPCOUNT=0
        while [ ${NS51}/${RUN}/SampleSheet.csv == 0 ]
        do
        SLEEPCOUNT=$((${SLEEPCOUNT}+1))
        sleep 20m
        if [ $SLEEPCOUNT == 100 ] ;
       	then
        	MAILNOTE=$(echo "Warning: Your run seems to have completed but no SampleSheet.csv was found in: /jumbo/Nextseq501351/${RUN}, you have 27,777 days to provide a correctly formatted SampleSheet.csv. After that bcl2fastq and fastqc has to be run manually")
        	EMAIL_ADDRESS=$(grep -e "ADMIN|" /jumbo/apps/misc-scripts/nextseq_cronjob/investigators/investigators.txt | cut -d"|" -f2)
        	INVESTIGATOR_NAME=$(grep -e "ADMIN|" /jumbo/apps/misc-scripts/nextseq_cronjob/investigators/investigators.txt | cut -d"|" -f3)
        	EXPERIMENT_NAME=$(echo "Unknown")
        	sendMail $INVESTIGATOR_NAME $EMAIL_ADDRESS $EXPERIMENT_NAME $MAILNOTE $STATUSCHECK
        	checkExit $? "While looking for SampleSheet.csv ${RUN} for 2000m"
         fi
         checkExit $? "While looking for SampleSheet.csv ${RUN} every 20min x ${SLEEPCOUNT} times"
         if [ $SLEEPCOUNT == 2000 ] ;
         then
         	MAILNOTE=$(echo "Warning: Automatic bcl2fastq and fastqc of data in run: $RUN was abandoned after 27 days due to reason: No SampleSheet.csv")
        	sendMail $INVESTIGATOR_NAME $EMAIL_ADDRESS $EXPERIMENT_NAME $MAILNOTE $STATUSCHECK
        	checkExit $? "While looking for SampleSheet.csv ${RUN} for 27 days - now abandoned"
        	rm ${TMP_LOC}/differences_$DATE
		exit
         fi
         done


	#------------REMOVE ILLEGAL CHARACTERS FROM SAMPLESHEET---------->
	#Copy the samplesheet to be modified
	cp /jumbo/Nextseq501351/${RUN}/SampleSheet.csv ${TMP_LOC}/old${DATE}.csv
	checkExit $? "cp samplesheet1"
   
	#Format space characters
	DATALINE=$(cat -n ${TMP_LOC}/old${DATE}.csv | grep -e "Data" | sed -r 's/ +/ /g' | cut -f1)
    
	#Skip column descriptors
	UPTO=$(($DATALINE+1))
    
	#Parse out only lines under [Data] from sample sheet
	sed -n "$UPTO"',$p' ${TMP_LOC}/old${DATE}.csv > ${TMP_LOC}/DATA_tmp${DATE}
	checkExit $? "sed datafield"
    
	#List illegal characters
	ILLEGALCHARS=$(echo "?- -(-)-\[-]-\/-\\-=-+-<->-:-;-\"-'-*-\^-|-&-\.")
    
	#Loop over each illegal character
	for k in $(seq 1 21);
	do
    
	CHAR=$(echo $ILLEGALCHARS | cut -d"-" -f${k})
	if [ "$CHAR" == "\\" ] ;
	then
	    CHAR=\\\\
	fi
	
	#Replace illegal character with underscore
	sed -i "s/${CHAR}/_/g" ${TMP_LOC}/DATA_tmp${DATE}
	done
	checkExit $? "illegalcharacters"		

	#Put unmodified lines from old shamples sheet to new
	head -n${DATALINE} ${TMP_LOC}/old${DATE}.csv > ${TMP_LOC}/SampleSheet${DATE}.csv
	checkExit $? "head old csv"

	#Append modified lines to new sample sheet
	cat ${TMP_LOC}/DATA_tmp${DATE} >> ${TMP_LOC}/SampleSheet${DATE}.csv
	checkExit $? "cat DATA_tmp"

	#Replace old sample sheet with new
	cp ${TMP_LOC}/SampleSheet${DATE}.csv /jumbo/Nextseq501351/${RUN}/SampleSheet.csv
	checkExit $? "copy samplesheet2"

	#-------------------RUN BCL2FASTQ AND FASTQC-------------------->

	RUNLOC=/jumbo/WorkingDir/Runs/${RUN}
	mkdir $RUNLOC
	module load bcl2fastq/2.17.1.14
	module load java
	checkExit $? "module load"

	#Run bcl2fastq
	nohup bcl2fastq  --runfolder-dir /jumbo/Nextseq501351/$RUN -o ${RUNLOC} -r4 -p4 -d4 -w4 --barcode-mismatches 1 --no-lane-splitting --min-log-level TRACE > ${RUNLOC}/${RUN}_nohup.txt
	checkExit $? "bcl2fastq"

	#Move sample sheet to run location
	cp /jumbo/Nextseq501351/${RUN}/SampleSheet.csv ${RUNLOC}/
	checkExit $? "cp samplesheet"

	#Run NS_FastqMergeQC_3.pl
	cd /jumbo/WorkingDir/Runs/
	time /jumbo/WorkingDir/Programs/NextSeq/NS_FastqMergeQC_3.pl $RUN
	checkExit $? "NS_FastMergeQC_3.pl"

	#Run NS_createRunReport_3.pl
	cd $RUNLOC
	time /jumbo/WorkingDir/Programs/NextSeq/NS_createRunReport_3.pl MD $RUN
	checkExit $? "NS_createRunReport_3.pl"

	#Save location of resultfiles to string
	MAILNOTE=$(echo "Find data and fastqc-report at: ${RUNLOC}")

	COUNTDIFF=$(($COUNTDIFF+1))
	
	#Save initials of the Investigator to string
	INITIALS=$(grep -e "Investigator Name," ${RUNLOC}/SampleSheet.csv | cut -f2 -d"," | sed 's/\r//')

	#Save experiment name to string
	EXPERIMENT_NAME=$(grep -e "Experiment Name," ${RUNLOC}/SampleSheet.csv | cut -f2 -d",")

	#Fetch email address from file containing list of initials, email adresses and names
	EMAIL_ADDRESS=$(grep -e "${INITIALS}|" /jumbo/apps/misc-scripts/nextseq_cronjob/investigators/investigators.txt | cut -d"|" -f2)

	#Fetch Investigator name from file containing list of initials, email addresses and names
	INVESTIGATOR_NAME=$(grep -e "${INITIALS}|" /jumbo/apps/misc-scripts/nextseq_cronjob/investigators/investigators.txt | cut -d"|" -f3)
	checkExit $? "grep1"
	
	#Remove TMPfiles
	rm ${TMP_LOC}/SampleSheet${DATE}.csv
	rm ${TMP_LOC}/DATA_tmp${DATE}
	rm ${TMP_LOC}/old${DATE}.csv

    	sendMail $INVESTIGATOR_NAME $EMAIL_ADDRESS $EXPERIMENT_NAME $MAILNOTE $STATUSCHECK
    
	done
	#-------------------------------MAJOR FOR LOOP FINISHED---------------------------------------------->
fi

#Remove differences file
rm ${TMP_LOC}/differences_$DATE
checkExit $? "rm_differences"

#Keep log filesize in check
echo "`tail -100000 /jumbo/Nextseq501351/cron_seqdataanalysis.log`" > /jumbo/Nextseq501351/cron_seqdataanalysis.log
checkExit $? "tail logfile"
