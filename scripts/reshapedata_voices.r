# reshapedata.r
# Some reworking and retooling of the input data file (1st arg)
# saved to path given in 2nd arg.
#
# Changes table from long to wide (making it much smaller), adds on
# information at word-, IP-level, including mean median and SD for a bunch of 
# different measures

library(reshape2)
library(plyr)
library(ggplot2)
library(lme4)
library(lmerTest)

args <- commandArgs(trailingOnly = TRUE)
input.path <- args[1]
output.path <- args[2]
stopifnot(length(args) >= 2)

data.df <- read.delim(input.path, na.strings=c("NA","--undefined--"), colClasses=c(word_segments="character", ip="character"),
 row.names=NULL, allowEscapes=TRUE, quote="")
data.df$speaker_id <- data.df[,"speaker"]
data.df$phone_id <- with(data.df, paste(speaker_id, phone, floor(start_phone * 1000), sep="_"))
data.df$word_id <- with(data.df, paste(speaker_id, word, floor(start_word * 1000), sep="_"))
data.df$ip_id <- with(data.df, paste(speaker_id, floor(start_ip * 1000), sep="_"))

message("Making phone-level table")
phone.df <- unique(subset(data.df, select=c(phone_id, phone, start_phone, end_phone, word_id,start_word, end_word, word_segments, ip_id, start_ip, end_ip)))
message("Making word-level table")
word.df <- dcast(phone.df[order(phone.df$start_phone),], word_id + start_word + ip_id + start_ip + end_ip + word_segments ~ "stress_pattern", 
                 value.var="word_segments", fun.aggregate=function(x) { return(gsub("[^012]", "", x[1])) })
word.df$num_syls <- sapply(word.df$stress_pattern,nchar)
word.df$word_in_ip <- with(word.df, ave(start_word, ip_id, FUN=rank))
word.df$word_in_ip_perct <- with(word.df, (start_word-start_ip)/(end_ip-start_ip))

data.df <- merge(data.df, subset(word.df, select=c(word_id,num_syls,word_in_ip,word_in_ip_perct,stress_pattern)),by="word_id")

message("Making IP-level table")
ip.df <- ddply(data.df, .(ip_id), .fun=function(x) { 
  x$F0_max <- max(x$F0,na.rm=TRUE)
  x$F0_min <- min(x$F0,na.rm=TRUE)
  x$F0_median <- median(x$F0,na.rm=TRUE)
  x$F0_mean <- mean(x$F0,na.rm=TRUE)
  x$F0_sd <- sd(x$F0,na.rm=TRUE)
  
  x$int_max <- max(x$intensity,na.rm=TRUE)
  x$int_min <- min(x$intensity,na.rm=TRUE)
  x$int_median <- median(x$intensity,na.rm=TRUE)
  x$int_mean <- mean(x$intensity,na.rm=TRUE)
  x$int_sd <- sd(x$intensity,na.rm=TRUE)
  
  x$ip_syls <- sum(unique(subset(x, select=c(word_id,num_syls)))$num_syls)
  x$ip_words <- nrow(unique(subset(x, select=c(word_id))))
  return(x)
})

# TODO: word frequency, PVI
write.table(data.df, file=output.path, row.names=FALSE, sep="\t", quote=FALSE)
