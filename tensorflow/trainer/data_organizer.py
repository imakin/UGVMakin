#!/usr/bin/env python

try:
    import Tkinter as tk
except:
    import tkinter as tk

import subprocess
from functools import partial
from PIL import ImageTk, Image
from sys import argv
import os
import shutil

print('data_organizer.py training_dir output_dir')

categories = ['forward', 'left', 'right', 'stop']


class DATA(object):
    DIR = argv[1]
    OUTPUT_DIR = argv[2]
    DIR_ROAD = os.path.join(argv[2], 'road')
    DIR_OBSTACLE = os.path.join(argv[2], 'obstacle')

subprocess.run(['mkdir','-p', DATA.OUTPUT_DIR])
for cat in categories:
    subprocess.run(['mkdir','-p',os.path.join(DATA.OUTPUT_DIR, cat)])

def pad(n,length=3):
    return ('0'*length+str(n))[-3:]

existing_files = 0
for cat in categories:
    existing_files += len(os.listdir(os.path.join(DATA.OUTPUT_DIR, cat)))

files = [os.path.join(DATA.DIR, f) for f in os.listdir(DATA.DIR) if f.endswith('png') or f.endswith('jpg')]
file_i = existing_files
app = tk.Tk()

img = ImageTk.PhotoImage(Image.open(files[file_i]))
root_frame = tk.Listbox(app)
root_frame.pack(side='top', fill=tk.BOTH)
panel = tk.Label(root_frame, image = img)
panel.pack(side = "bottom", fill = "both", expand = "yes")

def next_file():
    global file_i
    file_i += 1
    img2 = ImageTk.PhotoImage(Image.open(files[file_i]))
    panel.configure(image=img2)
    panel.image = img2#hold from garbagec

def set_road():
    global file_i
    shutil.copy(files[file_i], os.path.join(DATA.DIR_ROAD, f'ripe_{pad(file_i)}.jpg'))
    next_file()
    
def set_obstacle():
    global file_i
    shutil.copy(files[file_i], os.path.join(DATA.DIR_OBSTACLE, f'ripe_{pad(file_i)}.jpg'))
    next_file()

# ~ bt_road = tk.Button(root_frame, text='Road', command=set_road)
# ~ bt_road.pack(side='bottom')
# ~ bt_obstacle = tk.Button(root_frame, text='Obstacle', command=set_obstacle)
# ~ bt_obstacle.pack(side='bottom')

def set_cat(category_name=None):
    global file_i
    shutil.copy(
        files[file_i],
        os.path.join(DATA.OUTPUT_DIR, category_name, f'ripe_{pad(file_i)}.jpg')
    )
    next_file()
categories_callback = {}
categories_button = {}
for cat in categories:

    bt_ = tk.Button(root_frame, text=cat, command=partial(set_cat,category_name=cat))
    bt_.pack(side='bottom')
    categories_button[cat] = bt_

app.mainloop()


