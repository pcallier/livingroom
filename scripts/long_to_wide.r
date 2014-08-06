library(reshape2)

args <- commandArgs(trailingOnly = TRUE)
input.path <- args[1]
output.path <- args[2]
stopifnot(length(args) >= 2)

data.df <- read.delim(input.path, na.strings="--undefined--")
massive.df <- dcast(data.df, ... ~ Measure, value.var="Value")
write.table(massive.df, file=output.path, row.names=FALSE, sep="\t", quote=FALSE)


