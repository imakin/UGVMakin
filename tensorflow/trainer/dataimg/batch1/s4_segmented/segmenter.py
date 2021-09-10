import cv2
import os
from sys import argv

print('python segmenter.py batch_dir_path')
print('input files are 672x672, segmented into 9 images, each 224x224')

def pad(n,length=3):
    return ('0'*length+str(n))[-3:]

class DATA(object):
    DIR = argv[1]
    SIZE = 224 #target image size
    SEGMENTS = 9
    COLUMN = int(SEGMENTS**0.5)
    SIZE_INPUT = int(SIZE * COLUMN)

files = [os.path.join(DATA.DIR, f) for f in os.listdir(DATA.DIR)]
print(files)

i = 0
for file in files:
    im = cv2.imread(file)
    if (im is None):
        continue
    print(f'segmenting {file}')
    for y in range(0,DATA.COLUMN):
        for x in range(0,DATA.COLUMN):
            x0 = x*DATA.SIZE
            y0 = y*DATA.SIZE
            x1 = (x+1)*DATA.SIZE
            y1 = (y+1)*DATA.SIZE
            print(f'crop coords: ({x0},{y0}), ({x1},{y1})')
            i += 1
            cropped = im[y0:y1, x0:x1]
            print('saving to '+os.path.join(DATA.DIR, f'ripe_{pad(i)}.jpg'))
            cv2.imwrite(os.path.join(DATA.DIR, f'ripe_{pad(i)}.jpg'), cropped)
