# Get utterance timings from a ELAN TSV export to a TG
# UGLY
#
# ELAN TSV export has no headers
# but Praat can't even conceive of a table file without headers
# so we import as strings
#
# Output is a TextGrid object with the Utterance timings added. 
# ~~If overwrite_tg is checked, the tg file given will be overwritten~~
#
# The input file should be tab-delimited, with at least five columns
# and have the beginning time in the third column,
# ending time in the fourth column, text in the fifth

form Give me the ELAN export and TG you want to modify
	sentence Tab_separated_timings /Volumes/data_drive/corpora/living_room/data/annotations/20140512_008F_INT010_FAM_CHA.txt
	sentence Textgrid_to_modify /Volumes/Surfer/users/pcallier/livingroom/.working/tgs/20140512_008F_010_FAM_CHA.TextGrid
	boolean Overwrite_tg 0
	boolean Voc_xml 0
endform

if overwrite_tg=1
	printline Overwriting input TextGrid...
endif

Read Strings from raw text file: tab_separated_timings$
tg_lines = selected("Strings")
n_lines = Get number of strings

Read from file: textgrid_to_modify$
tg = selected("TextGrid")
n_tiers = Get number of tiers
end_of_grid = Get end time

Insert interval tier: n_tiers + 1, "Line"

b = -1
for line_i from 1 to n_lines
	# the lines may be in two formats: tab-delim, or XML. We can't deal with all valid XML,
	# but if the fields are ordered start, end, speaker, and text, then we can deal

	if voc_xml = 0
		select tg_lines
		cur_line$ = Get string: line_i
		a = number ( replace_regex$(cur_line$, "^.*?\t.*?\t([0-9.]+)\t.*$", "\1",0) )
		# cover case where prior right boundary equals current left boundary
		if a = b
			a = undefined
		endif 
		b = number ( replace_regex$(cur_line$, "^.*?\t.*?\t.*?\t([0-9.]+)\t.*$", "\1",0) )
		line_text$ = replace_regex$(cur_line$, "^.*?\t.*?\t.*?\t([0-9.]+)\t(.*)$", "\2",0)
	
		select tg
	
		if a <> undefined
			# normal insertion
			nocheck Insert boundary: n_tiers + 1, a
			cur_int = Get interval at time: n_tiers + 1, a
		else
			# no need to add an extra boundary
			cur_int = cur_int + 1
		endif
		Set interval text: n_tiers+1, cur_int, line_text$
		if b <> end_of_grid
			nocheck Insert boundary: n_tiers + 1, b
		endif
	else
		# VOC-style XML formatting, assuming order of start, end, speaker, text (and each record
		# on a separate line), tries to ID speaker based on (VOC-style) filename
		# 3C and 3E are hex codes for gt and lt signs (<, >)
		# I DON'T THINK THIS WORKS YET
		speaker_guess$ = replace_regex$(tab_separated_timings$, "[BAK|RED|MER|SACI?]_((^_)+_(^_)+)_.*$", "\1", 0)
		select tg_lines
		cur_line$ = Get string: line_i
		a = number (replace_regex$(cur_line$, "^.*\X3Cst\X3E(.+)\X3C/st\X3E.*$", "\1",0))
		# cover case where prior right boundary equals current left boundary
		if a = b
			a = undefined
		endif 
		b = number (replace_regex$(cur_line$, "^.*\X3Cend\X3E(.+)\X3C/end\X3E.*$", "\1",0))
		spkr$ = replace_regex$(cur_line$, "^.*\X3Cspkr\X3E(.+)\X3C/spkr\X3E.*$", "\1",0)
		line_text$ = replace_regex$(cur_line$, "^.*\X3Cutt\X3E(.+)\X3C/utt\X3E.*$", "\1",0)
		
		if speaker_guess$ = spkr$
			select tg
	
			if a <> undefined
				# normal insertion
				nocheck Insert boundary: n_tiers + 1, a
				cur_int = Get interval at time: n_tiers + 1, a
			else
				# no need to add an extra boundary
				cur_int = cur_int + 1
			endif
			Set interval text: n_tiers+1, cur_int, line_text$
			if b <> end_of_grid
				nocheck Insert boundary: n_tiers + 1, b
			endif		
		endif
	endif
endfor

if overwrite_tg = 1
	select tg
	Save as text file: textgrid_to_modify$
endif

select tg_lines
Remove