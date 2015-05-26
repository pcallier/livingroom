form Give me textgrid
    sentence textgrid_path 
    natural target_tier
endform

# Get labels of preceding and following segments on target_tier

Read from file: textgrid_path$
n = Get number of tiers
n_ints = Get number of intervals: target_tier

for i_int from 1 to n_ints
    label$ = Get label of interval: target_tier, i_int
    label$ = replace_regex$(label$, "\s+", " ", 0)
    if label$ <> ""
        start = Get start point: target_tier, i_int
        end = Get end point: target_tier, i_int
        
        print 'label$''tab$''start''tab$''end'
        
        prev_label$ = ""
        if i_int <> 1
            prev_label$ = Get label of interval: target_tier, i_int - 1
        endif
        
        next_label$ = ""
        if i_int <> n_ints
            next_label$ = Get label of interval: target_tier, i_int + 1
        endif
        print 'tab$''prev_label$''tab$''next_label$'
    endif
    printline
endfor
Quit