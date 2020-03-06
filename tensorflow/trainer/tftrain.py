#import matplotlib.pyplot as plt
from matplotlib import pyplot as plt
import tensorflow as tf
import tensorflow_hub as hub
import numpy as np
import pandas as pd
import os
from sys import argv

print("use: trfrain.py training_folder_path output_model_prefixname")
argv[1]
RESULT_PREFIXNAME = argv[2]
pd.set_option("display.precision", 8)

IMAGE_SHAPE = (128,128)
TRAINING_DATA_DIR = argv[1]

BATCH_SIZE = 8
EPOCH = 40
TOTAL_DATA_FOR_TRAINING = 85 #percentage of data used for training, the rest is for validation
validation_split_ = (100-TOTAL_DATA_FOR_TRAINING)/100

valid_datagen = tf.keras.preprocessing.image.ImageDataGenerator(
    rescale=1/255,
    validation_split=validation_split_
)
valid_generator = valid_datagen.flow_from_directory(
    TRAINING_DATA_DIR,
    subset='validation',
    shuffle=False,
    batch_size=BATCH_SIZE,
    target_size=IMAGE_SHAPE
)
train_datagen = tf.keras.preprocessing.image.ImageDataGenerator(
    rescale=1/255,
    validation_split=validation_split_
)
train_generator = train_datagen.flow_from_directory(
    TRAINING_DATA_DIR,
    subset='training',
    shuffle=False,
    batch_size=BATCH_SIZE,
    target_size=IMAGE_SHAPE
)
image_batch_train, label_batch_train = next(iter(train_generator))
print(f'Image batch shape: {image_batch_train.shape}')
# ~ print(f'so BATCH_SIZE is 4x{image_batch_train.shape[0]/4}')
print(f'label batch shape: {label_batch_train.shape}')
dataset_labels = sorted(train_generator.class_indices.items(), key=lambda pair:pair[1])
dataset_labels = np.array([key.title() for key,v in dataset_labels])
print(f'dataset_labels: \n\t{dataset_labels}\n satunya: {np.array(os.listdir(TRAINING_DATA_DIR))}')
print(f'train_generator.samples: {train_generator.samples}')

# ~ class MyLayer(tf.keras.layers.Layer):

    # ~ def __init__(self, output_dim, **kwargs):
        # ~ self.output_dim = output_dim
        # ~ super(MyLayer, self).__init__(**kwargs)

    # ~ def build(self, input_shape):
        # ~ # Create a trainable weight variable for this layer.
        # ~ self.kernel = self.add_weight(name='kernel', 
                                      # ~ shape=(input_shape[1], self.output_dim),
                                      # ~ initializer='uniform',
                                      # ~ trainable=True)
        # ~ super(MyLayer, self).build(input_shape)  # Be sure to call this at the end

    # ~ def call(self, x):
        # ~ return tf.keras.backend.dot(x, self.kernel)

    # ~ def compute_output_shape(self, input_shape):
        # ~ return (input_shape[0], self.output_dim)
# ~ layerku = MyLayer(1280)
# ~ layerku.build(IMAGE_SHAPE)
model = tf.keras.Sequential([
    hub.KerasLayer(
        # ~ "https://tfhub.dev/google/tf2-preview/mobilenet_v2/feature_vector/4",
        "https://tfhub.dev/google/imagenet/mobilenet_v2_075_128/feature_vector/4",
        output_shape=[1280],#feature vector  size
        trainable=False
    ),
    tf.keras.layers.Dropout(0.4),
    tf.keras.layers.Dense(train_generator.num_classes,activation='softmax')
])
model.build([None,IMAGE_SHAPE[0],IMAGE_SHAPE[1],3])
model.summary()
model.compile(
    optimizer=tf.keras.optimizers.Adam(),
    loss='categorical_crossentropy',
    metrics=['acc']
)

steps_per_epoch = np.ceil(train_generator.samples / train_generator.batch_size)
val_steps_per_epoch = np.ceil(valid_generator.samples / valid_generator.batch_size)

hist = model.fit(
    train_generator,
    epochs=EPOCH,
    verbose=1,
    steps_per_epoch=steps_per_epoch,
    validation_data = valid_generator,
    validation_steps=val_steps_per_epoch
).history

model_file = 'jalan'
tf.saved_model.save(model, './')

#tf.keras.experimental.export_saved_model(model, model_file)

#saved_model = tf.keras.experimental.load_from_saved_model(
#    model_file,
#    custom_objects={'KerasLayer':hub.KerasLayer}
#)



print('validator')
val_image_batch, val_label_batch = next(iter(valid_generator))
true_label_ids = np.argmax(val_label_batch, axis=-1)
print("Validation batch shape:", val_image_batch.shape)

tf_model_predictions = model.predict(val_image_batch)
tf_pred_dataframe = pd.DataFrame(tf_model_predictions)
tf_pred_dataframe.columns = dataset_labels
print("Prediction results for the first elements")
tf_pred_dataframe.head()
predicted_ids = np.argmax(tf_model_predictions, axis=-1)
predicted_labels = dataset_labels[predicted_ids]

#print(val_image_batch, val_label_batch)
#print(predicted_ids)
#print(predicted_labels)


plt.figure(figsize=(10,9))
plt.subplots_adjust(hspace=0.5)
for n in range(val_image_batch.shape[0]): #max is using validation batch size
    #print(val_image_batch[n], predicted_labels[n].title())
    plt.subplot(6,5,n+1)
    plt.imshow(val_image_batch[n])
    color = "green" if predicted_ids[n] == true_label_ids[n] else "red"
    plt.title(predicted_labels[n].title(), color=color)
    plt.axis('off')
    _ = plt.suptitle("Model predictions (green: correct, red: incorrect)")
plt.show()

TFLITE_MODEL = f'assets/{RESULT_PREFIXNAME}.tflite'
TFLITE_QUANT_MODEL = f'assets/{RESULT_PREFIXNAME}_optimized.tflite'
TFLITE_LABELS = f'assets/{RESULT_PREFIXNAME}_labels.txt'
#get concrete function from keras model
run_model = tf.function(lambda x: model(x))
concrete_func = run_model.get_concrete_function(
    tf.TensorSpec(model.inputs[0].shape, model.inputs[0].dtype)
)

#convert model, save as tflite
converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete_func])
converted_tflite_model = converter.convert()
with open(TFLITE_MODEL, 'wb') as f:
    f.write(converted_tflite_model)

#optimize 
converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete_func])
# ~ converter.optimizations = [tf.lite.Optimize.OPTIMIZE_FOR_SIZE]
converter.optimizations = [tf.lite.Optimize.DEFAULT]
tflite_quant_model = converter.convert()
with open(TFLITE_QUANT_MODEL, 'wb') as f:
    f.write(tflite_quant_model)

with open(TFLITE_LABELS, 'w') as f:
    for label in dataset_labels:
        f.write(label+'\n')
