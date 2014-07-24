# This is an extremely fragile utility script for adding
# the results of do_creak_detection.m (a bunch of TGs)
# to one master TG, which should be selected.
# Parameters to change include small_tg_dir$, creak_tier
# It assumes the originating TextGrid has 3 tiers and that the fourth will
# be where the creak goes

creak_tier = 4 
tg = selected ("TextGrid")

ntiers = Get number of tiers
if ntiers = 3
	Insert interval tier: creak_tier, "creak"
endif

small_tg_dir$ = "/afs/ir.stanford.edu/users/p/c/pcallier/private/working/creaking"
Create Strings as file list: "small_tg_list", "'small_tg_dir$'/*.TextGrid"
tg_list = selected("Strings")

lastboundary = -1
n_tgs = Get number of strings
for tg_i from 1 to n_tgs
	select tg_list
	this_tg$ = Get string: tg_i
	Read from file: "'small_tg_dir$'/'this_tg$'"
	small_tg	= selected("TextGrid")
	offset_ms$ = replace_regex$(this_tg$, "(^.*_)([0-9]+)(\.TextGrid)" , "\2", 0)
	offset_ms = number(offset_ms$)
	
	n_ints = Get number of intervals: 1
	for int_i from 1 to n_ints
		select small_tg
		int_label$ = Get label of interval: 1, int_i
		if int_label$ == "creak"
			intervalstart = Get start point: 1, int_i
			intervalend = Get end point: 1, int_i
			printline Adding at 'offset_ms' + 'intervalstart' and 'intervalend', 'int_label$'
		
			select tg
			boundary_1 = intervalstart + offset_ms / 1000
			nr_1_low = Get low interval at time: creak_tier, boundary_1
			nr_1_high = Get high interval at time: creak_tier, boundary_1
			
			boundary_2 =  intervalend + offset_ms / 1000
			nr_2_low = Get low interval at time: creak_tier, boundary_2
			nr_2_high = Get high interval at time: creak_tier, boundary_2
			if nr_1_low = nr_1_high and nr_2_low = nr_2_high
				Insert boundary: creak_tier, boundary_1
				Insert boundary: creak_tier, boundary_2

				midpt = (intervalend - intervalstart) / 2 + intervalstart + offset_ms / 1000
				which_int_bigtg = Get interval at time: creak_tier, midpt
				Set interval text: creak_tier, which_int_bigtg, "creak"
			endif
		endif
	endfor

	select small_tg
	Remove
endfor
select tg_list
Remove
printline Done.