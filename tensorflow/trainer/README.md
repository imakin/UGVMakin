puller.py:
   pull image trainig files captured from android phone, some paths are hardcoded

segmenter.py:
   segments images. segmentation done in android instead. capture image as the car running

data_organizer.py
   collect train images, and let us decide which images should be trained as  obstacle and road

tftrain.py
   the model creating. tensorflow keras layer is using layer from tfhub url (hardcoded)
