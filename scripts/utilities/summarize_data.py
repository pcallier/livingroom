#!/usr/bin/env python
# -*- coding: utf-8 -*-
""" summarize_data.py 
Patrick Callier

Utility suite/script for getting a useful summary of pipeline output for analysis.
Will do a number of reductions and summaries, including:
- one measurement per segment
- maybe some outlier detection?
"""

import sys
import pandas as pd
import numpy as np

measure_cols = [
'2k',
'5k',
'A1',
'A1c',
'A1hz',
'A2',
'A2c',
'A2hz',
'A3',
'A3c',
'A3hz',
'CPP',
'CPPS',
'F0',
'F1',
'F2',
'F3',
'H1',
'H1c',
'H1hz',
'H2',
'H2c',
'H2hz',
'H4',
'H4c',
'H4hz',
'HNR',
'HNR05',
'HNR15',
'HNR25',
'intensity',
'movamp_interp',
'p0db',
'p0hz',
'interlocutor_movamp']

binary_cols = ['smiles_interp', 'interlocutor_smile', 'creak_binary']



def summarize_many_cols(df, cols_to_summarize, grouping_col="segment_id", 
                        summary_func=lambda z: pd.Series.median(z, skipna=True)):
    """Summarize a df by taking the median (or other summary function) 
    of a number of columns.
    Returns the df with only one row per unique value of grouping_col.
    For cols_to_summarize, the value returned is the median, for all
    others, it is the zeroth element"""
    
    def summary_op(x):
        df_to_summarize = x[cols_to_summarize]
        df_the_rest = x[[col for col in x.columns if col not in cols_to_summarize]]
        summaries = df_to_summarize.apply(summary_func)
        the_rest = df_the_rest.apply(lambda y: y.iloc[0])
        return pd.concat([summaries,the_rest], axis=1)
        
    df_groups = df.groupby(grouping_col, as_index=False)
    df_summary = df_groups.apply(summary_op)
    
    return df_summary
    
def summarize_pipeline(df, grouping_col='segment_id', measure_cols=measure_cols, 
                       binary_cols=binary_cols):
    """Return a summary of df where df is split by grouping_col, the median is taken 
    of all cols in measure_cols, and binary_cols are True iff more than 40% of their
    elements are True. For all other cols, the zeroth element in ea. group is returned"""
    
    measures_df = df[measure_cols + ['segment_id']]
    binary_df = df[binary_cols + ['segment_id']]
    the_rest = df[[col for col in df.columns if col not in measure_cols + binary_cols]]
    
    measures_medians = measures_df.groupby(grouping_col).apply(
        lambda x: pd.Series.median(x, skipna=True))
    binary_40 = binary_df.groupby('segment_id').apply(
        lambda x: pd.Series.mean(x, skipna=True) > 0.4)
    the_rest = the_rest.groupby('segment_id').nth(0)
    
    return pd.concat([the_rest, measures_medians, binary_40]).reset_index(level=0)
        
if __name__ == '__main__':
    table_path = sys.argv[1]
    df = pd.read_table(table_path)
    print summarize_pipeline(df).to_csv(sep='\t',index=False, encoding='utf-8')