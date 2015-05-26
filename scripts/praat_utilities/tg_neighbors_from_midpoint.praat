form Give me textgrid
    sentence textgrid_path 
    natural target_tier
    positive target_midpoint
endform

# Get labels of preceding and following segments on target_tier, given target_midpoint

Read from file: textgrid_path$

n_ints = Get number of intervals: target_tier
i_int = Get interval at time: target_tier, target_midpoint
      
prev_label$ = ""
if i_int <> 1
    prev_label$ = Get label of interval: target_tier, i_int - 1
endif

next_label$ = ""
if i_int <> n_ints
    next_label$ = Get label of interval: target_tier, i_int + 1
endif

print 'prev_label$''tab$''next_label$'

Quit