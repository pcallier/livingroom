form Give me textgrid
    sentence textgrid_path 
    natural target_tier
    sentence tiers_to_check
endform

Read from file: textgrid_path$
n = Get number of tiers
n_ints = Get number of intervals: target_tier

for i_int from 1 to n_ints
    label$ = Get label of interval: target_tier, i_int
    label$ = replace_regex$(label$, "\s+", " ", 0)
    if label$ <> ""
        start = Get start point: target_tier, i_int
        end = Get end point: target_tier, i_int
        midpoint = (end - start) / 2 + start
        print 'label$''tab$''start''tab$''end'
        for tier_num from 1 to n
            regex$ = "(^|\W)" + string$(tier_num) + "(\W|$)"
            if index_regex(tiers_to_check$, regex$) <> 0
                # add to table
                matching_interval = Get interval at time: tier_num, midpoint
                matching_label$ = Get label of interval: tier_num, matching_interval
                matching_label$ = replace_regex$(matching_label$, "\s+", " ", 0)
                if matching_label$ = ""
                    matching_label$ = """"""
                endif
                matching_start = Get start point: tier_num, matching_interval
                matching_end = Get end point: tier_num, matching_interval
                print 'tab$''matching_label$''tab$''matching_start''tab$''matching_end'
            endif
        endfor
    endif
    printline
endfor
Quit