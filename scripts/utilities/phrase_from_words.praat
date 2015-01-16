#
#   phrase_from_words.praat
#
#   Take word-level FAVE-style output (with sp labels) on word_tier
#   and construct phrase-like segmentations from it
#   and put it on destination_tier, which will be created and labeled "IPsurrogate"
#
#   Do so for all TextGrids in src_dir
#   Save output in dest_dir, which should be different
#   if output_as_tsv is true, output will be a single TSV results.tsv with all non-blank IPs and
#   their beginnings and ends. Otherwise, output will be individual TextGrid files
#   matching those in src_dir
#
form Phrase from Words settings...
    sentence src_dir /Users/patrickcallier/Downloads/tgs
    sentence dest_dir /Users/patrickcallier/Downloads/dest_tg
    natural word_tier 2
    natural destination_tier 3
    boolean output_as_tsv Yes
endform
tg_list = Create Strings as file list: "tgList", src_dir$ + "/*.TextGrid"
num_tgs = Get number of strings
if output_as_tsv = 1
    writeFileLine: dest_dir$ + "/results.tsv", "speaker" + tab$ + "ip_start" + tab$  + "ip_end" + tab$ + "ip_text"
endif
for tg_i from 1 to num_tgs
    select tg_list
    tg_filename$ = Get string: tg_i
    Read from file: src_dir$ + "/" + tg_filename$
    Insert interval tier: destination_tier, "IPsurrogate"
    numberOfIntervals = do ("Get number of intervals...", word_tier)
    words$ = ""
    for intervalNumber from 1 to numberOfIntervals
        startTime = do ("Get start point...", word_tier, intervalNumber)
        endTime = do ("Get end point...", word_tier, intervalNumber)
        duration = endTime - startTime
        label$ = do$ ("Get label of interval...", word_tier, intervalNumber)
        if label$ <> "sp"
            words$ = words$ + " " + label$
        endif
        if intervalNumber > 1
            prevlabel$ = do$ ("Get label of interval...", word_tier, intervalNumber -1)
            if prevlabel$ = ""
                prevlabel$ = "sp"
            endif
        else
            prevlabel$ = "sp"
        endif
        if label$ = "sp" and prevlabel$ <> "sp"
            nowarn Insert boundary... destination_tier startTime
            ip_interval = Get interval at time: destination_tier, startTime - 0.01
            Set interval text: destination_tier, ip_interval, words$
            words$ = ""
        endif
        if intervalNumber < numberOfIntervals
            nextlabel$ = do$ ("Get label of interval...", word_tier, intervalNumber +1)
            if nextlabel$ = ""
                nextlabel$ = "sp"
            endif
        else
            # end of the line, output remaining words
            ip_interval = Get interval at time: destination_tier, startTime
            Set interval text: destination_tier, ip_interval, words$
            words$ = ""
            nextlabel$ = "sp"
        endif
        if label$ = "sp" and nextlabel$ <> "sp"
            nowarn Insert boundary... destination_tier endTime
        endif
    endfor
    if output_as_tsv = 1
        numberOfIPIntervals = Get number of intervals: destination_tier
        speaker_name$ = selected$("TextGrid")
        for ipIntervalNumber from 1 to numberOfIPIntervals
            ip_text$ = Get label of interval: destination_tier, ipIntervalNumber
            if ip_text$ <> ""
                ip_start = Get start point: destination_tier, ipIntervalNumber
                ip_end = Get end point: destination_tier, ipIntervalNumber
                appendFileLine: dest_dir$ + "/results.tsv", speaker_name$ + tab$ + string$(ip_start) + tab$ + string$(ip_end) + tab$ + ip_text$
            endif
        endfor
    else
        Save as text file: dest_dir$ + "/" + tg_filename$
    endif
    Remove
endfor
select tg_list
Remove