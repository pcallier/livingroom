# add_smiles_movamp.r
# Patrick Callier
# 11/2014
#
# Takes a path to measurement table (from PraatVoiceSauceImitator + other stuff)
# and a path to a table with the output of Rob Voigt's
# smiling/movement amplitude script
# with timestamps and smiling (boolean) and MA (numeric)
# and modifies measurement tables
# to have a column smile (boolean) and movement_amplitude (numeric)
# with a (smoothed/interpolated, if necessary) value from the closest
# corresponding timepoint in the smiling/movement amp. table,
# with output saved to the path given in the third argument
#
# This is appropriate for measurement tables that have measurements at
# regular timepoints. It also has a (yet-to-be-implemented) method which is appropriate
# for annotating inputs which have been reduced to summaries over 
# irregularly sized intervals, which has parameters for what percentage
# of an interval's duration should be smiled for the interval to count
# as smiled, and what function to use to summarize movement amplitude
# (defaulting to max)
#

library(car)

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 3) {
  stop("Usage:\n\tadd_smiles_movamp.r measurements_path movamp_path output_dir\n\nNot enough arguments. see script for help.")
}

measurements.path <- normalizePath(args[1])
movamp.path <- normalizePath(args[2])
output.path <- args[3]

timepoint.annotate <- function(measurements.df, movamp.df) {
	# return an annotated df according to specs in description
	if (sum(!is.na(movamp.df[,"movement_amplitude"]) >= 2)) {
		measurements.df[,"movement_amplitude"] <- tryCatch(approx(movamp.df[, "time"], 
			movamp.df[, "movement_amplitude"], xout=measurements.df[, "timepoint"])$y, error=function(e) {NA})
	} else measurements.df[,"movement_amplitude"] <- NA
	if (sum(!is.na(movamp.df[,"smile"]) >= 2)) {
		measurements.df[, "smile"] <- tryCatch(approx(movamp.df[, "time"], 
			as.numeric(movamp.df[, "smile"]), xout=measurements.df[, "timepoint"])$y, error=function(e) {NA})
	} else measurements.df[, "smile"] <- NA
	return(measurements.df)
}

interval.annotate <- function(measurements.df, movamp.df, smiles.cutoff=0.4, movamp.func=max) {
}

do.annotation <- function(measurements.path, movamp.path, output.path, method=timepoint.annotate) {
	# either loop over files if measurements.path is a directory (not currently supported)
	# or just do one at a time
	if (file.info(measurements.path)$isdir == FALSE) {
		measurements.df <- read.delim(measurements.path)
		movamp.df <- read.delim(movamp.path, colClasses=c(smile="logical"))
		output.df <- method(measurements.df, movamp.df)
		#output.filename <- basename(measurements.path)
		#output.path <- file.path(output.dir, output.filename)
		write.table(output.df, file=output.path, quote=FALSE, row.names=FALSE, sep="\t")
	}
}

do.annotation(measurements.path, movamp.path, output.path)
