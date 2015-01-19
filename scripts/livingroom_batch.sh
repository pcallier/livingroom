#!/bin/bash
# This batch script runs an analysis pipeline for the Living Room
# data, retrieving measurements relevant for nasality
# and voice quality projects, among others.
#
# Arguments:	
#				results_dir - 	the folder that into which results will be deposited, 
#									should obviously be writeable (work-in-progress also hidden here)
#				survey_path - path to the survey results table from the Talk Lab Dashboard, format described elsewhere
#
#	Patrick Callier, 2014
#
#	typical invocation: livingroom_batch.sh /Volumes/Surfer/users/pcallier/livingroom/livingroomresults /Volumes/Surfer/users/pcallier/livingroom/livingroom_metadata/responses-all.tsv
#

RESULTS_DIR=`cd "$1"; pwd`
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
SCRIPT_DIR=$(dirname "${0}")
SURVEY_PATH=$(cd $(dirname "$2"); pwd)/$(basename "$2")

echo `date -u`: "RESULTS_DIR=$RESULTS_DIR; TGWORKING=$TGWORKING; WAVWORKING=$WAVWORKING" >> "$PROJECT_INFO" 2>&1

# if you need to change the remote working location, just change the script since other things
# (the matlab invocation in particular) will also need to change
#WAVWORKINGREMOTE=/afs/.ir/users/p/c/pcallier/private/livingroom-util/wav_working/
WAV_DIR="/Volumes/data_drive/corpora/living_room/data/audio"
TRS_DIR="/Volumes/data_drive/corpora/living_room/data/annotations"
MOV_DIR="/Volumes/data_drive/corpora/living_room/data/video"

echo "Metadata at $SURVEY_PATH" >> "$PROJECT_INFO"
echo "Starting to read metadata..." >> "$PROJECT_INFO"

# take great care--multiple tabs in a row are interpreted as ONE delimiter, so stick something in between tabs
sed 1d "$SURVEY_PATH" | while IFS=$'\t' read lastname firstname user_id internal_user_id session_id internal_session_id session_start session_end no_of_participants question_data other_info relationship relationship_more interlocutor_age interlocutor_gender interlocutor_race interlocutor_sexual_orientation enjoyed_self interlocutor_enjoyed felt_comfortable_self interlocutor_felt_comfortable we_clicked hang_out_group hang_out_alone go_on_a_date set_them_up more_comments age gender race sexual_orientation attended_highschool highschool finished_highschool attended_twoyear twoyear finished_twoyear attended_fouryear fouryear finished_fouryear attended_professional professional finished_professional attended_masters masters finished_masters attended_doctoral doctoral finished_doctoral other_education profession placelived_1 whenlived_1 placelived_2 whenlived_2 placelived_3 whenlived_3 placelived_4 whenlived_4 placelived_5 whenlived_5 placelived_6 whenlived_6 userinforecord_id userinforecord_timestamp where_sat; do
	# Translate entries from survey table into standard forms
	# get date from survey, relies on BSD date syntax (may not be portable to GNU/Linux)
	DATE=$(date -jf '%m/%d/%y %H:%M' "$userinforecord_timestamp" '+%Y%m%d')
	# recode gender, expand as necessary
	GENDER=$(echo "$gender" | tr '[:upper:]' '[:lower:]')
	if [ "$GENDER" = "male" ] || [ "$GENDER" = "m" ] || [ "$GENDER" = "man" ]; then M_F="M"; GENDER="male"; else M_F="F"; GENDER="female"; fi
	if [ "$relationship"  = "stranger" ]; then STR_FAM="STR"; else STR_FAM="FAM"; fi
	if [ "$where_sat" = "chair" ]; then CHA_SOF="CHA"; elif [ "$where_sat" = "sofa" ]; then CHA_SOF="SOF"; else CHA_SOF="UNK"; fi
	USER_ID=$(printf "%03d" $( echo "$user_id" | sed 's/^0*//'))
	SESSION_ID=$(printf "%03d" $(echo "$session_id" | sed 's/^0*//'))
	FILE_ID="$DATE"_"$USER_ID""$M_F"_INT"$SESSION_ID"_"$STR_FAM"_"$CHA_SOF"
	echo $FILE_ID
	
	UNIQUE_SPEAKER="$USER_ID"_INT"$SESSION_ID"
	echo `date -u`: "Starting to work with ${UNIQUE_SPEAKER}..."  >> "$PROJECT_INFO"
	
	BIGWAV="$WAV_DIR"/"$FILE_ID".wav
	TRSDATA="$TRS_DIR"/"$FILE_ID".txt
	TGFILE="$TRS_DIR"/"$FILE_ID".TextGrid
	MOVFILE="$MOV_DIR"/"$FILE_ID".mov

	echo "MOVFILE=$MOVFILE; BIGWAV=$BIGWAV; TRSDATA=$TRSDATA; TGFILE=$TGFILE"  >> "$PROJECT_INFO"
	
	
	# These are the paths of the various intermediate and final products
	MEASUREMENTS_PATH="${RESULTS_DIR}/.working/${UNIQUE_SPEAKER}_pitchresults.txt"
	MEASUREMENTS_WIDE_PATH="${RESULTS_DIR}/.working/${UNIQUE_SPEAKER}_pitchresults_wide.txt"
	MEASUREMENTS_DECORATED_PATH="${RESULTS_DIR}/.working/${UNIQUE_SPEAKER}_pitchresults_decorated.txt"
	MEASUREMENTS_SMILES_PATH="${RESULTS_DIR}/.working/${UNIQUE_SPEAKER}_pitchresults_smiles.txt"
	MEASUREMENTS_RESHAPED_PATH="${RESULTS_DIR}/.working/${UNIQUE_SPEAKER}_pitchresults_reshaped.txt"
	MEASUREMENTS_FINAL_PATH="${RESULTS_DIR}/${FILE_ID}.tsv"
	SMILES_MOVAMP_PATH="${RESULTS_DIR}/.working/${UNIQUE_SPEAKER}_smiles_movamp.txt"
	SMILES_DONE_PATH="${RESULTS_DIR}/.working/${UNIQUE_SPEAKER}_smiles_done"

	# check to see if we already have results for this speaker
	if [ -f "$MEASUREMENTS_FINAL_PATH" ]; then echo `date -u`: "Results exist for ${UNIQUE_SPEAKER}. Next..." >> "$PROJECT_INFO"; continue 1; fi
	
		
	if [ -f "$BIGWAV" ]; then BIGWAV_READY=1; else BIGWAV_READY=0; fi
	if [ -f "$TRSDATA" ]; then TRSDATA_READY=1; else TRSDATA_READY=0; fi
	if [ -f "$TGFILE" ]; then TGFILE_READY=1; else TGFILE_READY=0; fi
	if [ -f "$MOVFILE" ]; then MOVFILE_READY=1; else MOVFILE_READY=0; fi
	
	
	if [ $BIGWAV_READY -eq 0 ] || [ $TRSDATA_READY -eq 0 ] || [ $TGFILE_READY -eq 0  ]; then
		echo `date -u`: "Files not found; BIGWAV_READY=$BIGWAV_READY TRSDATA_READY=$TRSDATA_READY TGFILE_READY=$TGFILE_READY" >> "$PROJECT_INFO"
		continue
	fi
	
	if [ $MOVFILE_READY -eq 0 ]; then
		echo `date -u`: "Movie file not found, smiles/movement amplitude will not be recorded" >> "$PROJECT_INFO"
	else
		# start the smiles detection in the background, if necessary
		# we will wait for the results when the rest of the measurements finish for this file
		echo -e "time\tmovement_amplitude\tsmile" > "$SMILES_MOVAMP_PATH"
		if [ $MOVFILE_READY -ne 0 ] && [ ! -f $SMILES_DONE_PATH ]; then
			echo `date -u`: "Starting movement amplitude, smiling measurements" >> "$PROJECT_INFO"
			python "${SCRIPT_DIR}/smiles_movamp/get_smiles.py" "$MOVFILE" >> "$SMILES_MOVAMP_PATH" &
			SMILES_PROCESS_ID=$!
		fi
	fi
	
	# this is the WORKING folder for TGs, not the original location (which is in TGFILE already)
	# copy TG to working directory
	STRIPPEDTG="${TGWORKING}/${FILE_ID}.TextGrid"
	cp "$TGFILE" "$STRIPPEDTG"
	# add utterance info to TG, this may throw a warning "Overwriting input TextGrid" which is nothing to worry about
	/Applications/Praat.app/Contents/MacOS/Praat ${SCRIPT_DIR}/add_utterances_to_tg.praat "$TRSDATA" "$STRIPPEDTG" 1 0 >> "$PROJECT_INFO" 2>&1

	if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi

	if [ ! -f $MEASUREMENTS_SMILES_PATH ]; then
		if [ ! -f $MEASUREMENTS_RESHAPED_PATH ]; then
			if [ ! -f $MEASUREMENTS_DECORATED_PATH ]; then
				if [ ! -f $MEASUREMENTS_WIDE_PATH ]; then
					if [ ! -f $MEASUREMENTS_PATH ]; then
						# split again, now for analysis (phone-sized)
						echo `date -u`: "Chopping up utterances for analysis..." >> "$PROJECT_INFO"
						# clear working directory
						find ${WAVWORKING} -type f -delete
						if [ $? -ne 0 ]; then echo "Find/delete failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
						/Applications/Praat.app/Contents/MacOS/Praat "${SCRIPT_DIR}/save_labeled_intervals_to_wav_sound_files.praat" "$BIGWAV" "$STRIPPEDTG" "$WAVWORKING" 1 0 0 1 1 1 0.025 >> "$PROJECT_INFO" 2>&1
						if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
						# run measurements script
						echo `date -u`: "Starting measurements..." >> "$PROJECT_INFO"
						/Applications/Praat.app/Contents/MacOS/Praat "${SCRIPT_DIR}/PraatVoiceSauceImitator.praat" "${UNIQUE_SPEAKER}" "$WAVWORKING" .wav  "$WAVWORKING" .TextGrid "${RESULTS_DIR}/.working" 1 0.025 0.025 0.010 10 "$GENDER" 500 550 1485 1650 2475 2750 >> "$PROJECT_INFO" 2>&1
						if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; rm ${MEASUREMENTS_PATH}; continue; fi
						echo `date -u`: "Done with measurements..." >> "$PROJECT_INFO"
					else 
						echo `date -u`: "Already found measurements..." >> "$PROJECT_INFO"
					fi
					echo `date -u`: "Converting to wide format..." >> "$PROJECT_INFO"
					Rscript --slave "${SCRIPT_DIR}/long_to_wide.r" "$MEASUREMENTS_PATH" "$MEASUREMENTS_WIDE_PATH" >> "$PROJECT_INFO" 2>&1
					if [ $? -ne 0 ]; then echo "Rscript failed. Line ${LINENO}" >> "$PROJECT_INFO"; rm ${MEASUREMENTS_WIDE_PATH}; continue; fi
				else
					echo `date -u`: "Already found wide measurements..." >> "$PROJECT_INFO"
				fi
				echo `date -u`: "Adding extra information from text grid..." >> "$PROJECT_INFO"
				/Applications/Praat.app/Contents/MacOS/Praat "${SCRIPT_DIR}/decoratedata.praat" "${MEASUREMENTS_WIDE_PATH}" "${STRIPPEDTG}" "${SURVEY_PATH}" "${userinforecord_id}" "${MEASUREMENTS_DECORATED_PATH}" >> "$PROJECT_INFO" 2>&1
				if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; rm ${MEASUREMENTS_DECORATED_PATH}; continue; fi
			else
				echo `date -u`: "Already found decorated measurements..." >> "$PROJECT_INFO"
			fi
		else
			echo `date -u`: "Already found reshaped measurements..." >> "$PROJECT_INFO"
		fi
		
		# add smiles/movement amplitude (assuming they've been measured; if not, NAs will be added)
		echo `date -u`: "Waiting for smiles/movement amplitude to wrap up..." >> "$PROJECT_INFO"
		wait
		touch "$SMILES_DONE_PATH"
		echo `date -u`: "Adding smiles/movement amplitude to table..." >> "$PROJECT_INFO"
		Rscript --slave "${SCRIPT_DIR}/add_smiles_movamp.r" "$MEASUREMENTS_DECORATED_PATH" "$SMILES_MOVAMP_PATH" "$MEASUREMENTS_SMILES_PATH"
		if [ $? -ne 0 ]; then echo "Rscript failed. Line ${LINENO}" >> "$PROJECT_INFO"; rm ${MEASUREMENTS_SMILES_PATH}; continue; fi
	else
		echo `date -u`: "Already found measurements with smiles..." >> "$PROJECT_INFO"		
	fi
	
	# clean-up, etc
	cp "$MEASUREMENTS_SMILES_PATH" "$MEASUREMENTS_FINAL_PATH" >> "$PROJECT_INFO" 2>&1
	
	find ${WAVWORKING} -type f -delete >> "$PROJECT_INFO" 2>&1
	echo `date -u`: "Done with $UNIQUE_SPEAKER." >> "$PROJECT_INFO"
done

echo `date -u`: "Goodbye..." >> "$PROJECT_INFO"

