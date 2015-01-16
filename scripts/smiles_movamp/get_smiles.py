# hello and welcome to this poorly documented script 
# what it tries to do is calculate movement amplitude and smiling/notsmiling for every frame
# and prints to stdout the following:
# [time] \t [MA] \t [smiling?]
#
# usage: python get_smiles.py [video_file]
# 

import cv2, os, random, sys, math
import numpy as np

# input file
script_dir = sys.path[0]
test_file = sys.argv[1]

# cascade classifier locations
face_file = 'haarcascade_frontalface_alt.xml'
smile_file = 'smiled_01.xml'

face_cascade = cv2.CascadeClassifier(os.path.join(script_dir, face_file))
smile_cascade = cv2.CascadeClassifier(os.path.join(script_dir, smile_file))

cap = cv2.VideoCapture(test_file)
fps = float(cap.get(5))

if not cap.isOpened():
    print 'error opening video file'
    exit(0) 

frame_num = -1
prior_frame = ''
times, mas, smilevals = [], [], []

while True:
    frame_num += 1
    ret, frame = cap.read()
    #if frame_num < 5000: continue
    #if frame_num == 5100: break
    try:
        frame_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    except:
        break
    
    time = frame_num / fps
    
    faces = face_cascade.detectMultiScale(frame_gray, 1.3, 5)
    
    smiling = False
    for (x,y,w,h) in faces:
        cv2.rectangle(frame, (x,y), (x+w, y+h), (255,0,0), 2)
        eye_roi_gray = frame_gray[y:y+(h/2), x:x+w]
        smile_roi_gray = frame_gray[y+(h/2):y+h, x:x+w]
        roi_color = frame[y:y+h, x:x+w]
        smiles = smile_cascade.detectMultiScale(smile_roi_gray)
        for (ex, ey, ew, eh) in smiles[0:1]:
            smiling = True
            cv2.rectangle(roi_color, (ex,ey+(h/2)), (ex+ew, ey+eh+(h/2)), (0,255,0), 2)

            
    if prior_frame != '':
        diff = frame_gray - prior_frame
        MA = np.log(np.sum(np.absolute(diff)))
        if math.isnan(MA):
            print >> sys.stderr, 'Error on frame %i' %frame_num
            raise Exception('FUCK THE WORLD IS PAIN')
        mas.append(MA)
        times.append(time)
        smilevals.append(smiling)
    prior_frame = frame_gray
    if cv2.waitKey(1) & 0xFF == ord('q'): break

cap.release()

ma_mean = np.mean(mas)
ma_std = np.std(mas)
zscore_mas = [(x - ma_mean)/ma_std for x in mas]

for t, m, s in zip(times, zscore_mas, smilevals):
    print t, '\t', m, '\t', s

cv2.destroyAllWindows()
