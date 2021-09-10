"""
Usage:
  # From tensorflow/models/
  # Create train data:
  python generate_tfrecord.py --csv_input=data/train_labels.csv  --output_path=train.record

  # Create test data:
  python generate_tfrecord.py --csv_input=data/test_labels.csv  --output_path=test.record
"""
from __future__ import division
from __future__ import print_function
from __future__ import absolute_import

import os
import io
import pandas as pd
import tensorflow as tf
from sys import argv

from PIL import Image
# ~ from object_detection.utils import dataset_util
from collections import namedtuple, OrderedDict

# ~ flags = tf.app.flags
# ~ flags.DEFINE_string('csv_input', '', 'Path to the CSV input')
# ~ flags.DEFINE_string('output_path', '', 'Path to output TFRecord')
# ~ flags.DEFINE_string('image_dir', '', 'Path to images')
# ~ FLAGS = flags.FLAGS
class Const(object):
    def __init__(self):
        self.arg_count = 1
        
    def add(self, key, what):
        try:
            setattr(self, key, argv[self.arg_count])
        except IndexError:
            print(f'run the app with argument {what} at position {self.arg_count}')
            exit(1)
        self.arg_count += 1
    
FLAGS = Const()
FLAGS.add('csv_input', 'csv_input_PATH')
FLAGS.add('image_dir', 'path_to_image_input')
FLAGS.add('output_path', 'TFRecord_output_PATH')

class dataset_util(object):
    @staticmethod    
    def int64_feature(values):
      """Returns a TF-Feature of int64s.
      Args:
        values: A scalar or list of values.
      Returns:
        A TF-Feature.
      """
      if not isinstance(values, (tuple, list)):
        values = [values]
      return tf.train.Feature(int64_list=tf.train.Int64List(value=values))

    @staticmethod
    def bytes_list_feature(values):
      """Returns a TF-Feature of list of bytes.
      Args:
        values: A string or list of strings.
      Returns:
        A TF-Feature.
      """
      return tf.train.Feature(bytes_list=tf.train.BytesList(value=values))

    @staticmethod
    def float_list_feature(values):
      """Returns a TF-Feature of list of floats.
      Args:
        values: A float or list of floats.
      Returns:
        A TF-Feature.
      """
      return tf.train.Feature(float_list=tf.train.FloatList(value=values))

    @staticmethod
    def bytes_feature(values):
      """Returns a TF-Feature of bytes.
      Args:
        values: A string.
      Returns:
        A TF-Feature.
      """
      return tf.train.Feature(bytes_list=tf.train.BytesList(value=[values]))

    @staticmethod
    def float_feature(values):
      """Returns a TF-Feature of floats.
      Args:
        values: A scalar of list of values.
      Returns:
        A TF-Feature.
      """
      if not isinstance(values, (tuple, list)):
        values = [values]
      return tf.train.Feature(float_list=tf.train.FloatList(value=values))


# TO-DO replace this with label map
label_map = ['tree', 'road', 'wall']
def class_text_to_int(row_label):
    try:
        return label_map.index(row_label) + 1
    except ValueError as e:
        return None


def split(df, group):
    data = namedtuple('data', ['filename', 'object'])
    gb = df.groupby(group)
    return [data(filename, gb.get_group(x)) for filename, x in zip(gb.groups.keys(), gb.groups)]


def create_tf_example(group, path):
    with tf.io.gfile(os.path.join(path, '{}'.format(group.filename)), 'rb') as fid:
        encoded_jpg = fid.read()
    encoded_jpg_io = io.BytesIO(encoded_jpg)
    image = Image.open(encoded_jpg_io)
    width, height = image.size

    filename = group.filename.encode('utf8')
    image_format = b'jpg'
    xmins = []
    xmaxs = []
    ymins = []
    ymaxs = []
    classes_text = []
    classes = []

    for index, row in group.object.iterrows():
        xmins.append(row['xmin'] / width)
        xmaxs.append(row['xmax'] / width)
        ymins.append(row['ymin'] / height)
        ymaxs.append(row['ymax'] / height)
        classes_text.append(row['class'].encode('utf8'))
        classes.append(class_text_to_int(row['class']))

    tf_example = tf.train.Example(features=tf.train.Features(feature={
        'image/height': dataset_util.int64_feature(height),
        'image/width': dataset_util.int64_feature(width),
        'image/filename': dataset_util.bytes_feature(filename),
        'image/source_id': dataset_util.bytes_feature(filename),
        'image/encoded': dataset_util.bytes_feature(encoded_jpg),
        'image/format': dataset_util.bytes_feature(image_format),
        'image/object/bbox/xmin': dataset_util.float_list_feature(xmins),
        'image/object/bbox/xmax': dataset_util.float_list_feature(xmaxs),
        'image/object/bbox/ymin': dataset_util.float_list_feature(ymins),
        'image/object/bbox/ymax': dataset_util.float_list_feature(ymaxs),
        'image/object/class/text': dataset_util.bytes_list_feature(classes_text),
        'image/object/class/label': dataset_util.int64_list_feature(classes),
    }))
    return tf_example


def main():
    writer = tf.io.TFRecordWriter(FLAGS.output_path)
    path = os.path.join(FLAGS.image_dir)
    examples = pd.read_csv(FLAGS.csv_input)
    grouped = split(examples, 'filename')
    for group in grouped:
        tf_example = create_tf_example(group, path)
        writer.write(tf_example.SerializeToString())

    writer.close()
    output_path = os.path.join(os.getcwd(), FLAGS.output_path)
    print('Successfully created the TFRecords: {}'.format(output_path))


if __name__ == '__main__':
    main()
