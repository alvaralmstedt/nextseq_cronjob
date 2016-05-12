#!/bin/bash -l




#_______________

cd /jumbo/WorkingDir/Runs
mkdir $RUN


module load bcl2fastq/2.17.1.14

nohup bcl2fastq  --runfolder-dir /jumbo/Nextseq500175/$RUN -o /jumbo/WorkingDir/Runs/$RUN -r4 -p4 -d4 -w4 --barcode-mismatches 1 --no-lane-splitting --min-log-level TRACE > /jumbo/WorkingDir/Runs/${RUN}/${RUN}_nohup.txt
cp /jumbo/Nextseq500175/${RUN}/SampleSheet.csv ${RUN}/.
time /jumbo/WorkingDir/Programs/NextSeq/NS_FastqMergeQC_3.pl $RUN >> /jumbo/WorkingDir/Runs/${RUN}/${RUN}_nohup.txt
time /jumbo/WorkingDir/Programs/NextSeq/NS_createRunReport_3.pl MD $RUN >> /jumbo/WorkingDir/Runs/${RUN}/${RUN}_nohup.txt











#______________
