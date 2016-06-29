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

sendMail() {
    EMAIL=$"""From: \"Miseq2776\" <Miseq2776.noreply@medair.sahlgrenska.gu.se>
To: \"$1\" <$2>
Subject: Your Sequencing job $3 has finished!
MIME-Version: 1.0
Content-Type: text/plain
 
$4

Script-run of $3 finished at `date`
Your sequencing run was completed at: $5

"""
    #Send email
    echo "$EMAIL" | /usr/sbin/sendmail -i -t
    checkExit $? "sendmail to $EMAIL_ADDRESS"
}

muttMail () {
    MAIL=$"""
    
    $4

    Script-run of: $1 finished at `date`
    Your sequencing run was completed at: $5

    """
echo "$MAIL" | mutt -s "$1" -e "my_hdr From: Miseq2776 <Miseq2776.noreply@medair.sahlgrenska.gu.se>" -a $2 -- "$6 <$3>"

}

#Format the date output
DATE=$(date | sed 's/ /_/g' | sed 's/:/_/'g | cut -d"_" -f-6)

#Check status of base directory
OLD=$(readlink -f /jumbo/apps/misc-scripts/miseq2776_cronjob/miseq2776_dirlist/*)

M2776=/jumbo/Miseq2776

#Create temporary file list
ls -d $M2776/*/ > /jumbo/apps/misc-scripts/miseq2776_cronjob/miseq2776_dirlist/lsM2776.${DATE}.tmp
checkExit $? "ls1"

#New file list
NEW=/jumbo/apps/misc-scripts/miseq2776_cronjob/miseq2776_dirlist/lsM2776.${DATE}.tmp

TMP_LOC=/jumbo/apps/misc-scripts/miseq2776_cronjob/tmp-files/miseq_2776

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
	
	#----------CHECK IF SAMPLESHEET EXISTS-------------->

	#Check if SampleSheet exists, and only continue if investigator is EM
	while [ ! -f ${M2776}/${RUN}/SampleSheet.csv ]
        do
	SLEEPCOUNT=$((${SLEEPCOUNT}+1))
        sleep 20m
        if [ $SLEEPCOUNT == 200 ] ;
        then
            	MAILNOTE=$(echo "Warning: Your sequencing run has been detected, but no SampleSheet.csv was found in: /jumbo/Miseq2776/${RUN}/")
                EXPERIMENT_NAME=$(echo "Unknown")
                INVESTIGATOR_NAME2=$(grep -e "ADMIN|" /jumbo/apps/misc-scripts/miseq2776_cronjob/investigators/investigators.txt | cut -d"|" -f3)
                EMAIL_ADDRESS2=$(grep -e "ADMIN|" /jumbo/apps/misc-scripts/miseq2776_cronjob/investigators/investigators.txt | cut -d"|" -f2)
                sendMail "${INVESTIGATOR_NAME}" "${EMAIL_ADDRESS}" "${EXPERIMENT_NAME}" "${MAILNOTE}" "${STATUSCHECK}"
                sendMail "${INVESTIGATOR_NAME2}" "${EMAIL_ADDRESS2}" "${EXPERIMENT_NAME}" "${MAILNOTE}" "${STATUSCHECK}"
                checkExit $? "While looking for SampleSheet.csv ${RUN} for 4000m"
        fi
	done
	
	COUNTDIFF=$(($COUNTDIFF+1))

	#Save initials of the Investigator to string
        INITIALS=$(grep -e "Investigator Name," ${M2776}/${RUN}/SampleSheet.csv | cut -f2 -d"," | sed 's/\r//')

        #Save experiment name to string
        EXPERIMENT_NAME=$(grep -e "Experiment Name," ${M2776}/${RUN}/SampleSheet.csv | cut -f2 -d"," | sed 's/\r//')
	
	if [ "${INITIALS}" != "EM" ] ;
	then
		checkExit $? "Investigator in ${RUN} is not EM, ignoring run."
		continue
	fi	
		
	#----------CHECK IF RUN HAS FINISHED BEING TRANSFERRED-------------->

	#Check if file /CompletedJobInfo.xml exists
	while [ ! -f ${M2776}/${RUN}/CompletedJobInfo.xml ]
	do
        echo "Sequencing job:$RUN detected but still in progress. Waiting for completion signal."
        sleep 20m
	done	
    	STATUSCHECK=$(grep -e "<CompletionTime>" ${M2776}/${RUN}/CompletedJobInfo.xml | cut -d">" -f2 | cut -d"<" -f1)
    	checkExit $? "While checking status of sequencingjob ${RUN}"

	#Check if run has finished being transferred
	DSIZE1=0
	DSIZE2=1
	while [ $DSIZE1 != $DSIZE2 ]
	do
		DSIZE1=$(du -s ${M2776}/${RUN} | cut -f1)
		sleep 10m
		DSIZE2=$(du -s	${M2776}/${RUN} | cut -f1)
	done
        checkExit $? "While dirsize check ${RUN}"
	
	
	#------------REMOVE ILLEGAL CHARACTERS FROM SAMPLESHEET---------->
	
	#Copy the samplesheet to be modified
        cp -R ${M2776}/${RUN}/SampleSheet.csv ${TMP_LOC}/old${DATE}.csv
        checkExit $? "cp samplesheet1"
        #Format space characters
        DATALINE=$(cat -n ${TMP_LOC}/old${DATE}.csv | grep -e "Data" | sed -r 's/ +/ /g' | cut -f1)
            
        #Skip column descriptors
        UPTO=$(($DATALINE+1))
            
        #Parse out only lines under [Data] from sample sheet
        sed -n "$UPTO"',$p' ${TMP_LOC}/old${DATE}.csv > ${TMP_LOC}/DATA_tmp${DATE}
        checkExit $? "sed datafield"
            
        #List illegal characters
        ILLEGALCHARS=$(echo "?- -(-)-\[-]-\/-\\-=-+-<->-:-;-\"-'-*-\^-|-&-\.-å-ä-ö")
    
	#Loop over each illegal character
	for k in $(seq 1 24);
	do
	REPLACE=$(echo "_")    
	CHAR=$(echo $ILLEGALCHARS | cut -d"-" -f${k})
	if [ "$CHAR" = "\\" ] ;
	then
		CHAR=\\\\
	fi
	if [ "$CHAR" = "å" ] || [ "$CHAR" = "ä" ] ;
	then
		REPLACE=$(echo "a")
	fi
		if [ "$CHAR" = "ö" ] ;
        then
                REPLACE=$(echo "o")
        fi
	
	#Replace illegal character with underscore
	sed -i "s/${CHAR}/${REPLACE}/g" ${TMP_LOC}/DATA_tmp${DATE}
	done
	checkExit $? "illegalcharacters"		

	#Put unmodified lines from old shamples sheet to new
	head -n${DATALINE} ${TMP_LOC}/old${DATE}.csv > ${TMP_LOC}/SampleSheet${DATE}.csv
	checkExit $? "head old csv"

	#Append modified lines to new sample sheet
	cat ${TMP_LOC}/DATA_tmp${DATE} >> ${TMP_LOC}/SampleSheet${DATE}.csv
	checkExit $? "cat DATA_tmp"

	#Remove potential excess ","
	ROWSTOKEEP=$(cat -n ${TMP_LOC}/SampleSheet${DATE}.csv | grep -e ",,,,,," | grep -e "\[Data\]" -A1 | sed "2q;d" | sed 's/^ *//' | cut -f1)
	if [ ! -z "$ROWSTOKEEP" ] ;
	then
		ROWSTOKEEP=$((${ROWSTOKEEP}-1))
		echo "`head -n $ROWSTOKEEP ${TMP_LOC}/SampleSheet${DATE}.csv | cut -d"," -f-10`" > ${TMP_LOC}/SampleSheet${DATE}.csv
	fi
	
	#Replace old sample sheet with new
	cp ${TMP_LOC}/SampleSheet${DATE}.csv  ${M2776}/${RUN}/SampleSheet.csv
	checkExit $? "copy samplesheet2"

	#-------------------MOVE RUN TO /jumbo/WorkingDir/B16-058/------------>
	
	RUNLOC=/jumbo/WorkingDir/B16-058/${RUN}/Data/Intensities/BaseCalls
	XMLLOC=/jumbo/WorkingDir/B16-058/${RUN}
	SAVELOC=/jumbo/WorkingDir/B16-058/shared
	cp -R ${M2776}/${RUN} /jumbo/WorkingDir/B16-058/
	cp /jumbo/WorkingDir/B16-058/bin/Miseq_0mm.pl $RUNLOC

	#-------------------RUN Miseq_0mm.pl---------------------->

	cd $RUNLOC
	$RUNLOC/Miseq_0mm.pl $RUN EM

	#-------------------SEND MAIL AND REMOVE TEMPORARY FILES------------>

	#Fetch email address from file containing list of initials, email adresses and names
	EMAIL_ADDRESS=$(grep -e "${INITIALS}|" /jumbo/apps/misc-scripts/miseq2776_cronjob/investigators/investigators.txt | cut -d"|" -f2)

	#Fetch Investigator name from file containing list of initials, email addresses and names
	INVESTIGATOR_NAME=$(grep -e "${INITIALS}|" /jumbo/apps/misc-scripts/miseq2776_cronjob/investigators/investigators.txt | cut -d"|" -f3)
	checkExit $? "grep1"
	#Remove TMPfiles
	rm ${TMP_LOC}/SampleSheet${DATE}.csv
	rm ${TMP_LOC}/DATA_tmp${DATE}
	rm ${TMP_LOC}/old${DATE}.csv
	

	#Save location of resultfiles to string
        MAILNOTE=$(echo "Your run: $RUN seem to have been demultiplexed and QC:d succesfully. Find results at: ${SAVELOC}")
	
	#Check if analysis completed as planned
	COUNTFASTQ=$(ls $RUNLOC/Fastq_1mm | grep -e "fastq.gz" | grep -v "Undetermined" | wc -l | cut -d" " -f1)
	COMPLETECHECK=$(ls $RUNLOC/Fastqc_0mm | grep -e "fastqc.html" | wc -l | cut -d" " -f1)
	if [ $COUNTFASTQ != $COMPLETECHECK ] ;
	then
		MAILNOTE=$(echo "Demultiplexing and QC of $RUN seem to have failed. See attached log-file")
		muttMail "${EXPERIMENT_NAME}" "${RUNLOC}/${RUN}.cero.log" "${EMAIL_ADDRESS}" "${MAILNOTE}" "${STATUSCHECK}" "${INVESTIGATOR_NAME}"
	else
		muttMail "${EXPERIMENT_NAME}" "${XMLLOC}/${RUN}.xlsx" "${EMAIL_ADDRESS}" "${MAILNOTE}" "${STATUSCHECK}" "${INVESTIGATOR_NAME}"
	        checkExit $? "muttMail sent to ${INVESTIGATOR_NAME} regarding experiment: ${EXPERIMENT_NAME}"
		mv ${RUNLOC}/${RUN}.cero.* /jumbo/WorkingDir/B16-058/logs
		mv /jumbo/WorkingDir/B16-058/$RUN $SAVELOC
	fi

	done
	#-------------------------------MAJOR FOR LOOP FINISHED---------------------------------------------->
fi
#Remove differences file
rm ${TMP_LOC}/differences_$DATE
checkExit $? "rm_differences"

#Keep log filesize in check
echo "`tail -100000 /jumbo/apps/misc-scripts/miseq2776_cronjob/cron_seqdataanalysis.log`" > /jumbo/apps/misc-scripts/miseq2776_cronjob/cron_seqdataanalysis.log
checkExit $? "tail logfile"
