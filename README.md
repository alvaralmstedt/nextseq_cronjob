# nextseq_cronjob

This script will be run as a cron job, every five minutes. It will then check if there are any new sequencing batches comepleted and convert them from bcl to fastq, run fastqc and send the report as a pdf to a submitter.
