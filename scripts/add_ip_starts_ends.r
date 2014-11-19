# add_ip_starts_ends.r
#
# Takes a directory of measurement tables
# and a directory of tables with utterance timings
# and annotates the tables in the former
# with start and end and text for each utterance
#
# Some input may already have the necessary information attached,
# so this script should intelligently passes over files that already 
# look like they have such information added,
# i.e. that have more than one "IP" recorded (some may have the columns
# but only one set of timestamps, etc
#

library(reshape2)
library(ggplot2)
library(plyr)
library(dplyr)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
	stop("Not enough arguments, see script for help.")
}
measurements.path <- normalizePath(args[1])
measurements.list <- list.files(measurements.path)
transcripts.path <- normalizePath(args[2])
output.dir <- normalizePath(args[3])

for (transcript.filename in list.files(transcripts.path, "\\.txt$")) {
	file.id <- gsub("\\.txt", "", transcript.filename)
	output.path <- file.path(output.dir, paste(file.id, ".tsv", sep=""))
	if (!file.exists(output.path)) {
		transcript.path <- file.path(transcripts.path, transcript.filename)
		measurement.table.path <- file.path(measurements.path, paste(file.id, ".tsv", sep=""))
		ip.times <- read.delim(transcript.path)
		if (nrow(ip.times) > 0) {
			cat("Working with transcript for ", file.id, "\n", file=stderr())
			names(ip.times)[c(1,2)] <- c("start_ip","end_ip")
			data.df <- read.delim(measurement.table.path, na.strings=c("NA","--undefined--"))

			# go through times in ip table, match to measurements
			run.time <- system.time(timed.data <- ddply(ip.times, .(start_ip), function(.) {
			  match.rows<-filter(filter(select(data.df, -ip, -start_ip, -end_ip), end_phone < .[1,]$end), start_phone > .[1,]$start)
			  if (nrow(match.rows) > 1) return(cbind(match.rows,end_ip=.[1,]$end_ip,ip_text=.[1,]$text))
			}))
			cat("Run time for ", file.id, ": ", as.character(run.time), " seconds\n", file=stderr())
			timed.data <- cbind(timed.data[,-1], timed.data[,1, drop=FALSE])
			write.table(timed.data, file=output.path, sep="\t", quote=FALSE, row.names=FALSE)
		} else cat("No transcript data for ", file.id, "\n", file=stderr())
	} else cat("Results already exist for ", file.id, "\n", file=stderr())
}

