#############################
#	praatvoicesauceimitator.praat
#
# 	Original script by Chad Vicenik
# 	Harmonic amplitude corrections h/t Iseli (from VoiceSauce codebase)
# 	Other modifications Patrick Callier
#

#############################
#
#  This script goes through all the sound files in a directory
#  and makes several measurements relevant to phonation.
#  It analyzes a given tier within the textgrid associated with
#  the sound file, measuring for each non-empty interval
#  H1-H2, H1-A1, H1-A2 and H1-A3.  It makes these measure-
#  ments at different portions of the interval, based on the 
#  amount of chunking specified.  To do this, it must measure
#  f0 and the locations of the first three formants. 
#
#  This script is based off of a similar script by Bert Remijsen.
#
#  It is similar to the measurements done by VoiceSauce, 
#  developed at UCLA.
#	[PC: modified to output results  in a long-format table, with one measurement point per line]
#   [PC: Added in corrected harmonic measurements. Corrected H1, H2
#    A1, A2, and A3 for F1, F2, and F3; Added CPP and CPPS (smoothed CPP), 2k, 5k,
#	 HNR, HNR05, HNR10, HNR15]	
#	[PC: added Intensity, "fallback" F0 object, exclusion of labels matching skip_these_re$]
#	[PC: recording frequencies of harmonic peaks.]
#
#############################

form Calculate F1, F2, and intensity-related measurements for a specific segment
	comment See header of script for details. 
	sentence Speaker SashaP
	sentence sound_directory 
	sentence Sound_file_extension .wav
	sentence textGrid_directory 
	sentence TextGrid_file_extension .TextGrid
	sentence results_dir 
	
   comment Analyze which tier in the TextGrid:
   integer the_tier 1

	# padding that we can skip analyzing (but use for making windows)
	# make sure this is the same as the setting in save_labeled_intervals...
	positive padding 0.025

   positive window_length 0.025
   positive timestep 0.010
   comment Skip sounds longer than (secs):
   positive max_length 10
	choice Speaker_sex: 2
		button male
		button female
   comment (MALE on the left; FEMALE on the right), more settings in script
	positive left_F1_reference 500
	positive right_F1_reference 550
	positive left_F2_reference 1485
	positive right_F2_reference 1650
	positive left_F3_reference 2475
	positive right_F3_reference 2750
endform

left_Frequency_cost=1
right_Frequency_cost=1
left_Bandwidth_cost=1
right_Bandwidth_cost=1
left_Transition_cost=1
right_Transition_cost=1

sample_rate=16000

# Intervals on the_tier whose labels match this regex will be skipped
skip_these_re$ = "^\{..\}|sp|lg|br|sl|[TPSJFGDHKZCVB]H?$"

clearinfo 


# clean up directory names, making sure they end in /
sound_directory$ = replace_regex$(sound_directory$, "/*$", "/", 0) 
textGrid_directory$ = replace_regex$(textGrid_directory$, "/*$", "/", 0) 
results_dir$  = replace_regex$(results_dir$, "/*$", "/", 0) 
resultfile$ = results_dir$ + speaker$ + "_pitchresults.txt"


# Here, you make a listing of all the sound files in a directory.
# The example gets file names ending with ".wav" from D:\tmp\

Create Strings as file list... list 'sound_directory$'*'sound_file_extension$'
numberOfFiles = Get number of strings

# Check if the result file exists:
if fileReadable (resultfile$)
	pause The result file 'resultfile$' already exists! Do you want to overwrite it?
	filedelete 'resultfile$'
endif

# Write a row with column titles to the result file:
# (remember to edit this if you add or change the analyses!)

titleline$ = "Filename	Segment label	Segment start	Segment end	Measure	Value	Chunk	Window_start	Window_end"
#if include_other_tiers <> 0
#	# open a random textgrid--they should all have the same tier structure
#	Randomize
#	random_name$ = Get string: 1
#	Read from file... 'sound_directory$''random_name$'
#	random_soundname$ = selected$ ("Sound", 1)
#	random_gridfile$ = "'textGrid_directory$''random_soundname$''textGrid_file_extension$'"
#	Read from file: random_gridfile$
#	ntiers = Get number of tiers
#	for tier_i from 1 to ntiers
#		is_interval = Is interval tier: tier_i
#		if tier_i <> the_tier and is_interval <> 0
#			tier_name$ = Get tier name: tier_i
#			titleline$ = titleline$ + "	'tier_name$'"
#		endif
#	endfor
#endif
fileappend "'resultfile$'" 'titleline$'
titleline$ = "'newline$'"
fileappend "'resultfile$'" 'newline$'



# Go through all the sound files, one by one:
select Strings list
Sort
for ifile to numberOfFiles
	name$ = Get string... ifile
	# A sound file is opened from the listing:
	Read from file... 'sound_directory$''name$'
	soundname$ = selected$ ("Sound", 1)
	sound = selected("Sound")
	# exceptionally long sounds are usually mistakes and can clog up the works, skip them
	dur = Get total duration
	#min_length
	if dur < max_length
		# set maximum frequency of Formant calculation algorithm on basis of sex
		# sex is 1 for male (left); sex is 2 for female (right).
		if speaker_sex = 1
			maxf = 5000
			f1ref = left_F1_reference
			f2ref = left_F2_reference
			f3ref = left_F3_reference
			f4ref = 3465
			f5ref = 4455
			freqcost = left_Frequency_cost
			bwcost = left_Bandwidth_cost
			transcost = left_Transition_cost
		endif
		if speaker_sex = 2
			maxf = 5500
			f1ref = right_F1_reference
			f2ref = right_F2_reference
			f3ref = right_F3_reference
			f4ref = 3850
			f5ref = 4950
			freqcost = right_Frequency_cost
			bwcost = right_Bandwidth_cost
			transcost = right_Transition_cost
		endif
		select 'sound'
		Resample... 'sample_rate' 50
		sound_16khz = selected("Sound")
		To Formant (burg)... 0.01 5 'maxf' 0.025 50
		Rename... 'name$'_beforetracking
		formant_beforetracking = selected("Formant")

		xx = Get minimum number of formants
		if xx > 2
			Track... 3 'f1ref' 'f2ref' 'f3ref' 'f4ref' 'f5ref' 'freqcost' 'bwcost' 'transcost'
		else
			Track... 2 'f1ref' 'f2ref' 'f3ref' 'f4ref' 'f5ref' 'freqcost' 'bwcost' 'transcost'
		endif

		Rename... 'name$'_aftertracking
		formant_aftertracking = selected("Formant")
		select 'sound'
		To Spectrogram... 'window_length' 4000 0.002 20 Gaussian
		spectrogram = selected("Spectrogram")
		select 'sound'
		if speaker_sex = 1
			pitchrange_max = 350
			pitchrange_min = 40	
		else
			pitchrange_max = 400
			pitchrange_min = 70
		endif
		pitchrange_min_alt=50
		
		if dur < 3 / 40
			pitchrange_min = 3 / dur
			pitchrange_min_alt = 3 / dur
		endif
		
		To Pitch... 0 'pitchrange_min' 'pitchrange_max'
		pitch = selected("Pitch")
		Interpolate
		Rename... 'name$'_interpolated
		pitch_interpolated = selected("Pitch")
		select sound
		To Pitch: 0, pitchrange_min_alt, pitchrange_max
		Interpolate
		Rename: "'name$'_f0_fallback"
		pitch_fallback = selected("Pitch")

		select pitch
		min_f0 = Get minimum: 0, 0, "Hertz", "Parabolic"
		if min_f0 = undefined
			min_f0 = pitchrange_min
		endif
		select sound
		if dur > 6.4 / min_f0
			To Intensity: min_f0, 0, "yes"
			intensity = selected("Intensity")
		else
			intensity = undefined
		endif

		select sound
		To Harmonicity (cc): timestep, 50, 0.1, 1.0
		hnr = selected ("Harmonicity")
		select sound
		Filter (pass Hann band): 0, 500, 100
		Rename... 'name$'_500
		To Harmonicity (cc): timestep, 50, 0.1, 1.0
		hnr05 = selected ("Harmonicity")
		select sound
		Filter (pass Hann band): 0, 1500, 100
		Rename... 'name$'_1500
		To Harmonicity (cc): timestep, 50, 0.1, 1.0
		hnr15 = selected ("Harmonicity")
		select sound
		Filter (pass Hann band): 0, 2500, 100
		Rename... 'name$'_2500
		To Harmonicity (cc): timestep, 50, 0.1, 1.0
		hnr25 = selected ("Harmonicity")


		# Open a TextGrid by the same name:
		gridfile$ = "'textGrid_directory$''soundname$''textGrid_file_extension$'"
		if fileReadable (gridfile$)
			Read from file... 'gridfile$'
			textgrid = selected("TextGrid")
			select 'textgrid'
			nlabels = Get number of intervals... the_tier
			n_b = Get start time
			n_e = Get end time
			n_b = n_b + padding
			n_e = n_e - padding
			n_d = n_e-n_b
			# get number of windows
			chunk = floor(((n_d - window_length) / timestep) + 1)
			#printline 'n_d','window_length','timestep','chunk','labelx$'
			for kounter from 1 to 'chunk'

				# n_md, "midpoint" time-- the midpoint of the analysis window (not of the segment)
				n_md = n_b + (kounter - 1) * timestep + (window_length/2)
				#printline n_md: 'n_md', n_b: 'n_b', n_e: 'n_e', kounter: 'kounter'

				# get metadata
				select textgrid
				label_int = Get interval at time: the_tier, n_md
				labelx$ = Get label of interval: the_tier, label_int
				labelother$ = ""
#				if include_other_tiers <> 0
#					n_tiers = Get number of tiers
#					for tier_i from 1 to n_tiers
#						is_interval = Is interval tier: tier_i
#						if tier_i <> the_tier and is_interval <> 0
#							label_int = Get interval at time: tier_i, n_md
#							#label_a = Get start point: tier_i, label_int
#							#label_b = Get end point: tier_i, label_int
#							label_text$ = Get label of interval: tier_i, label_int
#							label_text$ = replace_regex$ (label_text$, """|''", "", 0)
#							#printline 'labelother$'
#							labelother$ = labelother$ + "	'label_text$'"
#						endif
#					endfor
#				endif

				if index_regex (labelx$, skip_these_re$) = 0 
					# Get the f1,f2,f3 measurements.
					select 'formant_aftertracking'
					f1hzpt = Get value at time... 1 n_md Hertz Linear
					f1bw = Get bandwidth at time... 1 n_md Hertz Linear
					f2hzpt = Get value at time... 2 n_md Hertz Linear
					f2bw = Get bandwidth at time... 2 n_md Hertz Linear
					if xx > 2
						f3hzpt = Get value at time... 3 n_md Hertz Linear
						f3bw = Get bandwidth at time... 3 n_md Hertz Linear
					else
						f3hzpt = 0
						f3bw = 0
					endif

					select 'sound_16khz'
		
					spectrum_begin = timestep * (kounter - 1) + n_b
					spectrum_end = spectrum_begin + window_length
					Extract part...  'spectrum_begin' 'spectrum_end' Hanning 1 no
					Rename... 'name$'_slice
					sound_16khz_slice = selected("Sound") 
					To Spectrum (fft)
					spectrum = selected("Spectrum")
					To Ltas (1-to-1)
					ltas = selected("Ltas")
					select spectrum
					To PowerCepstrum
					cepstrum = selected("PowerCepstrum")
			

					select pitch_interpolated
					fallback=0
					n_f0md = Get value at time... 'n_md' Hertz Linear
					if n_f0md = undefined
						select pitch_fallback
						n_f0md = Get value at time: n_md, "Hertz", "Linear"
						fallback = 1
					endif
			
					select pitch_interpolated
					if n_f0md <> undefined
						# get h1, h2
						p10_nf0md = 'n_f0md' / 10
						select 'ltas'
						lowerbh1 = 'n_f0md' - 'p10_nf0md'
						upperbh1 = 'n_f0md' + 'p10_nf0md'
						lowerbh2 = ('n_f0md' * 2) - ('p10_nf0md' * 2)
						upperbh2 = ('n_f0md' * 2) + ('p10_nf0md' * 2)
						lowerbh4 = ('n_f0md' * 4) - ('p10_nf0md' * 2)
						upperbh4 = ('n_f0md' * 4) + ('p10_nf0md' * 2)
						h1db = Get maximum... 'lowerbh1' 'upperbh1' None
						h1hz = Get frequency of maximum... 'lowerbh1' 'upperbh1' None
						h2db = Get maximum... 'lowerbh2' 'upperbh2' None
						h2hz = Get frequency of maximum... 'lowerbh2' 'upperbh2' None
						h4db = Get maximum... 'lowerbh4' 'upperbh4' None
						h4hz = Get frequency of maximum... 'lowerbh4' 'upperbh4' None
						rh1hz = round('h1hz')
						rh2hz = round('h2hz')
				

						# Get the a1, a2, a3 measurements.
						if f1hzpt <> undefined and f2hzpt <> undefined
							p10_f1hzpt = 'f1hzpt' / 10
							p10_f2hzpt = 'f2hzpt' / 10
							p10_f3hzpt = 'f3hzpt' / 10
							lowerba1 = 'f1hzpt' - 'p10_f1hzpt'
							upperba1 = 'f1hzpt' + 'p10_f1hzpt'
							lowerba2 = 'f2hzpt' - 'p10_f2hzpt'
							upperba2 = 'f2hzpt' + 'p10_f2hzpt'
							lowerba3 = 'f3hzpt' - 'p10_f3hzpt'
							upperba3 = 'f3hzpt' + 'p10_f3hzpt'
							a1db = Get maximum... 'lowerba1' 'upperba1' None
							a1hz = Get frequency of maximum... 'lowerba1' 'upperba1' None
							a2db = Get maximum... 'lowerba2' 'upperba2' None
							a2hz = Get frequency of maximum... 'lowerba2' 'upperba2' None
							a3db = Get maximum... 'lowerba3' 'upperba3' None
							a3hz = Get frequency of maximum... 'lowerba3' 'upperba3' None
							
							# calculate p0. this is an unpublished technique
							# from rob podesva and pat callier
							To SpectrumTier (peaks)
							spctier = selected ("SpectrumTier")
							Down to Table
							specpeaks = selected ("Table")
							nowarn Extract rows where column (number): "freq(Hz)", "greater than or equal to", 200
							specpeaks2 = selected ("Table")
							nowarn Extract rows where column (number): "freq(Hz)", "less than or equal to", 300
							specpeaks3 = selected ("Table")
							specpeaks_n = Get number of rows
							if specpeaks_n = 1
								p0db = Get value: 1, "pow(dB/Hz)"
								p0hz = Get value: 1, "freq(Hz)"
							elsif specpeaks_n = 2
								if n_f0md > 200
									p0db = Get value: 1, "pow(dB/Hz)"
									p0hz = Get value: 1, "freq(Hz)"
								else
									p0db = Get value: 2, "pow(dB/Hz)"
									p0hz = Get value: 2, "freq(Hz)"
								endif
							else
								if n_f0md > 200
									p0db = h1db
									p0hz = h1hz
								else
									p0db = h2db
									p0hz = h2hz
								endif
							endif
							# calculate corrected values rel to F1-3
							@correct_iseli (h1db, h1hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
							h1c = correct_iseli.result
							@correct_iseli (h2db, h2hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
							h2c = correct_iseli.result
							@correct_iseli (h4db, h4hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
							h4c = correct_iseli.result
							@correct_iseli (a1db, a1hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
							a1c = correct_iseli.result
							@correct_iseli (a2db, a2hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
							a2c = correct_iseli.result
							@correct_iseli (a3db, a3hz, f1hzpt, f1bw, f2hzpt, f2bw, f3hzpt, f3bw, sample_rate)
							a3c = correct_iseli.result
						else
							a1db = undefined                                                        
							a2db = undefined                                                        
							a3db = undefined         
							h1c = undefined
							h2c = undefined
							h4c = undefined
							a1hz = undefined                                                        
							a2hz = undefined                                                        
							a3hz = undefined         
							a1c = undefined                                                        
							a2c = undefined                                                        
							a3c = undefined
							p0db = undefined
							p0hz = undefined						
						endif		# if f1 and f2 not defined
					else
						a1hz = undefined                                                        
						a2hz = undefined                                                        
						a3hz = undefined         
						h1hz = undefined
						h2hz = undefined
						h4hz = undefined
						a1db = undefined                                                        
						a2db = undefined                                                        
						a3db = undefined         
						h1db = undefined
						h2db = undefined
						h4db = undefined
						h1c = undefined
						h2c = undefined
						h4c = undefined
						a1c = undefined                                                        
						a2c = undefined                                                        
						a3c = undefined
						p0db = undefined
						p0hz = undefined						
					endif  # if n_f0md not undefined

					# cepstral peak prominence measures
					select cepstrum
					cpp = Get peak prominence... 'pitchrange_min' 'pitchrange_max' "Parabolic" 0.001 0 "Straight" Robust
					Smooth... 0.0005 1
					smoothed_cepstrum = selected("PowerCepstrum")
					cpps = Get peak prominence... 'pitchrange_min' 'pitchrange_max' "Parabolic" 0.001 0 "Straight" Robust

					# get 2k and 5k	
					# search window--harmonic location should be based on F0, but would throw out a lot. Will base it on cepstral peak.
					select cepstrum
					peak_quef = Get quefrency of peak: 50, 550, "Parabolic"
					peak_freq = 1/peak_quef
					lowerb2k = 2000 - peak_freq
					upperb2k = 2000 + peak_freq
					lowerb5k = 5000 - peak_freq
					upperb5k = 5000 + peak_freq
					select ltas
					twokdb = Get maximum: lowerb2k, upperb2k, "Cubic"
					fivekdb = Get maximum: lowerb5k, upperb5k, "Cubic"
			
					# get HNRs
					select hnr
					hnrdb = Get value at time: n_md, "Cubic"
					select hnr05
					hnr05db = Get value at time: n_md, "Cubic"
					select hnr15
					hnr15db = Get value at time: n_md, "Cubic"
					select hnr25
					hnr25db = Get value at time: n_md, "Cubic"
					
					# get intensity
					if intensity <> undefined
						select intensity
						intdb = Get value at time: n_md, "Cubic"
					else
						intdb=undefined
					endif
					

					
					resultline$ = "'soundname$'	'labelx$'	'n_b'	'n_e'	F0	'n_f0md'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	F1	'f1hzpt'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	F2	'f2hzpt'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	F3	'f3hzpt'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	H1	'h1db'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	H2	'h2db'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	H4	'h4db'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	A1	'a1db'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	A2	'a2db'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	A3	'a3db'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	H1hz	'h1hz'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	H2hz	'h2hz'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	H4hz	'h4hz'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	A1hz	'a1hz'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	A2hz	'a2hz'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	A3hz	'a3hz'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	H1c	'h1c'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	H2c	'h2c'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	H4c	'h4c'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	A1c	'a1c'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	A2c	'a2c'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	A3c	'a3c'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	CPP	'cpp'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	CPPS	'cpps'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	Fallback	'fallback'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	HNR	'hnrdb'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	HNR05	'hnr05db'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	HNR15	'hnr15db'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	HNR25	'hnr25db'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	2k	'twokdb'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	5k	'fivekdb'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	intensity	'intdb'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	p0db	'p0db'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					resultline$ = resultline$+ "'soundname$'	'labelx$'	'n_b'	'n_e'	p0hz	'p0hz'	'kounter'	'spectrum_begin'	'spectrum_end''labelother$''newline$'"
					fileappend "'resultfile$'" 'resultline$'
				endif	# if label doesn't match skip_these_re regex
			endfor		# kounting over chunks
		endif	# if duration < max_dur
	endif	# if file is readable
	select all
	minus Strings list
	Remove
	select Strings list

endfor # loop over files

select all
Remove

procedure correct_iseli (dB, hz, f1hz, f1bw, f2hz, f2bw, f3hz, f3bw, fs)
	dBc = dB
	for corr_i from 1 to 3
		fx = f'corr_i'hz
		bx = f'corr_i'bw
		f = dBc
		if fx <> 0
			r = exp(-pi*bx/fs)
			omega_x = 2*pi*fx/fs
			omega  = 2*pi*f/fs
			a = r ^ 2 + 1 - 2*r*cos(omega_x + omega)
			b = r ^ 2 + 1 - 2*r*cos(omega_x - omega)

			# corr = -10*(log10(a)+log10(b));   # not normalized: H(z=0)~=0
			numerator = r ^ 2 + 1 - 2 * r * cos(omega_x)
			corr = -10*(log10(a)+log10(b)) + 20*log10(numerator)
			dBc = dBc - corr
		endif
	endfor
	.result = dBc
endproc
