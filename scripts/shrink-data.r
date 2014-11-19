# shrink-data.r
# Shrink results from the VoC pipeline data
# by a lot

library(reshape2)
library(plyr)
library(dplyr)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 2) {
	stop("Not enough arguments, see script for help.")
}
measurements.path <- normalizePath(args[1])
output.dir <- normalizePath(args[2])

base.dir <- normalizePath(measurements.path)
for (data.filename in list.files(base.dir, "\\.tsv$")) {
	cat(paste("Looking at", data.filename, "\n"), file=stderr())
	output.path <- file.path(output.dir, data.filename)
	cat(paste("Output will go in ", output.path, "\n"), file=stderr())
	if (!file.exists(output.path)) {

		data.path <- file.path(measurements.path, data.filename)
		data.df <- read.delim(data.path, na.strings=c("NA","--undefined--"), quote="", sep="\t", row.names=NULL)
		if (nrow(data.df) > 1) {
			data.df$phone_id <- factor(with(data.df, Filename))
			cat("Rows before reduction: ", nrow(data.df),"\n", file=stderr())
			data.df <- filter(data.df, grepl("[AEIOU]", Segment.label) & Segment.end < 0.75)
			cat("Rows after excluding non-vowels and overlong segments: ", nrow(data.df), "\n", file=stderr())
  
		  # add any necessary columns (fill with blanks)
		  id.columns <- c("Filename","Segment.label","Segment.start","Segment.end","preceding_segment",
			"following_segment","phone","start_phone","end_phone","word_segments","word","start_word",
			"end_word","ip","start_ip","end_ip","speaker","sex","location","age","race","sexual_orientation",
			"phone_id")
		  for (required.col in id.columns) { 
			if (!required.col %in% names(data.df)) {
			  data.df[ , required.col] <- NA 
			  }
		  }
	  
			# split up by segment class first (so much faster!)
			run.time <- system.time(
			  small.df <- ddply(data.df, .(Segment.label), function(segment.df) {
				ddply(segment.df,                
					  .(phone_id), function(.) { 
						# take the first value of ID variables and the mean of measurement variables
						cbind(.[1, id.columns],
							  lapply(.[, c("X2k","X5k","A1","A1c","A1hz","A2","A2c","A2hz","A3","A3c","A3hz","CPP",
										   "CPPS","F0","F1","F2","F3","H1","H1c","H1hz","H2","H2c",
										   "H2hz","H4","H4c","H4hz","HNR","HNR05","HNR15","HNR25","intensity","p0db","p0hz")],
									 function(.) { median(., na.rm=TRUE) }
							  ))
					  }
				)    
			  }
			  )
			)
			cat("Run time for ", data.filename, ": ", as.character(run.time), " seconds\n", file=stderr())
			write.table(small.df, file=output.path, sep="\t", quote=FALSE, row.names=FALSE)
			cat("Saved to ", output.path, "\n\n", file=stderr())
		}
	} else {
		cat(sprintf("Found results for %s, skipping...\n\n", data.filename))
	}
}

