# get_text_transcript_voices.sh
# 
# Fills working directory full of tab-delim'd text transcripts
# from VoC, given a tab-delim'd metadata table with speaker codes in 
# the first column

METADATA_PATH=$(cd $(dirname $1); pwd)/$(basename $1)
SCRIPT_DIR=$(dirname ${0})
sed 1d $METADATA_PATH | while IFS=$'\t' read SPEAKER_ID INTERACTION_ID SURVEY_ID DATE FAMILIARITY ANGLE SPEAKER_FIRST SPEAKER_LAST GENDER WAV_PATH TG_PATH TRS_DATA_PATH; do
	python ${SCRIPT_DIR}/make_tsv_transcript.py $SPEAKER_ID > ${SPEAKER_ID}.txt
done