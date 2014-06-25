# toy-analysis.r
# Demo analysis of Living Room Data

library(reshape2)
library(ggplot2)
library(lme4)
library(lmerTest)


base.dir <- "/Users/patrickcallier/Dropbox/ongoing/postdoc/livingroom"
data.df <- read.delim(file.path(base.dir, "work", "test_output.txt"), na.strings="--undefined--")
data.df$phone_id <- factor(with(data.df, Filename))

# some stats
phones.df<-unique(data.df[,c("phone_id","Segment.label")])
summary(phones.df$Segment.label)
chunks.df <- dcast(subset(data.df, Measure=="F0"), phone_id ~ "no.chunks", fun.aggregate=length)

# vowel analysis
vowels.df <- dcast(droplevels(data.df[grepl("[AEIOU].[01]",data.df$Segment.label) &
                                        data.df$Measure %in% c("F1","F2","F3"),]),
                   Segment.label~ Measure, 
                   value.var = "Value",
                   fun.aggregate=function(.) { mean(., na.rm=TRUE) })

ggplot(aes(x = F2, y=F1, label=Segment.label), data=vowels.df) +
  geom_text() + scale_x_reverse() + scale_y_reverse()

# voice quality first steps
creak.df <- dcast(droplevels(data.df[grepl("[AEIOU].[01]",data.df$Segment.label) &
                                        data.df$Measure %in% c("H1c","H2c","CPPS",
                                                               "A1c","A2c","A3c",
                                                               "2k","5k"),]),
                   creak ~ Measure, 
                   value.var = "Value",
                   fun.aggregate=function(.) { mean(., na.rm=TRUE) })

massive.df <- dcast(data.df, ... ~ Measure, value.var="Value")
ggplot(aes(x = creak, y=H1c-H2c), data=massive.df) + geom_boxplot()
ggplot(aes(x = creak, y=CPPS), data=massive.df) +  geom_boxplot()
ggplot(aes(x = CPPS, y=F0, color=creak), data=massive.df) + 
  stat_density2d() + geom_point(alpha=0.2) 
ggplot(aes(x = CPPS, y=H1c-H2c, color=creak), data=massive.df) + 
  stat_density2d() + geom_point(alpha=0.2) 

