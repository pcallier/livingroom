# vocal_strip_interviewer.praat
# 
# Takes input TG (w/ word and phone alignments) and removes any tiers not belonging
# to the speaker, saving result to output TG path.
# Identifies irrelevant tiers by searching for certain keywords
# Leaves only phone and word tiers from interviewee on 1 and 2, respectively
#
# Part of VoCal creak/nasality pipeline
#
# Patrick Callier 7/2014
#
#

form Give me two paths
	sentence Input_tg
	sentence Output_tg
endform

if input_tg$ = output_tg$
	exitScript: "Do not overwrite original TG"
endif

Read from file: input_tg$
tg_name$ = selected$ ("TextGrid")
speaker_first$ = replace_regex$(tg_name$, "(BAK|RED|MER)_([^_]+)_([^_]+).*?$", "\L\3", 0)
speaker_last$ = replace_regex$(tg_name$, "(BAK|RED|MER)_([^_]+)_([^_]+).*?$", "\L\2", 0)

ntiers = Get number of tiers
for i from 3 to ntiers
	lowscore=0
	lowscore_tier=0
	ntiers=Get number of tiers
	for tier_i from 1 to ntiers
		tier_score = 0
		tier_name$ = Get tier name: tier_i
		tier_name$ = replace_regex$(tier_name$, ".", "\L&", 0)
		# score tier name, penalizing for things that are not speaker, rewarding for things that are
		if index (tier_name$, speaker_first$) <> 0
			tier_score = tier_score + 1
		endif
		if index (tier_name$, speaker_last$) <> 0
			tier_score = tier_score + 1
		endif
		if index (tier_name$, "speak") <> 0
			tier_score = tier_score + 1
		endif
		if index (tier_name$, "interviewee") <> 0
			tier_score = tier_score + 1
		endif

		if index (tier_name$, "interviewer") <> 0
			tier_score = tier_score - 1
		endif				

		if tier_score < lowscore
			lowscore = tier_score
			lowscore_tier = tier_i
		endif
	endfor
	if lowscore_tier <> 0
		Remove tier: lowscore_tier
	endif
endfor

Save as text file: output_tg$
