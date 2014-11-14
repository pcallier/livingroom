#!/bin/bash
# This batch script runs an analysis pipeline for the Living Room
# data, retrieving measurements relevant for nasality
# and voice quality projects, among others.
#
# Arguments:	metadata_path -	location of a table with metadata on speakers to analyze. 
#							 	see project root for headers with what fields it needs to have.
#				results_dir - 	the folder that into which results will be deposited, 
#									should obviously be writeable (work-in-progress also hidden here)
#				survey_path - path to the survey results table from the Talk Lab Dashboard, format described elsewhere
#
#	Patrick Callier, 2014
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
TGWORKING="${RESULTS_DIR}/.working/tgs"
if [ ! -d "$TGWORKING" ]; then
	mkdir -p "$TGWORKING"
fi
WAVWORKING="${RESULTS_DIR}/.working/wavs"
if [ ! -d "$WAVWORKING" ]; then
	mkdir -p "$WAVWORKING"
fi
PROJECT_INFO="${PROJECT_SETTINGS}/info.log"
SCRIPT_DIR=$(dirname ${0})
SURVEY_PATH=$(cd $(dirname $3); pwd)/$(basename $3)

echo `date -u`: "METADATA_PATH=$METADATA_PATH; RESULTS_DIR=$RESULTS_DIR; TGWORKING=$TGWORKING; WAVWORKING=$WAVWORKING" >> "$PROJECT_INFO" 2>&1

# if you need to change the remote working location, just change the script since other things
# (the matlab invocation in particular) will also need to change
#WAVWORKINGREMOTE=/afs/.ir/users/p/c/pcallier/private/livingroom-util/wav_working/

echo "Metadata at $METADATA_PATH" >> "$PROJECT_INFO"
echo "Starting to read metadata..." >> "$PROJECT_INFO"

sed 1d $METADATA_PATH | while IFS=$'\t' read SPEAKER_ID INTERACTION_ID SURVEY_ID DATE FAMILIARITY ANGLE SPEAKER_FIRST SPEAKER_LAST GENDER WAV_PATH TG_PATH TRS_DATA_PATH; do
	UNIQUE_SPEAKER="${SPEAKER_ID}_INT${INTERACTION_ID}"
	echo `date -u`: "Starting to work with ${UNIQUE_SPEAKER}..."  >> "$PROJECT_INFO"
	BIGWAV=$WAV_PATH
	TRSDATA=$TRS_DATA_PATH
	TGFILE=$TG_PATH
	#echo "'$SPEAKER_ID' '$INTERACTION_ID' '$SURVEY_ID' '$DATE' '$FAMILIARITY' '$ANGLE' '$SPEAKER_FIRST' '$SPEAKER_LAST' '$GENDER' '$WAV_PATH' '$TG_PATH' '$TRS_DATA_PATH'" >> "$PROJECT_INFO"
	echo "BIGWAV=$BIGWAV; TRSDATA=$TRSDATA; TGFILE=$TGFILE"  >> "$PROJECT_INFO"
	# the results end up in the directory we specify (results/.working, which is hidden) with the name DATE_SPEAKER_SESSION_FAMILIARITY_ANGLE_pitchresults.txt
	if [ "$GENDER" = "male" ]; then M_F="M"; else M_F="F"; fi
	FILE_CODE="${DATE}_${SPEAKER_ID}${M_F}_${INTERACTION_ID}_${FAMILIARITY}_${ANGLE}"

	MEASUREMENTS_PATH=${RESULTS_DIR}/.working/${UNIQUE_SPEAKER}_pitchresults.txt
	MEASUREMENTS_WIDE_PATH=${RESULTS_DIR}/.working/${UNIQUE_SPEAKER}_pitchresults_wide.txt
	MEASUREMENTS_DECORATED_PATH=${RESULTS_DIR}/.working/${UNIQUE_SPEAKER}_pitchresults_decorated.txt
	MEASUREMENTS_RESHAPED_PATH=${RESULTS_DIR}/.working/${UNIQUE_SPEAKER}_pitchresults_reshaped.txt
	MEASUREMENTS_FINAL_PATH=${RESULTS_DIR}/${FILE_CODE}.tsv

	# check to see if we already have results for this speaker
	if [ -f "$MEASUREMENTS_FINAL_PATH" ]; then echo `date -u`: "Results exist for ${SPEAKER_ID}_INT${INTERACTION_ID}. Next..." >> "$PROJECT_INFO"; continue 1; fi
	
		
	if [ -f "$BIGWAV" ]; then BIGWAV_READY=1; else BIGWAV_READY=0; fi
	if [ -f "$TRSDATA" ]; then TRSDATA_READY=1; else TRSDATA_READY=0; fi
	if [ -f "$TGFILE" ]; then TGFILE_READY=1; else TGFILE_READY=0; fi
	
	if [ $BIGWAV_READY -eq 0 ] || [ $TRSDATA_READY -eq 0 ] || [ $TGFILE_READY -eq 0  ]; then
		echo `date -u`: "Files not found; BIGWAV_READY=$BIGWAV_READY TRSDATA_READY=$TRSDATA_READY TGFILE_READY=$TGFILE_READY" >> "$PROJECT_INFO"
		continue
	fi	

	# this is the WORKING folder for TGs, not the original location (which is in TGFILE already)
	# copy TG to working directory
	STRIPPEDTG=${TGWORKING}/${FILE_CODE}.TextGrid
	cp $TGFILE $STRIPPEDTG
	# add utterance info to TG
	/Applications/Praat.app/Contents/MacOS/Praat ${SCRIPT_DIR}/add_utterances_to_tg.praat "$TRSDATA" "$STRIPPEDTG" 1 0 >> "$PROJECT_INFO" 2>&1

	if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi

	# split again, now for analysis (phone-sized)
	echo `date -u`: "Chopping up utterances for analysis..." >> "$PROJECT_INFO"
	# Praat's deleting takes too long, use shell
	find ${WAVWORKING} -type f -delete
	if [ $? -ne 0 ]; then echo "Find/delete failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
	/Applications/Praat.app/Contents/MacOS/Praat "${SCRIPT_DIR}/save_labeled_intervals_to_wav_sound_files.praat" "$BIGWAV" "$STRIPPEDTG" "$WAVWORKING" 1 0 0 1 1 1 0.025 >> "$PROJECT_INFO" 2>&1
	if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
	# run measurements script
	echo `date -u`: "Starting measurements..." >> "$PROJECT_INFO"
	/Applications/Praat.app/Contents/MacOS/Praat "${SCRIPT_DIR}/PraatVoiceSauceImitator.praat" "${SPEAKER_ID}_INT${INTERACTION_ID}" "$WAVWORKING" .wav  "$WAVWORKING" .TextGrid "${RESULTS_DIR}/.working" 1 0.025 0.025 0.010 10 "$GENDER" 500 550 1485 1650 2475 2750 >> "$PROJECT_INFO" 2>&1
	if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
	echo `date -u`: "Done with measurements..." >> "$PROJECT_INFO"
	# Decorate
	echo `date -u`: "Converting to wide format..." >> "$PROJECT_INFO"
	rscript --slave "${SCRIPT_DIR}/long_to_wide.r" "$MEASUREMENTS_PATH" "$MEASUREMENTS_WIDE_PATH" >> "$PROJECT_INFO" 2>&1
	if [ $? -ne 0 ]; then echo "Rscript failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
	echo `date -u`: "Adding extra information from text grid..." >> "$PROJECT_INFO"
	/Applications/Praat.app/Contents/MacOS/Praat "${SCRIPT_DIR}/decoratedata.praat" "${MEASUREMENTS_WIDE_PATH}" "${STRIPPEDTG}" "${SURVEY_PATH}" "${SURVEY_ID}" "${MEASUREMENTS_DECORATED_PATH}" >> "$PROJECT_INFO" 2>&1
	if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
	
	# This takes wayyy too long
	#echo `date -u`: "Adding extra niceties (almost done)..." >> "$PROJECT_INFO"
	#rscript --slave "${SCRIPT_DIR}/reshapedata.r" "$MEASUREMENTS_DECORATED_PATH" "$MEASUREMENTS_RESHAPED_PATH" >> "$PROJECT_INFO" 2>&1
	#if [ $? -ne 0 ]; then echo "Rscript failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi

	# clean-up, etc
	cp $MEASUREMENTS_DECORATED_PATH $MEASUREMENTS_FINAL_PATH >> "$PROJECT_INFO" 2>&1
	find ${WAVWORKING} -type f -delete >> "$PROJECT_INFO" 2>&1
	echo `date -u`: "Done with $UNIQUE_SPEAKER." >> "$PROJECT_INFO"
done

echo `date -u`: "Goodbye..." >> "$PROJECT_INFO"

