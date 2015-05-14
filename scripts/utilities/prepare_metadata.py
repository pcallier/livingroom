#!/usr/bin/env python
"""prepare_metadata.py
"""

import StringIO
import logging
logging.basicConfig(level=logging.DEBUG)
import pandas as pd
import data.legacy_ids

def is_same_day(date1, date2):
    return(date1.year == date2.year and date1.month == date2.month and 
            date1.day == date2.day)

def normalize_id(x):
    try:
        id = "{:03d}".format(
            long(float(filter(lambda(y): str.isdigit(y) or y==".", str(x)))))
    except ValueError:
        id = pd.np.nan
    logging.debug("in: {}, out: {}".format(x, id))
    return id
    
def prepare_qualtrics(qualtrics_path, qualtrics_header_path="qualtricsheadings.txt"):
    with open(qualtrics_header_path) as qheader_file:
        qualtrics_header = qheader_file.read().strip().split(",")
        
    qualtrics_table = pd.read_table(qualtrics_path,sep=",",skiprows=[0,1],header=None,
                                    names=qualtrics_header)
                                    
    # normalize ID fields, if present
    id_fields = [id_field for id_field in 
        ['SessionID','ParticipantOneID','ParticipantTwoID','ParticipantID'] 
        if id_field in qualtrics_table.columns]
    for id_field in id_fields:
        qualtrics_table[id_field] = map(normalize_id, qualtrics_table[id_field])
            
    return qualtrics_table

                         
def adorn_with_session_info(df, exit_survey_path, exit_survey_header_path, 
          session_info_path, session_info_header_path):
    """ (Living Room-specific)
    Joins measurement data with exit survey and session info data
    df should have fields 'session_id' and 'speaker_id' which identify the speaker/session 
    unique pair for each observation"""
        
    exit_survey = prepare_qualtrics(exit_survey_path, exit_survey_header_path)
    session_info = prepare_qualtrics(session_info_path, session_info_header_path)

    # rectify session/participant IDs
    # bkgd: all exit_survey exports from qtrics will be missing session/participant 
    # IDs for the first 60 or so records, so must merge them into exit_survey from 
    # hand-coded data in data.legacy_ids
    backup_ids = pd.read_table(StringIO.StringIO(data.legacy_ids.ids), sep=",", 
                               dtype="string")
    exit_survey_alternates = exit_survey[['ResponseID']].merge(
        backup_ids, how='left', on='ResponseID')
    exit_survey[['SessionID','ParticipantID']] = \
        exit_survey[['SessionID','ParticipantID']].where(
            pd.isnull(exit_survey[['SessionID', 'ParticipantID']])==False,
            exit_survey_alternates[['SessionID', 'ParticipantID']])
    logging.debug(exit_survey['SessionID'].values)
    
    
    # main loop for adding metadata, iterates over unique speaker/session pairs
    # The idea is to build up a one-row data frame with all the metadata for each 
    # speaker/session from exit survey and session records, combine them
    combined_result = pd.DataFrame()
    for index, speaker_session in df.loc[:,['session_id','speaker_id']].drop_duplicates().iterrows():
        speaker_session_df = pd.DataFrame()
        
        # add session-level metadata
        # find speaker name
        # note that 0-row data frame must be assigned to with iterable type
        speaker_session_df['session_id'] = [speaker_session['session_id']]
        speaker_session_df['speaker_id'] = speaker_session['speaker_id']
        
        logging.debug("Session IDs: {}".format(session_info['SessionID'].values))
        logging.debug("Session ID: {}".format(speaker_session_df['session_id'].values))
        current_session_info = session_info[session_info['SessionID'].values == 
                                            speaker_session_df['session_id'].values]

        logging.debug("Spkr ID: {}\nPrtcpt One ID: {}\nPrtcpt Two ID: {}".format(
                        speaker_session_df['speaker_id'],
                        current_session_info['ParticipantOneID'],
                        current_session_info['ParticipantTwoID']))

        # find names of participant, and names + ID of interlocutor
        if speaker_session_df['speaker_id'].values == current_session_info['ParticipantOneID'].values:
            speaker_session_df['speaker_first'] = str(current_session_info['ParticipantOneFirstName'].values[0])
            speaker_session_df['speaker_last'] = str(current_session_info['ParticipantOneLastName'].values[0])
            speaker_session_df['interlocutor_id'] = str(current_session_info['ParticipantTwoID'].values[0])
            speaker_session_df['interlocutor_first'] = str(current_session_info['ParticipantTwoFirstName'].values[0])
            speaker_session_df['interlocutor_last'] = str(current_session_info['ParticipantTwoLastName'].values[0])
        elif speaker_session_df['speaker_id'].values == current_session_info['ParticipantTwoID'].values:
            speaker_session_df['speaker_first'] = str(current_session_info['ParticipantTwoFirstName'].values[0])
            speaker_session_df['speaker_last'] = str(current_session_info['ParticipantTwoLastName'].values[0])
            speaker_session_df['interlocutor_id'] = str(current_session_info['ParticipantOneID'].values[0])
            speaker_session_df['interlocutor_first'] = str(current_session_info['ParticipantOneFirstName'].values[0])
            speaker_session_df['interlocutor_last'] = str(current_session_info['ParticipantOneLastName'].values[0])
        else:
            logging.warning("Session information not found for speaker {}, session {}".
                            format(speaker_session['speaker_id'], 
                                   speaker_session['session_id']))
            raise Exception()
            
        # clean up ID numbers (format as 3-digit zero-padded)
        speaker_session_df['speaker_id'] = speaker_session_df['speaker_id'].map(
            lambda x: "{:03d}".format(long(x)))
        speaker_session_df['session_id'] = speaker_session_df['session_id'].map(
            lambda x: "{:03d}".format(long(x)))
        speaker_session_df['interlocutor_id'] = speaker_session_df['interlocutor_id'].map(
            lambda x: "{:03d}".format(long(x)))
        
        # add exit_survey metadata
        # acquire this speaker's row from exit_survey, add to speaker_session_df
        matching_exit_rows = (exit_survey['ParticipantID'].values==
                              speaker_session_df['speaker_id'].values) & \
            (exit_survey['SessionID'].values==speaker_session_df['session_id'].values)
        logging.debug("Number of matching rows from exit survey: {}".format(
            sum(matching_exit_rows)))
        exit_survey_row = exit_survey[matching_exit_rows]

        exit_survey_row.index = speaker_session_df.index
        speaker_session_df = pd.concat([speaker_session_df, exit_survey_row], axis=1)

        combined_result = pd.concat([combined_result, speaker_session_df], axis=0,
                                    ignore_index=True)

    return df.merge(combined_result, how='left', on=['speaker_id','session_id'])
        