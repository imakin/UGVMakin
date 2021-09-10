import subprocess
from sys import argv
l = str(
    subprocess.run(['adb','shell', 'ls', '/sdcard/makin/ugvtraining/'], stdout=subprocess.PIPE).stdout,
    "utf8"
  )
print(l)
for f in l.split('\n'):
  if f.endswith('png') or f.endswith('jpg'):
    if (f.find('FRAME')==(-1)):
      print(f'pulling {f}')
      subprocess.run(['adb', 'pull', '/sdcard/makin/ugvtraining/'+f, argv[1]], stdout=subprocess.PIPE)

print('delete on phone? y/n')
d = input()
if d.startswith('y'):
    for f in l.split('\n'):
      if f.endswith('png') or f.endswith('jpg'):
        if (f.find('FRAME')==(-1)):
          print(f'deleting {f}')
          subprocess.run(['adb', 'shell', 'rm', '/sdcard/makin/ugvtraining/'+f], stdout=subprocess.PIPE)
