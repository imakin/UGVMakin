import PIL
from PIL import Image, ImageFilter
from sys import argv
im = Image.open(argv[1])
im.show()
# ~ im = im.resize((640,640), PIL.Image.NEAREST)

# ~ im = im.filter(ImageFilter.GaussianBlur(10))
# ~ pixels = im.load()
# ~ for y in range(im.size[1]):
    # ~ for x in range(im.size[0]):
        # ~ r,g,b = pixels[x,y]
        # ~ #posterize
        # ~ r -= (r%100)
        # ~ g -= (g%100)
        # ~ b -= (b%100)
        # ~ avg = int((r+g+b)/3)
        # ~ if (avg>50):
            # ~ avg = 255
        # ~ else:
            # ~ avg = 0
        # ~ pixels[x,y] = (avg,avg,avg)
# ~ im.show()
posterize_lvl = 70
im = im.crop((0,0,640,440))
im = im.resize((16,11))
pixels = im.load()
for y in range(im.size[1]):
    for x in range(im.size[0]):
        r,g,b = pixels[x,y]
        r -= (r%posterize_lvl)
        g -= (g%posterize_lvl)
        b -= (b%posterize_lvl)
        
        avg = int((r+g+b)/3)
        # ~ if (avg>50):
            # ~ avg = 255
        # ~ else:
            # ~ avg = 0
        pixels[x,y] = (avg,avg,avg)
im.show()
