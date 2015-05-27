This is the measurement pipeline for the Living Room. Given inputs of video files, 
audio files, and annotations in various formats, it can perform acoustic measurements
of pitch, formants, and voice quality for data from the Living Room.

scripts/pipeline_main.py contains the main functionality.

If you change the Qualtrics-based exit survey or session info survey:
scripts/utilities/qualtricsheadings.txt and
scripts/utilities/sessioninfoheadings.txt
have plain-English, R-compatible headings for the output of Qualtrics export. The 
pipeline uses these comma-delimited, one-line files to set the headings of the metadata.
Don't change any of the names that are already set in these files, especially not:
- ResponseID [both]
- SessionID [both]
- ParticipantID [qualtricsheadings]
- ParticipantOneID [sessioninfoheadings]
- ParticipantOneFirstName [sessioninfoheadings]
- ParticipantOneLastName [sessioninfoheadings]
- ParticipantTwoID [sessioninfoheadings]
- ParticipantTwoFirstName [sessioninfoheadings]
- ParticipantTwoLastName [sessioninfoheadings]

The names appear in the order in which Qualtrics currently exports them. If you change 
the surveys at all, you may have to change the order of the headings appropriately, or 
add/remove them. 

**By default, pipeline_main.py will look for qualtricsheadings.txt and sessioninfoheadings.txt**
**in the pipeline_working/metadata folder on Big Brother, so if you change these files, copy**
**them to this location!**

Depends: python 2.7.x, pandas 0.16.1, numpy 1.9.1+, scipy.signal. A compatible praat 
should be on the path. Creak detection uses the Matlab-based covarep 
repository and the wrappers written by Patrick Callier available at 
https://github.com/pcallier/creak_batch (runs separately). 