# toy-analysis.r
# Demo analysis of Living Room Data

library(reshape2)
library(ggplot2)
library(lme4)
library(lmerTest)
library(plyr)
library(dplyr)
args <- commandArgs(trailingOnly = TRUE)

base.dir <- "/Volumes/Surfer/users/pcallier"
data.df <- read.delim(file.path(base.dir, "results", "BAK_Boles_Carolyn.tsv"), na.strings=c("NA","--undefined--"))
data.df$phone_id <- factor(with(data.df, Filename))

# some stats
phones.df<-unique(data.df[,c("phone_id","Segment.label")])
phones.summary <- data.frame(count=summary(phones.df$Segment.label))
chunks.df <- dcast(data.df, phone_id ~ "no.chunks", fun.aggregate=length)

# vowel analysis
vowels.df <- merge(ddply(select(droplevels(data.df[grepl("[AEIOU].[01]",data.df$Segment.label),]),F1,F2,Segment.label),
                   .(Segment.label), .fun=function(.) { return(data.frame(F1=median(.$F1,na.rm=TRUE),
                                                                          F2=median(.$F2,na.rm=TRUE))) } ),
                   phones.summary, by.x="Segment.label", by.y="row.names")

ggplot(aes(x = F2, y=F1, label=Segment.label), data=filter(vowels.df, count > 10)) +
  geom_text() + scale_x_reverse() + scale_y_reverse()

# voice quality first steps
ggplot(aes(x = Segment.label, y=H1c-H2c), data=data.df) + geom_boxplot()
ggplot(aes(x = Segment.label, y=CPPS), data=data.df) +  geom_boxplot()
ggplot(aes(x = CPPS, y=F0), data=data.df) + 
  stat_density2d() + geom_point(alpha=0.2) 
ggplot(aes(x = CPPS, y=H1c-H2c), data=massive.df) + 
  stat_density2d() + geom_point(alpha=0.2) 

