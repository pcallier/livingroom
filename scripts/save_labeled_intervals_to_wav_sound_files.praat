# This script saves each interval in the selected IntervalTier of a TextGrid to a separate WAV sound file.
# It also saves a corresponding TextGrid to a matching TextGrid file in the same directory
# The source sound must be a LongSound object, and both the TextGrid and 
# the LongSound must have identical names and they have to be selected 
# before running the script.
# Files are named with the corresponding interval labels (plus a running index number when necessary).
#
# NOTE: You have to take care yourself that the interval labels do not contain forbidden characters!!!!
# 
# This script is distributed under the GNU General Public License.
# Copyright 8.3.2002 Mietta Lennes
#
# [PC: some modifications]

form Save intervals to small WAV sound files
	comment Input files
	sentence Soundfile /Users/patrickcallier/Dropbox/ongoing/postdoc/livingroom/audio/20140512_007M-008F_INT10_FAM_CHA.wav
	sentence Tg_file /Volumes/Surfer-1/BigBrother/data/annotations/20140512_007M-008F_INT10_FAM_CHA.TextGrid
	comment Your working folder, where files will be saved:
	sentence Wav_folder /afs/ir.stanford.edu/users/p/c/pcallier/private/working/creaking
	boolean Exclude_empty_labels 1
	boolean Exclude_intervals_labeled_as_xxx 0
	boolean Exclude_intervals_starting_with_dot_(.) 1
	comment Segment on which tier?
	integer Which_tier 1
	boolean Use_labels 1
	boolean Include_textgrids 1
	
	# padding
	positive Margin_(seconds) 0.025

	comment Optional filename decorators:
	sentence Prefix 
	sentence Suffix 
endform

Read from file... 'tg_file$'
tg_name$ = selected$ ("TextGrid", 1)
phone_tg = selected ("TextGrid", 1)

Open long sound file... 'soundfile$'
soundname$ = selected$ ("LongSound", 1)
sound = selected ("LongSound", 1)

# check if there are wav files in working directory(ies)
# delete them
Create Strings as file list... workingFiles 'wav_folder$'/*.wav
n_str = Get number of strings
if n_str > 0
	pause About to delete 'n_str' .wav files from destination folder...
endif
for n_file from 1 to n_str
	filename$ = Get string... n_file
	deleteFile (wav_folder$ + "/" + filename$)
endfor
Remove
# same for textgrid files
Create Strings as file list... workingFiles 'wav_folder$'/*.TextGrid
n_str = Get number of strings
if n_str > 0
	pause About to delete 'n_str' .TextGrid files from destination folder...
endif
for n_file from 1 to n_str
	filename$ = Get string... n_file
	deleteFile (wav_folder$ + "/" + filename$)
endfor
Remove

# Default values for variables
files = 0
intervalstart = 0
intervalend = 0
interval = 1
intname$ = ""
intervalfile$ = ""
select sound
endoffile = Get finishing time
select phone_tg

# Loop through all vowel intervals

nrows = Get number of intervals... 'which_tier'
printline Going through 'nrows' records in TextGrid tier 'which_tier'

for interval from 1 to nrows
	select phone_tg

	intname$ = Get label of interval... 'which_tier' 'interval'
	
	# decide whether or not to check this interval (0 = yes, 1 = no)
	check = 0
	if intname$ = "xxx" and exclude_intervals_labeled_as_xxx = 1
		check = 1
	endif
	if intname$ = "XXX" and exclude_intervals_labeled_as_xxx = 1	
		check = 1
	endif
	if intname$ = "" or intname$ = "{SL}" or intname$ = "sp"  or intname$ = "{LG}" or intname$ = "{NS}" and exclude_empty_labels = 1
		check = 1
	endif
	if left$ (intname$,1) = "." and exclude_intervals_starting_with_dot = 1
		check = 1
	endif
	
	if check = 0
		intervalstart = Get start point... 'which_tier' 'interval'
		segmentstartms = floor(intervalstart*1000)
			if intervalstart > margin
				intervalstart = intervalstart - margin
			else
				intervalstart = 0
			endif
		intervalstartms = floor(intervalstart * 1000)

		intervalend = Get end point... 'which_tier' 'interval'		
		segmentendms = floor(intervalend*1000)
			if intervalend < endoffile - margin
				intervalend = intervalend + margin
			else
				intervalend = endoffile
			endif
		intervalendms = floor(intervalend *1000)
		
		# do extraction	
		select sound
		Extract part... intervalstart intervalend no
		sound_part = selected ("Sound")
		Resample: 16000, 50
		sound_part_resampled= selected("Sound")
		Extract one channel: 1
		sound_part_left = selected("Sound")

		if use_labels = 1	
			filename$ = intname$ + "_" + "'intervalstartms'"
		else
			filename$ = "_" + "'intervalstartms'"
		endif
		intervalfile$ = "'wav_folder$'" + "/" + "'prefix$'" + "'filename$'" + "'suffix$'" + ".wav"
		Write to WAV file... 'intervalfile$'

		To TextGrid... label 
		select phone_tg
		Extract part: intervalstart, intervalend, 0
		tgfile$ = "'wav_folder$'" + "/" + "'prefix$'" + "'filename$'" + "'suffix$'" + ".TextGrid"
		if include_textgrids = 1
			Save as chronological text file... 'tgfile$'
		endif
		Remove
		select phone_tg
		Remove

		select sound_part
		Remove
		select sound_part_resampled
		Remove
		select sound_part_left
		Remove
		

	endif
endfor
printline Done.