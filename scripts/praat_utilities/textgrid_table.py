#!/usr/bin/env python

import os
import subprocess
import itertools


def get_table_from_tg(textgrid_path, target_tier, other_tiers=None, praat_path = "praat",
utilities_path = "praat_utilities/"):
    """ From the TextGrid in texgrid_path find which of the other 
    tiers in other_tiers overlap the midpoint of each nonempty interval in target_tier
    Output a table with the start, end, and label of each nonempty interval in the target,
    Along with the same information for each overlapping tier in the other tiers (all
    if other_tiers is None)
    """
     
    num_tiers = subprocess.check_output([praat_path, 
        os.path.join(utilities_path, "textgrid_numtiers.praat"), 
        os.path.abspath(textgrid_path)], shell=False)
    
    if other_tiers is None:
        other_tiers = [x for x in range(1, long(num_tiers) + 1) if x != target_tier]
    
    tg_table = subprocess.check_output([praat_path, 
        os.path.join(utilities_path, "textgrid_table.praat"), 
        os.path.abspath(textgrid_path) + ' ' + str(target_tier) + ' ' + 
            ' '.join(map(str, other_tiers))])
    
    return list(map(lambda x: x.split('\t'), tg_table.split('\n')))
    