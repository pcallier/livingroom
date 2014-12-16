# toy-analysis.r
# Demo analysis of Living Room/VoC Data

library(reshape2)
library(ggplot2)
library(lme4)
library(lmerTest)
library(plyr)
library(dplyr)
args <- commandArgs(trailingOnly = TRUE)

base.dir <- "/Volumes/Surfer/users/pcallier"
data.df <- read.delim(file.path(base.dir, "voc", "annotatedresults", "BAK_Boles_Carolyn.tsv"), na.strings=c("NA","--undefined--"))
data.df$phone_id <- factor(with(data.df, Filename))

# some stats
phones.df<-unique(data.df[,c("phone_id","Segment.label")])
phones.summary <- data.frame(count=summary(phones.df$Segment.label))
chunks.df <- dcast(data.df, phone_id ~ "no.chunks", fun.aggregate=length)

# vowel analysis

phones.df <- ddply(merge(data.df, phones.summary, by.x="Segment.label", by.y="row.names"),
                   .(Segment.label), function(.) { filter(., F1 < mean(F1,na.rm=TRUE) +
                                                            1.96*sd(F1,na.rm=TRUE) & 
                                                            F1 > mean(F1,na.rm=TRUE) -
                                                            1.96*sd(F1,na.rm=TRUE) &
                                                            F2 < mean(F2,na.rm=TRUE) +
                                                            1.96*sd(F2,na.rm=TRUE) & 
                                                            F2 > mean(F2,na.rm=TRUE) -
                                                            1.96*sd(F2,na.rm=TRUE)) })

vowels.df <- merge(ddply(select(droplevels(phones.df[grepl("[AEIOU].[01]",phones.df$Segment.label),]),F1,F2,Segment.label),
                         .(Segment.label), .fun=function(.) { return(data.frame(F1=median(.$F1,na.rm=TRUE),
                                                                                F2=median(.$F2,na.rm=TRUE))) } ),
                   phones.summary, by.x="Segment.label", by.y="row.names")



ggplot(aes(x = F2, y=F1, label=Segment.label), data=filter(vowels.df, count > 10)) + 
  geom_text()+ scale_x_reverse() + scale_y_reverse()

ggplot(aes(x = F2, y=F1, group=Segment.label), data=filter(phones.df, count > 10 & 
                                                             grepl("(AA|OW|UW|IY)1",
                                                                   Segment.label))) + 
  geom_contour(stat="density2d") + scale_x_reverse() + scale_y_reverse() + 
  geom_text(aes(x=F2, y=F1, label=Segment.label), color="black", 
            data=filter(vowels.df, count > 10))
  

#ggplot(aes(x = F2, y=F1, color=Segment.label), data=filter(phones.df, count > 10 & grepl("(AA|OW|UW|IY)1",Segment.label))) +
#   geom_contour(breaks=4, stat="density2d") + scale_x_reverse() + scale_y_reverse() + 
#   geom_text(aes(x=F2, y=F1, label=Segment.label), color="black", data=filter(vowels.df, count > 10 & grepl("[AEIOU].[1]",Segment.label)))
   
# voice quality first steps
ggplot(aes(x = Segment.label, y=H1c-H2c), data=data.df) + geom_boxplot()
ggplot(aes(x = Segment.label, y=CPPS), data=data.df) +  geom_boxplot()
ggplot(aes(x = CPPS, y=F0), data=data.df) + 
   geom_point(alpha=0.2) + stat_density2d() 
ggplot(aes(x = CPPS, y=H1c-H2c), data=data.df) + 
	geom_point(alpha=0.2)  + stat_density2d()

