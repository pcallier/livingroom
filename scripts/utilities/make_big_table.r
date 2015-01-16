#
# voc_vq_analysis.r
#
# Make a "big table" with all the measurements
# from the reduced, annotated VoC pipeline data
#
# do some additional coding and VQ analyses
#
# Profit
#
# Patrick Callier
# 11/2014
#

library(car)
library(reshape2)
library(plyr)
library(dplyr)
library(R.utils)

setwd("/Volumes/Surfer/users/pcallier/voc/")


measurements.path <- "/Volumes/Surfer/users/pcallier/voc/shrunkenresults"
metadata.path <- "/Volumes/Surfer/users/pcallier/voc/"

make.big.table <- function(measurements.dir) {
  list.of.dfs <- list()
  measurements.files <- list.files(measurements.path)
  for (measurements.file in measurements.files) {
    list.of.dfs <- c(list.of.dfs, list(read.delim(file.path(measurements.dir, measurements.file), quote="")))
  }
  big.df <- rbind.fill(list.of.dfs)
  
  return(big.df)
}

big.df <- make.big.table(measurements.path)
big.df[big.df[,"speaker"]=="RED_Fowler_Ginger","sex"] <- "female"

filename <- "big_table_voc.txt"
write.table(big.df, file=filename, col.names=TRUE, quote=FALSE, row.names=FALSE)
gzip(filename)

