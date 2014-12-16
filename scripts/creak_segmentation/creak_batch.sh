#!/bin/bash
#
# creak_batch.sh
#   Patrick Callier
#
# looks in DATA_DIR for folders with a file called .ready
# runs do_creak_detection on such folders
# when done, deletes WAVs from such folders to free up space
# and touches .done to signal that the data can be collected by the client

DATA_DIR="${HOME}/private/creak_wavs/wav_working"
SCRIPT_DIR=`cd $(dirname "${0}"); pwd`
errorlog="${SCRIPT_DIR}/errors.log"

# loop over folders in data directory
for folder in "$DATA_DIR"/*/ ; do
    if [ ! -z "$folder" ]; then
    	echo "Folder ${folder} not blank"
    	if [ -f "${folder}/.ready" ]; then
    		echo "Folder ready."
    		touch -t "`date -d '10 hours ago' +%Y%m%d%H%M`" "${folder}/.THEN"
			if [[ ! -f "${folder}/.inprogress"  || ( -f "${folder}/.inprogress" && "${folder}/.inprogress" -ot "${folder}/.THEN" ) ]]; then
				echo "Folder not being processed"
				touch "${folder}/.inprogress"
				module load matlab
				matlab -r "cd ${SCRIPT_DIR}/covarep; startup; cd ${SCRIPT_DIR}; do_creak_detection('${folder}'); exit" >> "$errorlog"
				if [ "$?" -ne 0 ]; then
				    rm -f "${folder}/.THEN"
					echo "Matlab had bad exit in ${folder}" >> "$errorlog"
					continue
				fi
				rm "${folder}/.inprogress"
				# delete wav files
				find "${folder}" -type f -name "*.wav" -exec rm -rf {} \;
				touch "${folder}/.done"
				rm "${folder}/.ready"
			fi
			rm -f "${folder}/.THEN"
		fi
	fi
done