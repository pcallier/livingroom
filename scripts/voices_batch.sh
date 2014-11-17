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

echo `date -u`: "METADATA_PATH=$METADATA_PATH; RESULTS_DIR=$RESULTS_DIR; TGWORKING=$TGWORKING; WAVWORKING=$WAVWORKING; SCRIPT_DIR=$SCRIPT_DIR" >> "$PROJECT_INFO" 2>&1

# if you need to change the remote working location, just change the script since other things
# (the matlab invocation in particular) will also need to change
WAVWORKINGREMOTE=/afs/.ir/users/p/c/pcallier/private/livingroom-util/wav_working/

#for creak segmentation only:
# Log in the user to kerberos: change username if needed!
# kinit pcallier
# aklog
# if [ $? -ne 0 ]; then echo "Failed to get AFS token. Line ${LINENO}" >> "$PROJECT_INFO"; exit 1; fi

echo "Metadata at $METADATA_PATH" >> "$PROJECT_INFO"
echo "Starting to read metadata..." >> "$PROJECT_INFO"

sed 1d $METADATA_PATH | while IFS=$'\t' read SPEAKER GENDER LOCATION AGE RACE SEXUAL_ORIENTATION WAV_PATH TG_PATH TRS_DATA_PATH; do
	echo `date -u`: "Starting to work with $SPEAKER..."  >> "$PROJECT_INFO"
	BIGWAV=$WAV_PATH
	TRSDATA=$TRS_DATA_PATH
	TGFILE=$TG_PATH
	# the results end up in the directory we specify (results/.working, which is hidden) with the name SPEAKER_pitchresults.txt
	MEASUREMENTS_PATH=${RESULTS_DIR}/.working/${SPEAKER}_pitchresults.txt
	MEASUREMENTS_WIDE_PATH=${RESULTS_DIR}/.working/${SPEAKER}_pitchresults_wide.txt
	MEASUREMENTS_DECORATED_PATH=${RESULTS_DIR}/.working/${SPEAKER}_pitchresults_decorated.txt
	MEASUREMENTS_RESHAPED_PATH=${RESULTS_DIR}/.working/${SPEAKER}_pitchresults_reshaped.txt
	MEASUREMENTS_FINAL_PATH=${RESULTS_DIR}/${SPEAKER}.tsv

	# check to see if we already have results for this speaker
	if [ -f "$MEASUREMENTS_FINAL_PATH" ]; then echo `date -u`: "Results exist for $SPEAKER. Next..." >> "$PROJECT_INFO"; continue 1; fi
	
		
	if [ -f "$BIGWAV" ]; then BIGWAV_READY=1; else BIGWAV_READY=0; fi
	if [ -f "$TRSDATA" ]; then TRSDATA_READY=1; else TRSDATA_READY=0; fi
	if [ -f "$TGFILE" ]; then TGFILE_READY=1; else TGFILE_READY=0; fi
	
	if [ $BIGWAV_READY -eq 0 ] || [ $TGFILE_READY -eq 0  ]; then
		echo `date -u`: "Files not found; BIGWAV_READY=$BIGWAV_READY TRSDATA_READY=$TRSDATA_READY TGFILE_READY=$TGFILE_READY" >> "$PROJECT_INFO"
		continue
	fi	

	# this is the WORKING folder for TGs, not the original location (which is in TGFILE already)
	# strip Interviewer information from TG
	STRIPPEDTG=${TGWORKING}/${SPEAKER}.TextGrid
	# the alignments textgrid may have more than one speaker in it. the following script removes the interviewer (somewhat intelligently)
	/Applications/Praat.app/Contents/MacOS/Praat ${SCRIPT_DIR}/vocal_strip_interviewer.praat "$TGFILE" "$STRIPPEDTG" >> "$PROJECT_INFO" 2>&1
	if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi

	if [ $TRSDATA_READY -ne 0 ]; then
		# add utterance info to TG
		/Applications/Praat.app/Contents/MacOS/Praat ${SCRIPT_DIR}/add_utterances_to_tg.praat "$TRSDATA" "$STRIPPEDTG" 1 1 >> "$PROJECT_INFO" 2>&1
		if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
	fi

# 	# UPDATE: Creak detection jams up pipeline, will spin off to its own process
	# put chopped-up audio data onto remote
	# this requires ssh authentication to my Stanford account (taken care of above), and for the AFS file
	# system to be mounted (this you must do yourself)
	# TODO: check for access to afs
	# Chop up WAV into bits (phrase-sized)
# 	echo `date -u`: "Chopping up utterances for creak detection..." >> "$PROJECT_INFO"
# 	/Applications/Praat.app/Contents/MacOS/Praat ${SCRIPT_DIR}/save_labeled_intervals_to_wav_sound_files.praat "$BIGWAV" "$STRIPPEDTG" "$WAVWORKINGREMOTE" 1 0 0 3 0 1 0.025 >> "$PROJECT_INFO" 2>&1
# 	if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
# 	# Creak detection
# 	# copy creak-related scripts to remote (sigh)
# 	scp -r "${SCRIPT_DIR}/creak_segmentation" pcallier@corn.stanford.edu:~/private/livingroom-util/ >> "$PROJECT_INFO" 2>&1
# 	if [ $? -ne 0 ]; then echo "scp failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
# 	ssh pcallier@corn.stanford.edu <<ENDSSH
# 		sleep 5
# 		module load matlab
# 		matlab -r "cd private/covarep; startup; cd ~/private/livingroom-util/creak_segmentation/; do_creak_detection('../wav_working/'); exit"
# 		rm -rf ~/private/livingroom-util/creak_segmentation
# 		logout
# ENDSSH
# 	echo `date -u`: "Done with creak segmentation." >> "$PROJECT_INFO"
# 	# TODO: need some fancy error checking here
# 	# decorate big textgrid with creak
# 	/Applications/Praat.app/Contents/MacOS/Praat "${SCRIPT_DIR}/creak_segmentation/add_creak_info_to_tg.praat" "$STRIPPEDTG" "$WAVWORKINGREMOTE" 4 >> "$PROJECT_INFO" 2>&1
# 	if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
# 	# Clean up
# 	find ${WAVWORKINGREMOTE} -type f -delete

	if [ ! -f $MEASUREMENTS_RESHAPED_PATH ]; then
		if [ ! -f $MEASUREMENTS_DECORATED_PATH ]; then
			if [ ! -f $MEASUREMENTS_WIDE_PATH ]; then
				if [ ! -f $MEASUREMENTS_PATH ]; then
					# split again, now for analysis (phone-sized)
					echo `date -u`: "Chopping up into phone-sized chunks for analysis..." >> "$PROJECT_INFO"
					# Praats deleting takes too long, use shell
					find ${WAVWORKING} -type f -delete
					if [ $? -ne 0 ]; then echo "Find/delete failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
					/Applications/Praat.app/Contents/MacOS/Praat "${SCRIPT_DIR}/save_labeled_intervals_to_wav_sound_files.praat" "$BIGWAV" "$STRIPPEDTG" "$WAVWORKING" 1 0 0 1 1 1 0.025 >> "$PROJECT_INFO" 2>&1
					if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
					# run measurements script
					echo `date -u`: "Starting measurements..." >> "$PROJECT_INFO"
					/Applications/Praat.app/Contents/MacOS/Praat "${SCRIPT_DIR}/PraatVoiceSauceImitator.praat" "$SPEAKER" "$WAVWORKING" .wav  "$WAVWORKING" .TextGrid "${RESULTS_DIR}/.working" 1 0.025 0.025 0.010 10 "$GENDER" 500 550 1485 1650 2475 2750 >> "$PROJECT_INFO" 2>&1
					if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; rm ${MEASUREMENTS_PATH}; continue; fi
					echo `date -u`: "Done with measurements..." >> "$PROJECT_INFO"
				fi
				# Decorate
				echo `date -u`: "Converting to wide format..." >> "$PROJECT_INFO"
				rscript --slave "${SCRIPT_DIR}/long_to_wide.r" "$MEASUREMENTS_PATH" "$MEASUREMENTS_WIDE_PATH" >> "$PROJECT_INFO" 2>&1
				if [ $? -ne 0 ]; then echo "Rscript failed. Line ${LINENO}" >> "$PROJECT_INFO"; rm ${MEASUREMENTS_WIDE_PATH}; continue; fi
			fi
			echo `date -u`: "Adding extra information from text grid..." >> "$PROJECT_INFO"
			/Applications/Praat.app/Contents/MacOS/Praat "${SCRIPT_DIR}/decoratedata_voices.praat" "${MEASUREMENTS_WIDE_PATH}" "${STRIPPEDTG}" "${METADATA_PATH}" "${MEASUREMENTS_DECORATED_PATH}" "${SPEAKER}" >> "$PROJECT_INFO" 2>&1
			if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; rm ${MEASUREMENTS_DECORATED_PATH}; continue; fi
		fi	
		# This takes wayyy too long
		#echo `date -u`: "Adding extra niceties (almost done)..." >> "$PROJECT_INFO"
		#rscript --slave "${SCRIPT_DIR}/reshapedata_voices.r" "$MEASUREMENTS_DECORATED_PATH" "$MEASUREMENTS_RESHAPED_PATH" >> "$PROJECT_INFO" 2>&1
		#if [ $? -ne 0 ]; then echo "Rscript failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
	fi
	# clean-up, etc
	cp $MEASUREMENTS_DECORATED_PATH $MEASUREMENTS_FINAL_PATH >> "$PROJECT_INFO" 2>&1
	find ${WAVWORKING} -type f -delete >> "$PROJECT_INFO" 2>&1
	echo `date -u`: "Done with $SPEAKER." >> "$PROJECT_INFO"
done

echo `date -u`: "Goodbye..." >> "$PROJECT_INFO"

#/Applications/Praat.app/Contents/MacOS/Praat /Volumes/Surfer/users/pcallier/livingroom/scripts/save_labeled_intervals_to_wav_sound_files.praat /Users/BigBrother/Documents/VoCal/Retreat_Sample/RED_Fowler_Ginger.wav /Volumes/Surfer/users/pcallier/tgs/RED_Fowler_Ginger.TextGrid /Volumes/Surfer/users/pcallier/wavs/ 1 0 0 1 1 1 0.025 
