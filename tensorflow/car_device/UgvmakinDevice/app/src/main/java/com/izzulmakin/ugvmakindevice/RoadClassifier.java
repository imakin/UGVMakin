package com.izzulmakin.ugvmakindevice;

import android.annotation.SuppressLint;
import android.content.res.AssetFileDescriptor;
import android.content.res.AssetManager;
import android.graphics.Bitmap;
import android.util.Log;

import org.tensorflow.lite.Interpreter;

import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.nio.MappedByteBuffer;
import java.nio.channels.FileChannel;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.PriorityQueue;

import static android.os.SystemClock.elapsedRealtime;

public class RoadClassifier {
    public static ByteBuffer byteBuffer;

    private static final int MAX_RESULTS = 2;
    private static final int BATCH_SIZE = 1;
    private static final int PIXEL_SIZE = 3;
    private static final float THRESHOLD = 0.1f;

    private static final int IMAGE_MEAN = 128;
    private static final float IMAGE_STD = 128.0f;

    private Interpreter interpreter;
    private int inputSize;
    public List<String> labelList;
    private boolean quant;

    private static final int ROAD_LABEL_POS = 1;//position of road in label list
    private static final int OBSTACLE_LABEL_POS = 0;//position of obstacle in label list

    public static final int FORWARD_LABEL_POS = 0;//just like labelList indexing, position in label list (MainActivity.USE_TURN == true), hardcoded for performance
    public static final int LEFT_LABEL_POS = 1;
    public static final int RIGHT_LABEL_POS = 2;
    public static final int STOP_LABEL_POS = 3;

    private int[] intValues;

    private RoadClassifier() {

    }

    static RoadClassifier create(AssetManager assetManager,
                             String modelPath,
                             String labelPath,
                             int inputSize,
                             boolean quant) throws IOException {

        RoadClassifier classifier = new RoadClassifier();
        classifier.interpreter = new Interpreter(classifier.loadModelFile(assetManager, modelPath), new Interpreter.Options());
        classifier.labelList = classifier.loadLabelList(assetManager, labelPath);
        classifier.inputSize = inputSize;
        classifier.quant = quant;

        classifier.intValues = new int[inputSize * inputSize];
        if(quant) {
            byteBuffer = ByteBuffer.allocateDirect(BATCH_SIZE * inputSize * inputSize * PIXEL_SIZE);
        } else {
            byteBuffer = ByteBuffer.allocateDirect(4 * BATCH_SIZE * inputSize * inputSize * PIXEL_SIZE);
        }
        byteBuffer.order(ByteOrder.nativeOrder());
        return classifier;
    }

    public byte isRoad(Bitmap bitmap) {
        long start = elapsedRealtime();
        ByteBuffer byteBuffer = convertBitmapToByteBuffer(bitmap);
        Log.v("MAKIN", "convert lama: "+(elapsedRealtime()-start));
        if(quant){
            byte[][] result = new byte[1][labelList.size()];
            interpreter.run(byteBuffer, result);
            Log.v("MAKIN", "model data length: "+result[0].length);
            if (result[0][ROAD_LABEL_POS]>result[0][OBSTACLE_LABEL_POS]) {
                return 1;
            }
            else {
                return 0;
            }
        } else {
            float [][] result = new float[1][labelList.size()];
            start = elapsedRealtime();
            interpreter.run(byteBuffer, result);
            Log.v("MAKIN", "interpret lama: "+(elapsedRealtime()-start));
            Log.v("MAKIN", "model data length: "+result[0].length);
            if (result[0][ROAD_LABEL_POS]>result[0][OBSTACLE_LABEL_POS]) {
                return 1;
            }
            else {
                return 0;
            }
        }
    }

    public byte isRoadTurn(Bitmap bitmap) {
        long start = elapsedRealtime();
        ByteBuffer byteBuffer = convertBitmapToByteBuffer(bitmap);
        Log.v("MAKIN", "convert lama: "+(elapsedRealtime()-start));
        if(quant){
            byte[][] result = new byte[1][labelList.size()];
            interpreter.run(byteBuffer, result);
            Log.v("MAKIN", "model data length: "+result[0].length);
            return (byte)findMaxByte(result[0]);
        } else {
            float [][] result = new float[1][labelList.size()];
            start = elapsedRealtime();
            interpreter.run(byteBuffer, result);
            Log.v("MAKIN", "interpret lama: "+(elapsedRealtime()-start));
            Log.v("MAKIN", "model data length: "+result[0].length);
//            Log.v("MAKIN", "contoh data r[1][0]: "+result[1][0]);
            Log.v("MAKIN", "Hasil: "+labelList.get((byte)findMaxFloat(result[0])));
            return (byte)findMaxFloat(result[0]);
        }
    }

    //return string of binary values of the classification
    // example 0110 means input being classified as 1st category results in not confident, 2nd in confident, 3rd in confident, 4th not confident
    public String classify(Bitmap bitmap) {
        ByteBuffer byteBuffer = convertBitmapToByteBuffer(bitmap);
        if(quant){
            byte[][] result = new byte[1][labelList.size()];
            interpreter.run(byteBuffer, result);
//            Log.v("MAKIN", "model data length: "+result[0].length);
            String res = "";
            for (int i=0;i<result[0].length;i++) {
                res += ((int)Math.round(result[0][i]));
            }
            return res;
        } else {
            float [][] result = new float[1][labelList.size()];
            interpreter.run(byteBuffer, result);
//            Log.v("MAKIN", "model data length: "+result[0].length);
//            return "0:"+Math.round(100*(result[0][0]))+", 1:"+Math.round(100*(result[0][1]));
            String res = "";
            for (int i=0;i<result[0].length;i++) {
                res += ((int)Math.round(result[0][i]));
            }
            return res;
        }
    }

    public void close() {
        interpreter.close();
        interpreter = null;
    }

    private MappedByteBuffer loadModelFile(AssetManager assetManager, String modelPath) throws IOException {
        AssetFileDescriptor fileDescriptor = assetManager.openFd(modelPath);
        FileInputStream inputStream = new FileInputStream(fileDescriptor.getFileDescriptor());
        FileChannel fileChannel = inputStream.getChannel();
        long startOffset = fileDescriptor.getStartOffset();
        long declaredLength = fileDescriptor.getDeclaredLength();
        return fileChannel.map(FileChannel.MapMode.READ_ONLY, startOffset, declaredLength);
    }

    private List<String> loadLabelList(AssetManager assetManager, String labelPath) throws IOException {
        List<String> labelList = new ArrayList<>();
        BufferedReader reader = new BufferedReader(new InputStreamReader(assetManager.open(labelPath)));
        String line;
        while ((line = reader.readLine()) != null) {
            labelList.add(line);
        }
        reader.close();
        for (int i=0;i<labelList.size();i++) {
            Log.v("MAKIN","Label i:"+i+": "+labelList.get(i));
        }
        return labelList;
    }

    private ByteBuffer convertBitmapToByteBuffer(Bitmap bitmap) {
        byteBuffer.clear();
        bitmap.getPixels(intValues, 0, bitmap.getWidth(), 0, 0, bitmap.getWidth(), bitmap.getHeight());
        int pixel = 0;
        for (int i = 0; i < inputSize; ++i) {
            for (int j = 0; j < inputSize; ++j) {
                final int val = intValues[pixel];
                if(quant){
                    byteBuffer.put((byte) ((val >> 16) & 0xFF));
                    byteBuffer.put((byte) ((val >> 8) & 0xFF));
                    byteBuffer.put((byte) (val & 0xFF));
                } else {
                    byteBuffer.putFloat((((val >> 16) & 0xFF)-IMAGE_MEAN)/IMAGE_STD);
                    byteBuffer.putFloat((((val >> 8) & 0xFF)-IMAGE_MEAN)/IMAGE_STD);
                    byteBuffer.putFloat((((val) & 0xFF)-IMAGE_MEAN)/IMAGE_STD);
                }
                pixel++;

            }
        }
        return byteBuffer;
    }


    // get max byte, return the index
    public int findMaxByte(byte[] bytes) {
        int index = 3;
        try {
            byte max = bytes[0];
            for (int i = 0; i < bytes.length; i++) {
                if (bytes[i]>max) {
                    max = bytes[i];
                    index = i;
                }
            }
        } catch (ArrayIndexOutOfBoundsException e) {
            Log.w("MAKIN", "maxByte(bytes) bytes length is zero, returning zero");
        }
        finally {
            return index;
        }
    }
    // get max float, return the index
    public int findMaxFloat(float[] floats) {
        int index = 3;
        try {
            float max = floats[0];
            for (int i = 0; i < floats.length; i++) {
                if (floats[i]>max) {
                    max = floats[i];
                    index = i;
                }
                Log.v("MAXBYTE", "current i: "+i+" val: "+floats[i]);
            }
        } catch (ArrayIndexOutOfBoundsException e) {
            Log.w("MAKIN", "maxByte(bytes) bytes length is zero, returning zero");
        }
        finally {
            return index;
        }
    }


//    public byte makinRoadDetection(Bitmap input) {
//
//    }
}

