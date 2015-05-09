#!/usr/bin/env python
"""acoustic_analysis_livingroom.py
Do the acoustic analysis side of the pipeline. For living room-style data.
Praat must be on the path
"""

import os
import subprocess
import pandas as pd
import logging
logging.basicConfig(level=logging.DEBUG)
import distutils.dir_util
import shutil

def do_acoustic_annotation(audio_path, alignments_path, 
                           working_wav_dir=".tmpwav"):
    """1. split up audio according to alignments in alignments_path
        2. invoke VoiceSauce or whatever
    """
    
    # empty out and create tmp WAV folder (DANGER)
    if working_wav_dir in (".", "/"):
        raise Exception(("Working WAV directory must be deleted" 
                         "but I must not delete {}").format(working_wav_dir))
    shutil.rmtree(working_wav_dir, ignore_errors=True)
    distutils.dir_util.mkpath(os.path.realpath(working_wav_dir))
    
    split_audio(audio_path, alignments_path, working_wav_dir)
    results = invoke_praat_voice_analysis(working_wav_dir)
    return results
    
def split_audio(audio_path, alignments_path, destination_dir):
    phone_tier = 1
    output = subprocess.check_output( \
        ["praat", "utilities/split_wav_file.praat", "\"{}\" \"{}\" \"{}\" 1 1 1 {} 0 1 0.025 _ _".format(
            os.path.abspath(audio_path), 
            os.path.abspath(alignments_path), 
            os.path.abspath(destination_dir), 
            phone_tier)], 
            stderr=subprocess.STDOUT)

def invoke_voicesauce(audio_directory):
    """This will take some work. VoiceSauce itself is 
    pretty dependent on its GUI"""
    
    pass

    
def invoke_praat_voice_analysis(audio_directory):
    """Use the Praat acoustic analysis script to get a bunch of acoustic measures out.
    Return these results as a pandas dataframe
    """
    
    logging.debug("Audio directory:" + audio_directory)
    praat_args = ('{audio_path} .wav' +
        " {textgrid_path} .TextGrid" + 
        " {tier_to_analyze} {padding} {window_length} {timestep}" +
        " {max_duration} {f1ref} {f2ref} {f3ref} {f4ref} {f5ref} {maxformant}" + 
        " {min_f0} {max_f0}").format(
            audio_path=os.path.abspath(audio_directory), 
            textgrid_path=os.path.abspath(audio_directory), 
            tier_to_analyze=1,
            padding=0.025, window_length=0.025, timestep=0.02, max_duration=5,
            f1ref=550, f2ref=1650, f3ref=2750, f4ref=3850, f5ref=4950,        
            maxformant=5500,
            min_f0=50, max_f0=500)
    logging.warning("Analysis arguments: " + praat_args)
    
    output = subprocess.check_output( \
        ["praat", "utilities/praat_voice_measures.praat", praat_args])
    return output