#!/bin/bash
#
# do_creak_voices.sh
# Patrick Callier
#
# Cues data up to AFS, runs creak detection, downloads results,
# wash rinse repeat. 
#
# Authenticate to remote (script does not see your password)
# put chopped-up audio data onto remote
# this requires ssh authentication to a Stanford account (taken care of above), 
# and for the AFS file system to be mounted (this you must do yourself with AFS Controller)
#
# Arguments: do_creak_voices.sh results_path remote_path metadata_path textgrid_path
#   results_path: path to the folder where result TextGrids will be found. speakers who
#        have results in this folder will not be run.
#   remote_path: path to your "remote" working directory on AFS. If not absolute,
#       this must be relative to your local machine, i.e. not relative to your AFS home
#   metadata_path: path to the metadata for the corpus, formatted as for voices_batch.sh (which see)
#   textgrid_path: path to the folder of interviewee-only textgrids such as those produced 
#       by vocal_strip_interviewer.praat (local), with utterance timing added
#       as by add_utterances_to_tg.praat (on tier 3); you can either run
#       these scripts yourself or use the saved ones left over after voices_batch.sh runs;
#       see voices_batch.sh ($TGWORKING, $STRIPPEDTG) for more information
#
#   When you've run this, you'll need to set up [remote_path]/creak_segmentation/creak_batch.sh as a cron job 
#   on AFS. This can be done through the scheduler at 
#   https://tools.stanford.edu/cgi-bin/scheduler

# process arguments
if [ -d "$1" ]; then
    RESULTS_PATH=$(cd "$1"; pwd)
else
    echo "Results directory not found."
    exit 0
fi
  
if [ -f "$3" ]; then
    METADATA_PATH=$(cd $(dirname "$3"); pwd)/$(basename "$3")
else
    echo "Metadata not found."
    exit 0
fi

if [ -d "$4" ]; then
    TEXTGRID_PATH=$(cd "$4"; pwd)
else
    echo "Textgrid directory not found."
    exit 0
fi

SCRIPT_DIR=$(dirname "${0}")
PROJECT_INFO="${SCRIPT_DIR}/creak_errors.log"

# check for access to afs
echo -n "SUNet ID: "
read AFSNAME
kinit $AFSNAME
aklog
AFS_HOME=$(cd "/afs/.ir/users/${AFSNAME:0:1}/${AFSNAME:1:1}/${AFSNAME}"; pwd)
if [ ! -d $AFS_HOME ]; then
    echo "Can't access AFS home folder $AFS_HOME. Is it mounted?"
    exit 0
fi

# process arguments
if [ -d "$2" ]; then
    REMOTE_PATH=$(cd "$2"; pwd)
    A=${#REMOTE_PATH}
    B=${#AFS_HOME}
    C=$(expr $A - $B)
else
    echo "Remote directory not found." >> "$PROJECT_INFO"
    exit 0
fi

# these are folders that will go in remote if they don't exist
# the wav_working folder will be emptied out
WAV_WORKING="wav_working"
CREAK_SCRIPTS="creak_segmentation"

if [ ! -d "${REMOTE_PATH}/${WAV_WORKING}" ]; then
    mkdir "${REMOTE_PATH}/${WAV_WORKING}"
    if [ $? -ne 0 ]; then echo "Unable to create working directory" >> "$PROJECT_INFO"; exit 0; fi
fi

# if the creak scripts dir exists, assume it has the correct stuff in it
if [ ! -d "${REMOTE_PATH}/${CREAK_SCRIPTS}" ]; then
    cp -R "${SCRIPT_DIR}/creak_segmentation/" "${REMOTE_PATH}/${CREAK_SCRIPTS}"
    if [ $? -ne 0 ]; then echo "Unable to copy scripts to remote" >> "$PROJECT_INFO"; exit 0; fi
fi

QUOTA=$(ssh $AFSNAME@corn.stanford.edu "check-stanford-afs-quota | grep -e 'MB.*MB' | sed -E 's/.* ([^\s]*) MB\s([^\s]*) MB.*/\2/'")
echo "AFS Quota: ${QUOTA} MB used"

sed 1d $METADATA_PATH | while IFS=$'\t' read SPEAKER GENDER LOCATION AGE RACE SEXUAL_ORIENTATION WAV_PATH TG_PATH TRS_DATA_PATH; do
	echo `date -u`: "Starting to work with $SPEAKER..." >> "$PROJECT_INFO"
	BIGWAV="$WAV_PATH"
	STRIPPEDTG="${TEXTGRID_PATH}/${SPEAKER}.TextGrid"
	
	if [ -f "$BIGWAV" ]; then BIGWAV_READY=1; else BIGWAV_READY=0; fi
	if [ -f "$STRIPPEDTG" ]; then TGFILE_READY=1; else TGFILE_READY=0; fi
	
	if [ "$BIGWAV_READY" -eq 0 ] || [ "$TGFILE_READY" -eq 0  ]; then
		echo `date -u`: "Files not found; BIGWAV_READY=$BIGWAV_READY TGFILE_READY=$TGFILE_READY" >> "$PROJECT_INFO"
		continue
	fi	

	NUM_TIERS=`/Applications/Praat.app/Contents/MacOS/Praat ${SCRIPT_DIR}/utilities/get_num_tiers.praat "$STRIPPEDTG"`
	if [ "$NUM_TIERS" -lt 3 ]; then echo "Not enough tiers in input TextGrid." >> "$PROJECT_INFO"; continue; fi
	
	NUM_UTTERANCES=`/Applications/Praat.app/Contents/MacOS/Praat ${SCRIPT_DIR}/utilities/get_num_intervals.praat "$STRIPPEDTG" 3`
	if [ "$NUM_UTTERANCES" -eq 1 ]; then echo "No utterance data in input TextGrid." >> "$PROJECT_INFO"; continue; fi
	
	if [ -f "${RESULTS_PATH}/${SPEAKER}.TextGrid" ]; then
	    echo "Results exist for $SPEAKER" >> "$PROJECT_INFO"
	    continue
	fi

    if [ ! -d "${REMOTE_PATH}/${WAV_WORKING}/${SPEAKER}" ]; then
        mkdir "${REMOTE_PATH}/${WAV_WORKING}/${SPEAKER}"
        if [ $? -ne 0 ]; then echo "Unable to create wav directory for speaker" >> "$PROJECT_INFO"; continue; fi
    fi
    
    if [ ! -f "${REMOTE_PATH}/${WAV_WORKING}/${SPEAKER}/.done" ]; then
     	if [ ! -f "${REMOTE_PATH}/${WAV_WORKING}/${SPEAKER}/.ready" ]; then
			echo "Speaker ${SPEAKER} is not done, not ready." >> "$PROJECT_INFO"
			# check how much space is left
			if [ "$QUOTA" -lt "4500" ]; then
				echo `date -u`: "Chopping up utterances for creak detection..." >> "$PROJECT_INFO"
				/Applications/Praat.app/Contents/MacOS/Praat ${SCRIPT_DIR}/save_labeled_intervals_to_wav_sound_files.praat "$BIGWAV" "$STRIPPEDTG" "${REMOTE_PATH}/${WAV_WORKING}/${SPEAKER}" 1 0 0 3 0 0 0.025 >> "$PROJECT_INFO" 2>&1
				if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
				touch "${REMOTE_PATH}/${WAV_WORKING}/${SPEAKER}/.ready"
				ADDED_SIZE=`du -I ".*" -kd 0 "${REMOTE_PATH}/${WAV_WORKING}/${SPEAKER}" | awk '{ total += $1 }; END { print total }'` 2>&0
				let QUOTA=ADDED_SIZE/1024+QUOTA
				echo "New disk usage: ${QUOTA}" >> "$PROJECT_INFO"
			else
				echo `date -u`: "Less than 500 MB on remote. Not putting any files on it for now..." >> "$PROJECT_INFO"
			fi
		fi
    else
        # speaker is done, clean up
        echo `date -u`: "Speaker ${SPEAKER} is done." >> "$PROJECT_INFO"
        # decorate big textgrid with creak
        cp "$STRIPPEDTG" "${RESULTS_PATH}/${SPEAKER}.TextGrid"
        /Applications/Praat.app/Contents/MacOS/Praat "${SCRIPT_DIR}/creak_segmentation/add_creak_info_to_tg.praat" "${RESULTS_PATH}/${SPEAKER}.TextGrid" "${REMOTE_PATH}/${WAV_WORKING}/${SPEAKER}/" 4 >> "$PROJECT_INFO" 2>&1
        if [ $? -ne 0 ]; then echo "Praat failed. Line ${LINENO}" >> "$PROJECT_INFO"; continue; fi
        # Clean up
        rm -rf "${REMOTE_PATH}/${WAV_WORKING}/${SPEAKER}"
        if [ $? -ne 0 ]; then echo "Cleanup on aisle ${SPEAKER}" >> "$PROJECT_INFO"; continue; fi
    fi
done
echo "All done. If you don't have your results yet, make sure that creak_batch.sh is running as a cron job on your remote. You can also invoke it yourself."