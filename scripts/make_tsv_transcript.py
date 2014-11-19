# make_tsv_transcript.py
#
# Takes a VoC-style name as input, finds the text transcript
# for it, and spits out a tab-delimited version of it to stdout
# with only speech from the interviewee proper
#

import sys
import os
import argparse
import re

text_paths = { "RED": "/Volumes/Surfer/corpora/VoCal/text_corpus/RED",
				"BAK": "/Volumes/Surfer/corpora/VoCal/text_corpus/BAK",
				"MER": "/Volumes/Surfer/corpora/VoCal/text_corpus/MER" }
				
text_name_decorator = "_proc.txt"

parser = argparse.ArgumentParser(description="Takes a VoC-style name as input, finds the text transcript for it, and spits out a tab-delimited version of it to stdout")
parser.add_argument("speaker_name", metavar="SPEAKER_NAME", type=str)

arg= parser.parse_args()

location_key = arg.speaker_name[0:3]
text_path = os.path.join(text_paths[location_key], arg.speaker_name + text_name_decorator)
speaker_name = re.sub(r"((MER|RED|BAK|SAC)I?_)(([^_]+)_([^_]+)).*$", r"\3", arg.speaker_name)
print >> sys.stderr, speaker_name

try:
	with open(text_path, "r") as text_file:
		print "start_ip\tend_ip\tspeaker\ttext"
		for text_line in text_file:
			stripped_line = re.sub(r"(\<.*?\>)+", r"\t", re.sub(r"^\<.*?\>(.*)\<.*?\>$", r"\1", text_line.strip()))
			if stripped_line.split('\t')[2] == speaker_name:
				print stripped_line
except IOError as e:
	print >> sys.stderr, "File %s not found" % text_path




