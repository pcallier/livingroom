# DecorateData_voices.praat
#
# Takes a table of measurements (from PraatVoiceSauceImitator.praat), the fully 
# decorated TextGrid of the audio (with phone, word, utterance, creak, etc.),
# and the metadata with speaker name, age, location, gender, sexual orientation, etc.
# 
# Output is an even bigger table file with a whole bunch of crap in it.
#
# FRAGILE: Assumes (though you may change these parameters) that phones are tier 1,
# words are tier 2, lines/utterances/IPs are tier 3, creak is tier 4
#
# Patrick Callier
#

form Decorate VoC measurements with extra data
	sentence measurements_path
	sentence textgrid_path
	sentence metadata_path 	
	sentence output_path 
	sentence speaker
endform

phone_tier = 1
word_tier = 2
ip_tier = 3
creak_tier = 4

level_'phone_tier'$ = "phone"
level_'word_tier'$ = "word"
level_'ip_tier'$ = "ip"
level_'creak_tier'$ = "creak"

procedure get_segments (word_int)
	.a = Get start point: word_tier, word_int
	.b = Get end point: word_tier, word_int
	.result$ = ""
	.cur_phone = Get interval at time: phone_tier, .a
	.phone_a = Get start point: phone_tier, .cur_phone
	while .phone_a < .b
		.phone$ = Get label of interval: phone_tier, .cur_phone
		.result$ = .result$ + " " + .phone$
		.cur_phone = .cur_phone + 1
		.phone_a = Get start point: phone_tier, .cur_phone
	endwhile
	.result$ = replace_regex$ (.result$, "^\s*(.*)\s*$", "\1", 0)
endproc

Read Strings from raw text file: measurements_path$
measurements = selected("Strings")
Read Table from tab-separated file: metadata_path$
survey = selected("Table")
Read from file: textgrid_path$
textgrid = selected("TextGrid")



# for each line, find the corresponding time points in every tier of the textgrid
# record start point, end point, and label
# append also the appropriate line from the survey
select measurements
nmeasures = Get number of strings

# fix header
select measurements
header_line$ = Get string: 1
header_line$ = header_line$ + "	timepoint"
select textgrid
ntiers = Get number of tiers
for tier_i from 1 to ntiers
	is_interval = Is interval tier: tier_i
	if is_interval <> 0
		if tier_i = phone_tier
			header_line$ = header_line$ + "	preceding_segment	following_segment"
		endif
		if tier_i = word_tier
			header_line$ = header_line$ + "	word_segments"
		endif
		tier_name$ = level_'tier_i'$
		header_line$ = header_line$ + "	'tier_name$'	start_'tier_name$'	end_'tier_name$'"
	endif
endfor
# add headers for which metadata fields will be used (change also below)
header_line$ = header_line$ + "	speaker	location	age	gender	race	sexual_orientation"
select measurements
Set string: 1, header_line$



for line_i from 2 to nmeasures
	select measurements
	cur_measure$ = Get string: line_i
	# the only absolute time key is in the filename, so if you didn't have time (ms) in the filename,
	# go back and do it again!
	# filename in first column
	timestamp$ = replace_regex$ ( cur_measure$, "^[^\t].*?([0-9]+)\t.*$", "\1", 0 )
	timestamp = number ( timestamp$ )
#	printline Timestamp: "'timestamp$'"

	# offset in 6th and 7th columns
	windowstart$ = replace_regex$ ( cur_measure$, "^((([^\t]*)\t){6}).*?$", "\3", 0 )
	windowstart = number ( windowstart$ )
#	printline Windowstart: "'windowstart$'"

	windowend$ = replace_regex$ ( cur_measure$, "^((([^\t]*)\t){7}).*?$", "\3", 0 )
	windowend = number (windowend$)
#	printline Windowend: "'windowend$'"

	timepoint = timestamp / 1000 + windowstart + (windowend-windowstart)/2
#	printline Timepoint: 'timepoint'
	
	cur_measure$ = cur_measure$ + tab$ + string$ (timepoint)
	select textgrid
	ntiers = Get number of tiers
	for tier_i from 1 to ntiers
		is_interval = Is interval tier: tier_i
		if is_interval <> 0
			cur_int = Get interval at time: tier_i, timepoint
			label_text$ = Get label of interval: tier_i, cur_int
			time_a = Get start point: tier_i, cur_int
			time_b = Get end point: tier_i, cur_int
			# get preceding, following phone information
			if tier_i = phone_tier
				prev_int = cur_int - 1
				if prev_int > 0
					prev_seg$ = Get label of interval: tier_i, prev_int
				else
					prev_seg$ = ""
				endif
				
				next_int = cur_int + 1
				num_ints = Get number of intervals: tier_i
				if next_int <= num_ints
					next_seg$ = Get label of interval: tier_i, next_int
				else
					next_seg$ = ""
				endif
				cur_measure$ = cur_measure$ + tab$ + prev_seg$ + tab$ + next_seg$
			endif	# if tier_i = phone_tier
			if tier_i = word_tier
				@get_segments(cur_int)
				cur_measure$ = cur_measure$ + tab$ + get_segments.result$
			endif
			cur_measure$ = cur_measure$ + tab$ + label_text$ + tab$ + string$ (time_a) + tab$ + string$ (time_b)
		endif
	endfor
	
	# and survey data
	select survey
	Rename... r
	which_line = Search column: "speaker", speaker$
	survey_line$ = ""
	survey_line$ = survey_line$ + tab$ + Table_r$ [which_line, "speaker"]
	survey_line$ = survey_line$ + tab$ + Table_r$ [which_line, "location"]
	survey_line$ = survey_line$ + tab$ + Table_r$ [which_line, "age"]
	survey_line$ = survey_line$ + tab$ + Table_r$ [which_line, "gender"]
	survey_line$ = survey_line$ + tab$ + Table_r$ [which_line, "race"]
	survey_line$ = survey_line$ + tab$ + Table_r$ [which_line, "sexual_orientation"]
	cur_measure$ = cur_measure$ + survey_line$
	select measurements
	Set string: line_i, cur_measure$
endfor

select measurements
Save as raw text file: output_path$

