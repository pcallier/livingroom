library(plyr)
source("/Users/BigBrother/Downloads/my_useful_functions.r")
p1 <- read.delim("/Volumes/Surfer/users/pcallier/livingroom/livingroomresults/20141105_029M_INT024_FAM_CHA.tsv")
p1 <- p1[,c("timepoint","smile")]
p1 <- unique(p1[order(p1[,"timepoint"]),])
times <- get.ranges(p1[,"timepoint"], p1[,"smile"], TRUE)
times[,"text"] <- "smile"
write.table(times[,c("start","text","end")], file="~/Downloads/029M_smiles.tsv",row.names=FALSE,col.names=TRUE,sep="\t", quote=FALSE)
