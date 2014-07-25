PROJECT_ROOT=./
SPEAKER=RED_Fowler_Ginger
BIGWAV=/Users/BigBrother/Documents/VoCal/Retreat_Sample/RED_Fowler_Ginger.wav
TRSDATA=${PROJECT_ROOT}/more/${SPEAKER}.txt
TGFILE=/Users/BigBrother/Documents/VoCal/Retreat_Sample/RED_Fowler_Ginger.TextGrid
# this is this path from the (Praat) script location to the project root, because Praat sets its working directory to script location
SCRIPT_TO_ROOT=../.. #TODO: this is a problem... relative paths won't work without this but this breaks absolute paths. Do some manipulation intelligently based on whetehr args are rel or absolute
# this is the WORKING folder for TGs, not the original location (which is in TGFILE already)
TGWORKING=/Volumes/Surfer/users/pcallier/tgs/
WAVWORKING=/Volumes/Surfer/users/pcallier/wavs/
WAVWORKINGREMOTE=/afs/.ir/users/p/c/pcallier/private/livingroom-util/wav_working/
# strip Interviewer information from TG
STRIPPEDTG=${TGWORKING}/${SPEAKER}.TextGrid
/Applications/Praat.app/Contents/MacOS/Praat ${PROJECT_ROOT}/livingroom/scripts/vocal_strip_interviewer.praat "${TGFILE}" "$STRIPPEDTG"
# add utterance info to TG
/Applications/Praat.app/Contents/MacOS/Praat ${PROJECT_ROOT}/livingroom/scripts/add_utterances_to_tg.praat "$TRSDATA" "$STRIPPEDTG" 1
# put chopped-up audio data onto remote
# this requires ssh authentication to my Stanford account, and for the AFS file
# system to be mounted. We're working on making this less messy
# Chop up WAV into bits (phrase-sized)
/Applications/Praat.app/Contents/MacOS/Praat ${PROJECT_ROOT}/livingroom/save_labeled_intervals_to_wav_sound_files.praat "$BIGWAV" "$STRIPPEDTG" "$WAVWORKINGREMOTE" 1 0 0 2 0 1 0.025 
# Creak detection
# copy creak-related scripts to remote (sigh)
scp -r ${PROJECT_ROOT}/livingroom/scripts/creak_segmentation pcallier@cardinal.stanford.edu:~/private/livingroom-util/
ssh pcallier@corn.stanford.edu <<ENDSSH
	sleep 5
	matlab -r "cd private/covarep; startup; cd ~/private/livingroom-util/creak_segmentation/; do_creak_detection('../wav_working/'); exit"
ENDSSH
# decorate big textgrid with creak
/Applications/Praat.app/Contents/MacOS/Praat ${PROJECT_ROOT}/livingroom/scripts/creak_segmentation/add_creak_info_to_tg.praat "$STRIPPEDTG" "$WAVWORKINGREMOTE" 4



#/Applications/Praat.app/Contents/MacOS/Praat /Volumes/Surfer/users/pcallier/livingroom/scripts/save_labeled_intervals_to_wav_sound_files.praat /Users/BigBrother/Documents/VoCal/Retreat_Sample/RED_Fowler_Ginger.wav /Volumes/Surfer/users/pcallier/tgs/RED_Fowler_Ginger.TextGrid /afs/.ir/users/p/c/pcallier/private/livingroom-util/wav_working/ 1 0 0 2 0 1 0.025 
