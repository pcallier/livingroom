#!/usr/bin/env python
"""pipeline_main.py

Patrick Callier
04/2015

Main entry point for the analysis pipeline. Has options to select corpus type (Living Room
dyads vs or Voices of California), set the path to praat (defaults to a BSD/Linux-
compatible local fallback, which should be in this folder), choose which speakers to analyze,
and of course set the path to audio recordings, alignment 
TextGrids, video recordings (optional), and metadata table (also optional, I think?)

Depends: pandas, numpy, scipy.signal. A compatible praat should be placed in the scripts/
directory

Output: one table, with acoustic measurements, unique speaker/session IDs, and whatever 
metadata are available"""

import sys
import os
import re
import StringIO
import logging
logging.basicConfig(level=logging.DEBUG)
logging.root.setLevel(logging.DEBUG)
import distutils.dir_util


import numpy as np
#import scipy.io as sp_io
import pandas as pd
import acoustic_analysis_livingroom as acous
from smiles_movamp.get_smiles import do_smiles_movamp, face_file, smile_file
from praat_utilities import textgrid_table
from utilities.prepare_metadata import prepare_qualtrics, adorn_with_session_info
from utilities.get_offset import get_offset_wav

# important regexes
livingroom_pattern_template = r"^(\d{8})_SESSION_USER([MF]?)_(FAM|STR)_(CHA|SOF)"
livingroom_filename_pattern = r"^(\d{8})_(INT\d{3})_(\d{3})([MF]?)_(FAM|STR)_(CHA|SOF).(wav|mov|eaf)$"
unique_id_pattern = r"^(INT\d{3})_(\d{3})$"
# paths--shifty!
# root of corpus, should contain video, audio, annotations folders
livingroom_root = "/Volumes/data_drive/corpora/living_room/data/"
# repository of creak detection results
creak_tmp_dir = "/Volumes/Surfer/users/pcallier/livingroom/creak_results"
# location of this script
script_dir = os.path.abspath(os.path.dirname(__file__))
acous.script_root = script_dir
smiles_data_path = os.path.join(script_dir,'smiles_movamp')
# temporary repository (not in Dropbox) of working files
pipeline_tmp_root = "/Users/BigBrother/Documents/pipeline_working"
# temporary repository of unjoined results for each case
tmp_results_dir = os.path.join(pipeline_tmp_root, ".working")
# temporary repository of wavs and textgrids--regularly deleted and rewritten!
tmp_wav_dir = os.path.join(pipeline_tmp_root, ".tmpwav")


def do_creak_detection(creak_results_path):
    """right now, the creak detection runs independently in a VM, so all this step
    needs to do is look in a designated folder for the results and return them.
    """
    creak_df = pd.read_table(creak_results_path)
    return creak_df
    
    
def do_cv_annotation(video_path):
    """returns a list of tuples (time, movement amplitude z-score, smile score)
    from Rob Voigt's computer vision annotation script
    """
    cv_results = do_smiles_movamp(os.path.realpath(video_path), smiles_data_path, face_file, smile_file)
    return cv_results

def add_metadata_from_path(df, metadata_path, df_keys, metadata_keys):
    metadata_df = pd.read_table(metadata_path)
    return df.merge(metadata_df, left_on=df_keys, right_on=metadata_keys)
    
def points_to_interval_indexes(points, lower, upper):
    """Returns, for each timepoint in points, the index of the (first) interval in
    zip(lower, upper) which it falls within, or None if None. Right now just a vectorization
    of value_in_which_interval"""
    return [ value_in_which_interval(pt, lower, upper) for pt in points ]
    

def value_in_which_interval(value, lower, upper, return_all=False):
    upper = pd.Series(upper)
    lower = pd.Series(lower)
    if return_all:
        return list(np.where(pd.concat([lower < value, upper > value], axis=1).all(1))[0])
    else:
        try:
            return list(np.where(pd.concat([lower < value, upper > value], axis=1).all(1))[0])[0]
        except IndexError:
            return None


def working_dir():
    tmp_path = os.path.realpath(tmp_results_dir)
    if not os.path.isdir(tmp_path):
        distutils.dir_util.mkpath(tmp_path)
    return tmp_path
            
def add_offsets(df,audio_dir):
    """Takes a df where speaker_session_id, session_id, and interlocutor_id and 
    chunk_original_timestamp are defined, and adds columns offset_secs and 
    chunk_timestamp_with_offset, using the automatically detected offset between 
    the relevant audio files"""
    spkr_sess_df = df.loc[:,['speaker_session_id','session_id','speaker_id',
                             'interlocutor_id']].drop_duplicates()
    spkr_sess_df['spkr_audio'], spkr_sess_df['interlocutor_audio'] = [ 
        (unique_id_to_audio_path(spkr_sess_id,audio_dir), 
         unique_id_to_audio_path("INT{sess_id}_{spkr_id}".format(sess_id, interlocutor_id),
                                 audio_dir)) for spkr_sess_id, sess_id, interlocutor_id in
                                    spkr_sess_df[:,['speaker_session_id','session_id',
                                    'interlocutor_id']].values ]
    # reduce spkr_sess_df to a df with 1 row per session, with one speaker chosen as 
    # the reference point for each session
    sess_groups = spkr_sess_df.groupby('session_id')
    sess_df = spkr_sess_df.loc[[ session_group[0] for session_group in sess_groups.groups.itervalues() ], :]
    # get audio offsets: amount of time that inter_wav starts after spkr_wav
    sess_df['offset_secs'] = [ get_offset_wav(spkr_wav, inter_wav) for spkr_wav, inter_wav in
        sess_df[:, ['spkr_audio','interlocutor_audio']].values ]
    # adjusted timestamps: spkr_time = orig + offset, inter_time = orig + 0
    spkr_df = sess_df[['speaker_id','offset']]
    inter_df = sess_df[['interlocutor_id']]
    inter_df.columns[0] = 'speaker_id'
    inter_df['offset_secs'] = 0
    offset_df = pd.concat([spkr_df,inter_df], axis=0, ignore_index=True)
    df = df.merge(offset_df, on='speaker_id')
    df['chunk_timestamp_with_offset'] = df['chunk_original_timestamp'] + df['offset']
    
    return df

def add_alignments_to_acoustic(df,alignments_path):
    """Takes output of acoustic measurement step, having at least column
    'segment_original_midpoint', and a path (alignments_path) to a TextGrid
    containing phonetic alignments for the appropriate audio.
    
    Merges phone- and word-level metadata from alignments with acoustic 
    measurements and returns the result."""
    
    phone_tier = 1
    word_tier = 2
    
    # get data from alignment
    logging.info("Getting data from alignments table")
    # phones and words
    alignments_table = pd.DataFrame(textgrid_table.get_table_from_tg(
            alignments_path, phone_tier, other_tiers=[word_tier], 
            utilities_path=os.path.join(script_dir, "praat_utilities")), 
        columns=['segment_label', 'segment_start', 'segment_end', 
                 'word_label', 'word_start', 'word_end'])

    alignments_table['segment_start'] = alignments_table['segment_start'].astype(float)
    alignments_table['segment_end'] = alignments_table['segment_end'].astype(float)
    alignments_table['segment_midpoint'] = alignments_table['segment_start'] + \
        (alignments_table['segment_end'] - alignments_table['segment_start']) / 2
    # this method checks where segment midpoints fall, may be slow
    words_table = alignments_table.loc[:,['word_start','word_end','word_label']].drop_duplicates()
    segment_indices = pd.Series([ value_in_which_interval(midpt, 
        words_table['word_start'].astype(float), 
        words_table['word_end'].astype(float)) for midpt in
        df['segment_original_midpoint'] ], index=df.index).dropna()
    matching_words = words_table.iloc[segment_indices,:].set_index(segment_indices.index)
    logging.debug(df.shape)
    logging.debug(matching_words.shape)
    
    df = pd.concat([df, matching_words], 1)
    return df
     
def add_transcript_data_to_acoustic(df,transcript_path):
    transcript_start_col = 2
    transcript_end_col = 3
    transcript_text_col = 4

    logging.info("Getting data from transcript")
    try:

        transcript_table = pd.read_table(transcript_path, header=None, 
            names=['speaker','speaker','line_start','line_end','line_label'])
        trs_start = transcript_table.iloc[:,transcript_start_col]
        trs_end = transcript_table.iloc[:,transcript_end_col]
        trs_indices = pd.Series([ value_in_which_interval(midpt, trs_start, trs_end)
            for midpt in df['segment_original_midpoint'] ], 
            index=df.index).dropna()
    
        logging.debug("{} matching lines from transcript".format(len(trs_indices)))
        logging.debug("{} rows, {} columns in transcript table".format(
            transcript_table.shape[0],transcript_table.shape[1]))
        matching_lines = transcript_table.iloc[trs_indices, 
                [transcript_start_col, transcript_end_col, 
                transcript_text_col]].set_index(trs_indices.index)
        df = pd.concat([df, matching_lines], axis=1)
    except IOError:
        logging.debug("Unable to retrieve transcript data", exc_info=True)
    return df

def case_pipeline(unique_id, audio_path, alignments_path, video_path=None, 
                  transcript_path=None, creak_results_path=None,
                  do_creak=True, do_cv=True, do_acoustic=True):
    """Runs the pipeline on a single 'case' (unique speaker/session combination)
    collecting requested data. Right now, that data includes acoustic measurements,
    creak detection output, and computer vision information. If acoustic data are 
    requested, then metadata about segment, 
    word, and line from which each measurement originates are all added as well.
    
    Returns a pandas dataframe if do_acoustic is True, with all requested data merged
    together intelligently. If do_acoustic is False, then attempts to return a 
    dict with other requested information included as individual pandas dataframes.
    If necessary resources are missing for any requested analysis, the function will 
    return None.
    """
    
    logging.info("Case pipeline: " + unique_id)

    working_table_path = os.path.join(working_dir(), unique_id + ".tsv")
    try:
        acous_df = pd.read_table(working_table_path, sep="\t")
        return acous_df
    except:
        logging.debug("No results yet exist for {}".format(unique_id))

    logging.debug(("Audio at {audio}\nAlignments at {alignments}\n"
                  "Video at {video}\nTranscript at {transcript}\n"
                  "Creak results at {creak}").format(
        audio=audio_path, alignments=alignments_path, video=video_path,
        transcript=transcript_path, creak=creak_results_path))
    # check that we have necessary resources, bail if not (to save processing time)
    if do_acoustic and (not audio_path or not alignments_path or not transcript_path):
        logging.warning("Acoustic measurements requested but resources are missing.")
        return None
    elif do_creak and (not creak_results_path):
        logging.warning("Creak detection requested but resources are missing.")
        return None
    elif do_cv and (not video_path):
        logging.warning("Computer vision requested but resources are missing.")
        return None
    
    # get results from subcomponents
    results_dict = {}
    if do_creak:
        logging.info("Doing creak detection")
        try:
            creak_results = do_creak_detection(creak_results_path)
            results_dict['creak'] = creak_results
        except KeyboardInterrupt:
            raise
        except:
            logging.error("Creak detection failed", exc_info=True)
    if do_cv:
        logging.info("Doing computer vision")
        cv_table_path = os.path.join(working_dir(), unique_id + "_cv.tsv")
        try:
            cv_results = zip(*pd.read_table(cv_table_path, sep='\t').values.tolist())
            results_dict['cv'] = cv_results
        except IOError:
            try:
                cv_results = do_cv_annotation(video_path)
                results_dict['cv'] = cv_results
                pd.DataFrame(zip(*cv_results), columns=['time','movamp','smile']).to_csv(
                    cv_table_path, sep='\t', index=False)
            except KeyboardInterrupt:
                raise
            except:
                logging.error("Computer vision failed", exc_info=True)

    # presumably every call to the case pipeline will request acoustic measurements, so right 
    # now the behavior of the pipeline is mostly defined in this conditional
    # (adding metadata etc); if only creak or CV info are requested, they are returned
    # in the dictionary results_dict and not merged into a single table
    if do_acoustic:
        logging.info("Doing acoustic annotation")
        try:
            acous_df = pd.read_table(StringIO.StringIO(
                acous.do_acoustic_annotation(audio_path, alignments_path, 
                                             working_wav_dir=tmp_wav_dir)), 
                na_values="--undefined--")
        except TypeError:
            logging.error(("Could not do acoustic annotation, "
                             "possibly because alignments missing"), exc_info=True)
            return None
        except AttributeError:
            logging.error(("Could not do acoustic annotation, "
                             "possibly because alignments missing"), exc_info=True)
            return None
        
        logging.info("Acoustic analysis complete...")

        # convert from (hybrid) long to wide
        acous_df['chunk_id'] = acous_df['Filename'] +  acous_df['Chunk'].map(str)
        other_metadata = acous_df.loc[:,['chunk_id', 'Filename', 'Segment label', 'Segment start', 
            'Segment end', 'Chunk', 'Window_start', 'Window_end']].drop_duplicates()
        other_metadata = other_metadata.set_index('chunk_id')
        acous_df = acous_df.pivot(index='chunk_id', columns='Measure', values='Value')
        
        
        acous_df = pd.merge(acous_df, other_metadata,left_index=True,right_index=True)

        # add in original timestamp, based on Filename field (possibly fragile--beware)
        acous_df['segment_original_timestamp'] = acous_df['Filename'].map(lambda x: re.sub(r"^.*_([0-9]+).*?$", r"\1", x)).map(float) / 1000 + acous_df['Segment start']
        acous_df['segment_original_end'] = acous_df['segment_original_timestamp'] + (acous_df['Segment end'] - acous_df['Segment start'])
        acous_df['segment_original_midpoint'] = acous_df['segment_original_timestamp'] + (acous_df['Segment end'] - acous_df['Segment start']) / 2
        acous_df['chunk_original_timestamp'] = acous_df['segment_original_timestamp'] + acous_df['Window_start']
        
        # combine acoustics with cv, metadata if necessary/possible
        # CV results
        try:
            # interpolate values of movamp and smile according to time
            acous_df['movamp_interp'] = np.interp(acous_df['chunk_original_timestamp'], 
                                                  cv_results[0], cv_results[1])
            acous_df['smiles_interp'] = np.interp(acous_df['chunk_original_timestamp'], 
                                                  cv_results[0], cv_results[2]) > 0.5
        except NameError:
            logging.warning("No computer vision annotation information added", exc_info=True)

        # Creak results: translate intervals from detector into boolean values at each 
        # timepoint
        try:
            acous_df = acous_df.sort('chunk_original_timestamp')
            acous_df['creak_binary'] = [ interval is not None for interval in 
                points_to_interval_indexes(acous_df['chunk_original_timestamp'], 
                                           creak_results['start'], creak_results['end']) ]
        except NameError:
            logging.warning("No creak detection information added", exc_info=True)
        
        # add observation metadata
        # two sources of data: alignments (get word label + start/end) and transcript 
        # (get utterance label + start/end)
        acous_df = add_alignments_to_acoustic(acous_df,alignments_path)
        # get data from transcript, also uses midpoint checking
        acous_df = add_transcript_data_to_acoustic(acous_df,transcript_path)
                
        # save a copy in the temporary directory
        acous_df.to_csv(working_table_path, sep="\t")
        logging.debug("Saved a copy of this case's results to {}".format(
            working_table_path))
        return acous_df

    # if acoustic measurements are not requested, return the dictionary of other results
    return results_dict

def get_cases_from_directory(case_path, case_filename_pattern=livingroom_filename_pattern, case_id_pattern=r"\2_\3"):
    """return a list of unique case IDs ('INTYYY_XXX') based on files matching 
    the regex in case_filename_pattern in the directory given in case_path"""
    
    case_filename_re = re.compile(case_filename_pattern)
    file_list = os.listdir(case_path)
    case_list = [ case_filename_re.sub(case_id_pattern, filename) for filename in 
                    file_list if case_filename_re.search(filename) != None ]
    return case_list
    

def unique_id_to_data_path(unique_id, data_dir=livingroom_root + "audio", 
                           data_filename_pattern=livingroom_pattern_template + ".(wav)$"):
    """Translates a unique ID (INTXXX_YYY) where XXX is a session ID and YY is a user ID
    into a full path containing the first filename in data_dir that meets the criteria
    specified in the template regex data_filename_pattern. The strings USER and SESSION 
    are to be used in the data_filename_pattern argument, which is otherwise a valid 
    regex, to indicate where the session and user IDs should be inserted in the file 
    naming schema."""
    
    # fill in template for data filename pattern with actual user id and session id
    data_filename_pattern = data_filename_pattern.replace("USER", re.sub(unique_id_pattern, r"\2", unique_id))
    data_filename_pattern = data_filename_pattern.replace("SESSION", re.sub(unique_id_pattern, r"\1", unique_id))
    data_filename_re = re.compile(data_filename_pattern)
    
    data_file_list = [ filename for filename in os.listdir(data_dir) if data_filename_re.search(filename) != None ]
    
    # just return the first result, if any
    if len(data_file_list) > 0:
        return os.path.join(data_dir, data_file_list[0])
    else:
        return None


def unique_id_to_audio_path(unique_id, data_dir=livingroom_root + "audio"):
    return unique_id_to_data_path(unique_id, data_dir=data_dir, data_filename_pattern=
                                  livingroom_pattern_template + ".(wav)$")

def unique_id_to_video_path(unique_id, data_dir=livingroom_root + "video"):
    return unique_id_to_data_path(unique_id, data_dir=data_dir, data_filename_pattern=
                                  livingroom_pattern_template + ".(mov)$")

def unique_id_to_alignments_path(unique_id, data_dir=livingroom_root + "annotations"):
    return unique_id_to_data_path(unique_id, data_dir=data_dir, data_filename_pattern=
                                  livingroom_pattern_template + ".(TextGrid)$")

def unique_id_to_transcript_path(unique_id, data_dir=livingroom_root + "annotations"):
    return unique_id_to_data_path(unique_id, data_dir=data_dir, data_filename_pattern=
                                  livingroom_pattern_template + ".(txt)$")


def directory_pipeline(video_path=livingroom_root + "video", 
                       audio_path=livingroom_root + "audio", 
                       alignments_path=livingroom_root + "annotations",
                       exclude_cases=[]):
    """ Run pipeline on a whole directory"""
    
    case_list = [ case for case in get_cases_from_directory(video_path) if case not in
                    exclude_cases ]
    results_by_case = dict([ (case_id, case_pipeline(case_id, 
        unique_id_to_audio_path(case_id, audio_path), 
        unique_id_to_alignments_path(case_id,alignments_path),
        video_path=unique_id_to_video_path(case_id, video_path), 
        transcript_path=unique_id_to_transcript_path(case_id,alignments_path),
        creak_results_path=unique_id_to_data_path(case_id, creak_tmp_dir, 
                livingroom_pattern_template + ".(txt)$"),
        do_creak=True, do_cv=True, do_acoustic=True)) for case_id in case_list ])
    
    # add unique identifier and split into speaker and session ID fields as well
    results = pd.concat([ pd.concat([pd.Series(key, index=df.index, 
        name="speaker_session_id"), pd.DataFrame(df)], axis=1)
        for key, df in results_by_case.iteritems() if df is not None ], axis=0)
    results['session_id'], results['speaker_id'] = zip(
        *map(lambda x: x.strip('INT').split('_'), results['speaker_session_id']))

    return results
     

def stump_main():
    """Testing only, do not run"""
    # measurements
    results = directory_pipeline(video_path="../../data/stump/video",
        audio_path="../../data/stump/audio",
        alignments_path="../../data/stump/annotations")
    # metadata
    results = adorn_with_session_info(results,
        ("/Users/patrickcallier/Dropbox/ongoing/postdoc/"
        "livingroom/data/stump/Living_Room_Participant_Survey.csv"),
        ("/Users/patrickcallier/Dropbox/ongoing/postdoc/"
        "livingroom/livingroom/scripts/utilities/qualtricsheadings.txt"),
        ("/Users/patrickcallier/Dropbox/ongoing/postdoc/"
        "livingroom/data/stump/Session_Information_Post.csv"),
        ("/Users/patrickcallier/Dropbox/ongoing/postdoc/"
        "livingroom/livingroom/scripts/utilities/sessioninfoheadings.txt"))
    # getting better timestamps
    results = add_offsets(results)
    
    return results.to_csv(None, sep="\t", encoding="utf-8")


def main():
    # measurements
    results = directory_pipeline()
    # metadata
    results = adorn_with_session_info(results,
        ("/Users/BigBrother/Dropbox/Patrick_BigBrother/"
        "Living_Room_Participant_Survey.csv"),
        ("/Users/BigBrother/Dropbox/Patrick_BigBrother/"
        "livingroom/scripts/utilities/qualtricsheadings.txt"),
        ("/Users/BigBrother/Dropbox/Patrick_BigBrother/"
        "Session_Information_Post.csv"),
        ("/Users/BigBrother/Dropbox/Patrick_BigBrother/"
        "livingroom/scripts/utilities/sessioninfoheadings.txt"))
    # get better timestamps
    results = add_offsets(results)
    
    return results   


if __name__ == '__main__':
    results = main()
    print results
