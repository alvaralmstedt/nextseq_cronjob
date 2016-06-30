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
echo "$MAIL" | mutt -s "$1" -e "my_hdr From: HiScan <HiScan.noreply@medair.sahlgrenska.gu.se>" -a $2 -- "$6 <$3>"

}

#Format the date output
DATE=$(date | sed 's/ /_/g' | sed 's/:/_/'g | cut -d"_" -f-6)

#Check status of base directory
OLD=$(readlink -f /jumbo/apps/misc-scripts/hiscan_cronjob/dirlists/*)

HISCAN=/jumbo/HiScan

#Create temporary file list
ls -d $HISCAN/*/ > /jumbo/apps/misc-scripts/hiscan_cronjob/dirlists/lsHiScan.${DATE}.tmp
checkExit $? "ls1"

#New file list
NEW=/jumbo/apps/misc-scripts/hiscan_cronjob/dirlists/lsHiScan.${DATE}.tmp

TMP_LOC=/jumbo/apps/misc-scripts/hiscan_cronjob/tmp-files

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
	

	#For every new directory in the new filelist
	for i in $(seq 1 $DIFFERENCES) ; do
	    RUN=$(sed "${COUNTDIFF}q;d" ${TMP_LOC}/differences_$DATE | cut -d"/" -f4)
    
    #Check if run has finished being transferred
    DSIZE1=0
    DSIZE2=1
    while [ $DSIZE1 != $DSIZE2 ]
    do
        DSIZE1=$(du -s ${HISCAN}/${RUN} | cut -f1)
        sleep 10m
        DSIZE2=$(du -s  ${HISCAN}/${RUN} | cut -f1)
    done
    checkExit $? "While dirsize check ${RUN}"

    RUNLOC=/jumbo/WorkingDir/${RUN}/shared
    cp -R ${HISCAN}/${RUN} ${RUNLOC}
    checkExit ? "cp -R to $RUNLOC"
    done
fi
