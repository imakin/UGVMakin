import subprocess
from sys import argv
list = str(
    subprocess.run(['adb','shell', 'ls', '/sdcard/makin/ugvtraining/'], stdout=subprocess.PIPE).
    stdout,
    "utf8"
  )
for file in list.split('\n'):
  if file.endswith('png'):
    print(f'pulling {file}')
    subprocess.run(['adb', 'pull', '/sdcard/makin/ugvtraining/'+file, argv[1]], stdout=subprocess.PIPE)
