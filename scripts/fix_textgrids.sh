#!/bin/bash
# This batch script runs an analysis pipeline for the Voices of
# California data, retrieving measurements relevant for nasality
# and voice quality projects, among others.
#
# Arguments:	metadata_path -	location of a table with metadata on speakers to analyze. 
#							 	see project root for headers with what fields it needs to have.
#				results_dir - 	the folder that contains the results, will also hold some working files
#				tg_working -	a working folder for temporarily holding the modified alignments textgrid
#				wav_working -	a working folder for small WAV file chunks, is cleared of all files during script run
#

METADATA_PATH=$(cd $(dirname $1); pwd)/$(basename $1)
RESULTS_DIR=`cd $2; pwd`
if [ ! -d "${RESULTS_DIR}/.working" ]; then
	mkdir -p "${RESULTS_DIR}/.working"
fi
PROJECT_SETTINGS="${RESULTS_DIR}/.extra"
if [ ! -d "$PROJECT_SETTINGS" ]; then
	mkdir -p "$PROJECT_SETTINGS"
fi
TGWORKING=`cd $3; pwd`
WAVWORKING=`cd $4; pwd`
PROJECT_SETTINGS="${RESULTS_DIR}/.extra"
if [ ! -d "$PROJECT_SETTINGS" ]; then
	mkdir "$PROJECT_SETTINGS"
fi
PROJECT_INFO="${PROJECT_SETTINGS}/info.log"
SCRIPT_DIR=$(dirname ${0})


sed 1d "$METADATA_PATH" | while IFS=$'\t' read SPEAKER GENDER LOCATION AGE RACE SEXUAL_ORIENTATION WAV_PATH TG_PATH TRS_DATA_PATH; do
	echo `date -u`: "Working with $SPEAKER." >> "$PROJECT_INFO"
	#BIGWAV="$WAV_PATH"
	TRSDATA="$TRS_DATA_PATH"
	TGFILE="$TG_PATH"

	# check to see if we already have results for this speaker
	#if [ -f "$MEASUREMENTS_FINAL_PATH" ]; then echo `date -u`: "Results exist for $SPEAKER. Next..." >> "$PROJECT_INFO"; continue 1; fi
	
		
	if [ -f "$BIGWAV" ]; then BIGWAV_READY=1; else BIGWAV_READY=0; fi
	if [ -f "$TRSDATA" ]; then TRSDATA_READY=1; else TRSDATA_READY=0; fi
	if [ -f "$TGFILE" ]; then TGFILE_READY=1; else TGFILE_READY=0; fi
	
	if [ "$TRSDATA_READY" -eq 0 ] || [ "$TGFILE_READY" -eq 0  ]; then
		echo `date -u`: "Files not found; BIGWAV_READY=$BIGWAV_READY TRSDATA_READY=$TRSDATA_READY TGFILE_READY=$TGFILE_READY" >> "$PROJECT_INFO"
		continue
	fi	

	# this is the WORKING folder for TGs, not the original location (which is in TGFILE already)
	# strip Interviewer information from TG
	STRIPPEDTG=${TGWORKING}/${SPEAKER}.TextGrid
	# the alignments textgrid may have more than one speaker in it. the following script removes the interviewer (somewhat intelligently)
	/Applications/Praat.app/Contents/MacOS/Praat ${SCRIPT_DIR}/vocal_strip_interviewer.praat "$TGFILE" "$STRIPPEDTG" >> "$PROJECT_INFO" 2>&1
	if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi

	if [ "$TRSDATA_READY" -ne 0 ]; then
		# add utterance info to TG
		/Applications/Praat.app/Contents/MacOS/Praat ${SCRIPT_DIR}/add_utterances_to_tg.praat "$TRSDATA" "$STRIPPEDTG" 1 1 >> "$PROJECT_INFO" 2>&1
		if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
	fi
done

echo `date -u`: "Goodbye..." >> "$PROJECT_INFO"

#/Applications/Praat.app/Contents/MacOS/Praat /Volumes/Surfer/users/pcallier/livingroom/scripts/save_labeled_intervals_to_wav_sound_files.praat /Users/BigBrother/Documents/VoCal/Retreat_Sample/RED_Fowler_Ginger.wav /Volumes/Surfer/users/pcallier/tgs/RED_Fowler_Ginger.TextGrid /Volumes/Surfer/users/pcallier/wavs/ 1 0 0 1 1 1 0.025 
