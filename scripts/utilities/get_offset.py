#!/usr/env/bin python
"""get_offset.py
Patrick Callier

Provides get_offset_wav, which gets offset in secs between two audio files
"""

import numpy as np
#import scipy as sp
import scipy.io.wavfile as sp_wav

def get_offset_xcorr(wav1, wav2):
    """Returns offset in samples between two 1d numpy arrays
    using the peak of their cross-correlation
    Much credit to http://stackoverflow.com/questions/4688715/find-time-shift-between-two-similar-waveforms
    and eryksun's answer: http://stackoverflow.com/a/4696026/1233304"""
    
    n_samples = 2 ** int(np.ceil(np.log2(wav1.size + wav2.size - 1)))
    spec1 = np.fft.rfft(wav1, n_samples)
    spec2 = np.fft.rfft(wav2, n_samples)
    
    spec_prod = spec1 * np.conj(spec2)
    xcorr = np.fft.irfft(spec_prod)
    xcorr = np.hstack((xcorr[:wav1.size], xcorr[n_samples - wav2.size + 1:]))
    return np.argmax(xcorr)

def get_offset_wav(wav_filename1, wav_filename2, time_limit=120):
    """Return offset in seconds between wav_filename1 and
    wav_filename2, which are recordings of the same event
    with potentially different starting times. Returns the 
    number of seconds that wav_filename2 starts after wav_filename1
    (possibly negative).
     
    
    If time_limit is provided, clip files
    to first time_limit seconds. This can substantially speed up 
    offset detection"""
    
    rate1, data1 = sp_wav.read(wav_filename1)
    rate2, data2 = sp_wav.read(wav_filename2)
    # the two files must have the same sampling rate
    assert(rate1==rate2)
    
    if time_limit is not None:
        data1 = data1[0:rate1 * time_limit]
        data2 = data1[0:rate2 * time_limit]
                
    offset_samples = get_offset_xcorr(data1, data2)
    offset_seconds = offset_samples / float(rate)
    
    return offset_seconds