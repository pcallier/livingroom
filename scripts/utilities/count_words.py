#!/usr/bin/env python
# count_words.py
# input: a file with words to count, on std in
# output: a headerless TSV table with word in the first column and count in the
# second column, printed to stdout

import fileinput
from collections import Counter

words = []
for line in fileinput.input():
   words.extend(line.split())

word_counts = '\n'.join([ "%s\t%s" % (word, count) for word, count in Counter(words).iteritems() ])
print word_counts
