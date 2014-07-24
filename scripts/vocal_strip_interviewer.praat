# vocal_strip_interviewer.praat
# 
# Just takes tiers 3 and 4 in input TG and removes them, saving to output TG path
# Leaves only phone and word tiers from interviewee on 1 and 2, respectively
#
# Part of VoCal creak/nasality pipeline
#
# Patrick Callier 7/2014
#

form Give me two paths
	sentence Input_tg
	sentence Output_tg
endform

if input_tg$ = output_tg$
	exitScript: Do not overwrite original TG
endif

Read from file: input_tg$
Remove tier: 4
Remove tier: 3
Save as text file: output_tg$
