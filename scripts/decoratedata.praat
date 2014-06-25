# DecorateData.praat
#
# Takes a table of measurements (from PraatVoiceSauceImitator.praat), the fully 
# decorated TextGrid of the audio (with phone, word, utterance, creak, smiles, etc.),
# and the survey responses (responses_all.tsv) from the survey system.
# 
# Output is an even bigger table file with a whole bunch of crap in it.
#
# Patrick Callier
#

form Decorate measurements with extra data
	sentence measurements_path /Users/patrickcallier/Dropbox/ongoing/postdoc/livingroom/work/SashaP_pitchresults.txt
	sentence textgrid_path /Volumes/Surfer-1/BigBrother/data/annotations/20140512_007M-008F_INT10_FAM_CHA.TextGrid
	sentence survey_path /Users/patrickcallier/Dropbox/ongoing/postdoc/livingroom/data/responses-all.tsv
	# by design, speakers may have multiple records in the survey results file
	# for purposes of this script, you have to pick one. if you 
	# need more advanced functionality, you should probably 
	# doctor the responses-all.tsv table yourself.
	comment Which line of the survey to use? (2nd to last field)
	sentence which_userinforecord_id 5757487680585728
	
	sentence output_path /Users/patrickcallier/Dropbox/ongoing/postdoc/livingroom/work/test_output.txt
endform

Read Strings from raw text file: measurements_path$
measurements = selected("Strings")
Read Table from tab-separated file: survey_path$
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
		tier_name$ = Get tier name: tier_i
		header_line$ = header_line$ + "	'tier_name$'	start_'tier_i'	end_'tier_i'"
	endif
endfor
header_line$ = header_line$ + "	user_id	session_id	age	gender	race	sexual_orientation	userinforecord_id	userinforecord_timestamp"
select measurements
Set string: 1, header_line$



for line_i from 2 to nmeasures
	select measurements
	cur_measure$ = Get string: line_i
	# the only absolute time key is in the filename, so if you didn't have time (ms) in the filename,
	# go back and do it again!
	# filename in first column
	timestamp = number ( replace_regex$ ( cur_measure$, "^[^\t].*?([0-9]+)\t.*$", "\1", 0 ))
	# offset in 8th and ninth columns
	windowstart = number ( replace_regex$ ( cur_measure$, "^(([^\t]*\t){7})([0-9.]+)\t.*$", "\3", 0 ))
	windowend = number ( replace_regex$ ( cur_measure$, "^(([^\t]*\t){8})([0-9.]+)\t.*$", "\3", 0 ))
	timepoint = timestamp / 1000 + windowstart + (windowend-windowstart)/2
	
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
			cur_measure$ = cur_measure$ + tab$ + label_text$ + tab$ + string$ (time_a) + tab$ + string$ (time_b)
		endif
	endfor
	
	# and survey data
	select survey
	Rename... r
	which_line = Search column: "userinforecord_id", which_userinforecord_id$
	survey_line$ = ""
#	survey_line$ = tab$ + Table_r$ [which_line, "firstname"] + tab$ + Table_r$ [which_line, "lastname"]
	survey_line$ = survey_line$ + tab$ + Table_r$ [which_line, "user_id"]
	survey_line$ = survey_line$ + tab$ + Table_r$ [which_line, "session_id"]
	survey_line$ = survey_line$ + tab$ + Table_r$ [which_line, "age"]
	survey_line$ = survey_line$ + tab$ + Table_r$ [which_line, "gender"]
	survey_line$ = survey_line$ + tab$ + Table_r$ [which_line, "race"]
	survey_line$ = survey_line$ + tab$ + Table_r$ [which_line, "sexual_orientation"]
	survey_line$ = survey_line$ + tab$ + Table_r$ [which_line, "userinforecord_id"]
	survey_line$ = survey_line$ + tab$ + Table_r$ [which_line, "userinforecord_timestamp"]
	cur_measure$ = cur_measure$ + survey_line$
	select measurements
	Set string: line_i, cur_measure$
endfor

select measurements
Save as raw text file: output_path$