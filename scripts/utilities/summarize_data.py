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
import re
import logging
logging.basicConfig(level=logging.DEBUG)
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

segment_re = re.compile(r"([^0-9]+)[012]?")
stress_re = re.compile(r"[^0-9]+([012]?)")
vowel_re = re.compile(r"[AEIOU][AEIOUYWH]")


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
    
def pipeline_medians_40s(df, grouping_col='segment_id', measure_cols=measure_cols, 
                       binary_cols=binary_cols):
    """Return a summary of df where df is split by grouping_col, the median is taken 
    of all cols in measure_cols, and binary_cols are True iff more than 40% of their
    elements are True. For all other cols, the zeroth element in ea. group is returned"""
    
    measures_df = df[measure_cols + [grouping_col]]
    binary_df = df[binary_cols + [grouping_col]]
    the_rest = df[[col for col in df.columns if col not in measure_cols + binary_cols]]
    
    measures_medians = measures_df.groupby(grouping_col).apply(
        lambda x: x.median(skipna=True))
    binary_40 = binary_df.groupby(grouping_col).apply(
        lambda x: x.mean(skipna=True) > 0.4)
    the_rest = the_rest.groupby(grouping_col).apply(lambda x: x.iloc[0,:])
    
    return pd.concat([the_rest, measures_medians, binary_40], axis=1)
    
def pipeline_recode(df):
    recodes = {'Unnamed: 0': 'index',
               'movamp_interp': 'movamp',
               'smiles_interp': 'smiles',
               'creak_binary': 'creak',
               'Segment label': 'segment_with_stress',
               'Chunk': 'chunk_index',
               'Filename': 'filename_segment',
               'Unnamed: 191': 'blank'}
    return df.rename(columns=recodes)
    
def pipeline_segment_labels(df):
    logging.info(df.columns.values)
    df['segment_label'] = df['segment_with_stress'].map(lambda x: 
                                                        segment_re.sub(r"\1", str(x)))
    df['stress'] = df['segment_with_stress'].map(lambda x: 
                                                        stress_re.sub(r"\1", str(x)))
    df['preceding_segment'] = df['preceding_context'].map(lambda x: 
                                                        segment_re.sub(r"\1", str(x)))
    df['following_segment'] = df['following_context'].map(lambda x: 
                                                        segment_re.sub(r"\1", str(x)))
    df['preceding_stress'] = df['preceding_context'].map(lambda x: 
                                                        stress_re.sub(r"\1", str(x)))
    df['following_stress'] = df['following_context'].map(lambda x: 
                                                        stress_re.sub(r"\1", str(x)))
                                                        
    return df                                                        

def pipeline_durations(df):
    df['segment_duration'] = df['segment_original_end'] - df['segment_original_start']
    df['word_duration'] = df['word_end'] - df['word_start']
    df['line_duration'] = df['line_end'] - df['line_start']    
    return df
    
def pipeline_vowels_only(df, vowel_col='Segment label'):
    return df[df[vowel_col].map(lambda x: vowel_re.search(x) is not None)]

def pipeline_phrase_summaries(df, smile_col='smiles_interp', movamp_col='movamp_interp',
                                    interlocutor_smile='interlocutor_smile',
                                    interlocutor_movamp='interlocutor_movamp'):
    group_means = df[['line_id',smile_col, movamp_col,
                      interlocutor_smile,interlocutor_movamp]].groupby('line_id').mean()
    group_means.columns = ['percent_phrase_smiled','mean_phrase_movamp',
        'percent_phrase_smiled_interlocutor','mean_phrase_movamp_interlocutor']
    try:
        group_means.reset_index(inplace=True)
    finally:
        return df.merge(group_means, on='line_id', how='left')  
    
def pipeline_phrase_posns(df):
    df['chunk_secs_from_line_start'] = df['chunk_original_timestamp'] - df['line_start']
    df['chunk_secs_from_line_end'] =  df['line_end'] - df['chunk_original_timestamp']
    df['chunk_normalized_time_by_line'] = (df['chunk_secs_from_line_start'] / 
                                            (df['line_end'] - df['line_start']))
    return df    
        
if __name__ == '__main__':
    table_path = sys.argv[1]
    logging.info("Loading data")
    dtypes = dict(zip(measure_cols, ['float'] * len(measure_cols)) + 
                  zip(binary_cols, ['bool'] * len(binary_cols)))
    df = pd.read_table(table_path, sep='\t', dtype=dtypes,low_memory=False)
    logging.info("Phrase-level summaries")
    df = pipeline_phrase_summaries(df)
    logging.info("Cutting out non-vowels")
    df = pipeline_vowels_only(df)
    logging.info("Reducing to one observation per segment")
    df = pipeline_medians_40s(df)
    logging.info("Doing some recodes")
    df = pipeline_recode(df)
    logging.info("Getting segment and stress information")
    df = pipeline_segment_labels(df)    
    logging.info("Durations")
    df = pipeline_durations(df)
    logging.info("Phrase positions")
    df = pipeline_phrase_posns(df)
    
    print df.to_csv(sep='\t',index=False, encoding='utf-8')