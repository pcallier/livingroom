#!/bin/bash
# This batch script runs an analysis pipeline for the Voices of
# California data, retrieving measurements relevant for nasality
# and voice quality projects, among others.
#
# Arguments:	metadata_path -	location of a table with metadata on speakers to analyze. 
#							 	see project root for headers with what fields it needs to have.
#				project_root - 	the folder that contains the folder scripts
#				tg_working -	a working folder for holding the modified alignments textgrid
#				wav_working -	a working folder for small file chunks
#

METADATA_PATH=`cd $1; pwd`
PROJECT_ROOT=`cd $2; pwd`
TGWORKING=`cd $3; pwd`
WAVWORKING=`cd $4; pwd`
# if you need to change the remote working location, just change the script since other things
# (the matlab invocation in particular) will also need to change
WAVWORKINGREMOTE=/afs/.ir/users/p/c/pcallier/private/livingroom-util/wav_working/


while read SPEAKER GENDER LOCATION AGE RACE SEXUAL_ORIENTATION WAV_PATH TG_PATH TRS_DATA_PATH; do
	BIGWAV=$WAV_PATH
	TRSDATA=$TRS_DATA_PATH
	TGFILE=$TG_PATH
	# this is the WORKING folder for TGs, not the original location (which is in TGFILE already)
	# strip Interviewer information from TG
	STRIPPEDTG=${TGWORKING}/${SPEAKER}.TextGrid
	/Applications/Praat.app/Contents/MacOS/Praat ${PROJECT_ROOT}/livingroom/scripts/vocal_strip_interviewer.praat "${TGFILE}" "$STRIPPEDTG"
	# add utterance info to TG
	/Applications/Praat.app/Contents/MacOS/Praat ${PROJECT_ROOT}/livingroom/scripts/add_utterances_to_tg.praat "$TRSDATA" "$STRIPPEDTG" 1
	# put chopped-up audio data onto remote
	# this requires ssh authentication to my Stanford account, and for the AFS file
	# system to be mounted. We're working on making this less messy
	# Chop up WAV into bits (phrase-sized)
	/Applications/Praat.app/Contents/MacOS/Praat ${PROJECT_ROOT}/livingroom/save_labeled_intervals_to_wav_sound_files.praat "$BIGWAV" "$STRIPPEDTG" "$WAVWORKINGREMOTE" 1 0 0 3 0 1 0.025 
	# Creak detection
	# copy creak-related scripts to remote (sigh)
	scp -r ${PROJECT_ROOT}/livingroom/scripts/creak_segmentation pcallier@cardinal.stanford.edu:~/private/livingroom-util/
	ssh pcallier@corn.stanford.edu <<ENDSSH
		sleep 5
		matlab -r "cd private/covarep; startup; cd ~/private/livingroom-util/creak_segmentation/; do_creak_detection('../wav_working/'); exit"
		rm -rf ~/private/livingroom-util/creak_segmentation
ENDSSH
	# decorate big textgrid with creak
	/Applications/Praat.app/Contents/MacOS/Praat ${PROJECT_ROOT}/livingroom/scripts/creak_segmentation/add_creak_info_to_tg.praat "$STRIPPEDTG" "$WAVWORKINGREMOTE" 4
	# Clean up
	find ${WAVWORKINGREMOTE} -type f -delete

	# split again, now for analysis (phone-sized)
	# Praat's deleting takes too long
	find ${WAVWORKING} -type f -delete
	/Applications/Praat.app/Contents/MacOS/Praat ${PROJECT_ROOT}/livingroom/save_labeled_intervals_to_wav_sound_files.praat "$BIGWAV" "$STRIPPEDTG" "$WAVWORKING" 1 0 0 1 1 1 0.025 
	# run analysis script
	if [ $GENDER="male" ]; then
		GENDERNUMBER=1
	else
		GENDERNUMBER=2
	fi	
	# then analyze
	/Applications/Praat.app/Contents/MacOS/Praat ${PROJECT_ROOT}/livingroom/PraatVoiceSauceImitator.praat "$SPEAKER" "$WAVWORKING" .wav  "$WAVWORKING" .TextGrid "${PROJECT_ROOT}/results" 1 0.025 0.025 0.010 10 "$GENDERNUMBER" 500 550 1485 1650 2475 2750
	# the results end up in the directory we specify with the name SPEAKER_pitchresults.txt
	MEASUREMENTS_PATH=${PROJECT_ROOT}/results/${SPEAKER}_pitchresults.txt
	MEASUREMENTS_DECORATED_PATH=${PROJECT_ROOT}/results/${SPEAKER}_pitchresults_decorated.txt
	MEASUREMENTS_RESHAPED_PATH=${PROJECT_ROOT}/results/${SPEAKER}_pitchresults_reshaped.txt
	# Decorate
	/Applications/Praat.app/Contents/MacOS/Praat ${PROJECT_ROOT}/livingroom/decoratedata_voices.praat "${MEASUREMENTS_PATH}" "${STRIPPEDTG}" "${METADATA_PATH}" "${MEASUREMENTS_DECORATED_PATH}"
	rscript ${PROJECT_ROOT}/scripts/reshapedata_voices.r "$MEASUREMENTS_DECORATED_PATH" "$MEASUREMENTS_RESHAPED_PATH"
done <$METADATA_PATH

# concatenate all the results


#/Applications/Praat.app/Contents/MacOS/Praat /Volumes/Surfer/users/pcallier/livingroom/scripts/save_labeled_intervals_to_wav_sound_files.praat /Users/BigBrother/Documents/VoCal/Retreat_Sample/RED_Fowler_Ginger.wav /Volumes/Surfer/users/pcallier/tgs/RED_Fowler_Ginger.TextGrid /Volumes/Surfer/users/pcallier/wavs/ 1 0 0 1 1 1 0.025 
