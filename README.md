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

