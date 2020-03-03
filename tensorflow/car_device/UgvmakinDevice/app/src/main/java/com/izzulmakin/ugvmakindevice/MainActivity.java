package com.izzulmakin.ugvmakindevice;

import androidx.appcompat.app.AppCompatActivity;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Matrix;
import android.graphics.Rect;
import android.graphics.RectF;
import android.os.Bundle;
import android.os.Environment;
import android.text.method.ScrollingMovementMethod;
import android.util.Log;
import android.view.View;
import android.widget.Button;
import android.widget.CompoundButton;
import android.widget.ImageView;
import android.widget.Switch;
import android.widget.TextView;

import com.camerakit.CameraKit;
import com.camerakit.CameraKitView;
import com.camerakit.CameraKitView.ImageCallback;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.List;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;

import de.mobilej.thinr.Thinr;

import static android.os.SystemClock.elapsedRealtime;


public class MainActivity extends AppCompatActivity
implements ImageCallback,CompoundButton.OnCheckedChangeListener,View.OnClickListener
{
    public static final String MAKIN = "makin";
    private static final String MODEL_PATH = "road_optimized_128.tflite";
    private static final boolean QUANT = false;
    private static final String LABEL_PATH = "road_label.txt";
    private static final int INPUT_SIZE = 128;

    private RoadClassifier classifier;

    private Executor executor = Executors.newSingleThreadExecutor();
    private TextView textViewResult;
    private Button btnDetectObject;
    private ImageView imageViewResult;
    private CameraKitView cameraView;

    private static boolean is_running = false;
    private Bitmap segmentedBitmap = null; //croppedBitmap might be cropped again, into 9 segments
    private static final int recognizeSequenceLimit = 10;//makin: counter for recognize attempt, may reset to 0 when reached this limit
    private int recognizeSequence = 0;//makin: counter for recognize attempt, counter reset at certain limit
    private static final int recognizeSequenceSegmentation_column = 5; //for a frame, divide it into recognizeSequenceLimit segments, which is recognizeSequenceSegmentation_column column
    private static final int recognizeSequenceSegmentation_row = recognizeSequenceLimit/recognizeSequenceSegmentation_column;

    private byte[] road;    //containing the segmented frame, values if road or not.
                            // 2 dimension [recognizeSequenceSegmentation_column,recognizeSequenceSegmentation_row] stored in 1 dimension

    private boolean saveimg = false;

    private CarDriver car;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        car = new CarDriver(this);
        cameraView = findViewById(R.id.cameraView);
        cameraView.setImageMegaPixels(0.4f);
        cameraView.setAspectRatio(1f);

        imageViewResult = findViewById(R.id.imageViewResult);
        textViewResult = findViewById(R.id.textViewResult);
        textViewResult.setMovementMethod(new ScrollingMovementMethod());
        btnDetectObject = findViewById(R.id.btnDetectObject);

        ((Switch)findViewById(R.id.sw_running)).setOnCheckedChangeListener(this);
        ((Switch)findViewById(R.id.sw_flash)).setOnCheckedChangeListener(this);
        ((Switch)findViewById(R.id.sw_save)).setOnCheckedChangeListener(this);

        btnDetectObject.setOnClickListener(this);

        initTensorFlowAndLoadModel();
        segmentedBitmap = Bitmap.createBitmap(INPUT_SIZE, INPUT_SIZE, Bitmap.Config.ARGB_8888);
        road = new byte[recognizeSequenceSegmentation_column * recognizeSequenceSegmentation_row];
    }

    @Override
    public void onImage(CameraKitView cameraKitView, final byte[] capturedImage) {
        // capturedImage contains the image from the CameraKitView.
        Bitmap scaledBitmap = BitmapFactory.decodeByteArray(capturedImage, 0, capturedImage.length);
//        final int bw = bitmap.getWidth();
//        final int bh = bitmap.getHeight();
//
//        //scale it
//        int reqH = INPUT_SIZE*recognizeSequenceSegmentation_row;
//        int reqW = INPUT_SIZE*recognizeSequenceSegmentation_column;
//        if (bw>bh) {
//            reqW = Math.round(reqH*bw/bh); //slightly increase reqW so reqH can be fulfilled
//        }
//        else {
//            reqH = Math.round(reqW*bh/bw); //slightly increase reqH so reqW can be fulfilled
//        }
//        Matrix matrix = new Matrix();
//        matrix .setRectToRect(new RectF(0, 0, bitmap.getWidth(), bitmap.getHeight()), new RectF(0, 0, reqW, reqH), Matrix.ScaleToFit.CENTER);
//        final Bitmap scaledBitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), matrix, true);

        //clear road
        for (int i = 0; i < road.length; i++) {
            road[i] = 0;
        }
        // 012
        // 345
        // 5x2:
        // 01234
        // 56789
        byte[] optimized_seq = {2, 7, 6, 8, 5, 9};
        for (int i=0;i<optimized_seq.length;i++) {
            long s = elapsedRealtime();
            recognizeSequence = optimized_seq[i];
            //crop it per segment, one sequence one segment
            final int cbw = scaledBitmap.getWidth();
            final int cbh = scaledBitmap.getHeight();

            int left_offset = 0;
            int top_offset = 0;
            left_offset = Math.round((cbw - (INPUT_SIZE * recognizeSequenceSegmentation_column)) / 2); //to crop exess width, take center
            top_offset = -45+Math.round((cbh - (INPUT_SIZE * recognizeSequenceSegmentation_row))); //to crop exess width, don't center it but bottom-first
            //hardcoded 45: the height of Car Front captured in frame

            final int left = left_offset + INPUT_SIZE * (recognizeSequence % recognizeSequenceSegmentation_column);
            final int top = top_offset + INPUT_SIZE * ((int) (Math.floor(recognizeSequence / recognizeSequenceSegmentation_column)));
            new Canvas(segmentedBitmap).drawBitmap(
                    scaledBitmap,
                    new Rect(left, top, left + INPUT_SIZE, top + INPUT_SIZE),
                    new Rect(0, 0, INPUT_SIZE, INPUT_SIZE),
                    null
            );


            if (saveimg) {
                saveBitmap(segmentedBitmap, Environment.getExternalStorageDirectory()+"/makin/ugvtraining/ugvmakin_"+(elapsedRealtime()/10000)+"_"+recognizeSequence+".jpg");//per 10k, once every 10sec
            }

            Log.v(MAKIN, "segmentedBitmap sizes: " + segmentedBitmap.getWidth() + ":" + segmentedBitmap.getHeight());
            final int sbw = segmentedBitmap.getWidth();
            final int sbh = segmentedBitmap.getHeight();
            Log.v(MAKIN, "Bitmap preparation: "+(elapsedRealtime()-s));
            final byte results = classifier.isRoad(segmentedBitmap);
            road[recognizeSequence] = results;
            if (
                (recognizeSequence==2 && results==1)
                || (recognizeSequence==6 && results==1)
                || (recognizeSequence==8 && results==1)
                || (recognizeSequence==5 && results==1)
            ) {

                break;// if far forward or either left/right possible, don't check the other
            }
        }

        String road_string = "";
        for (int i = 0; i < road.length; i++) {
            if (i == recognizeSequenceSegmentation_column) {
                road_string += "\n";
            }
            road_string += road[i];
        }

        final int turn_left = road[0]+road[1]+road[5]+road[6];
        final int turn_forward = road[2]+road[7];
        final int turn_right = road[3]+road[4]+road[8]+road[9];

        // 01234
        // 56789
        if (road_string=="00000\n00110") {
            car.turnRight(15);
            car.moveStep(400);
        }
        else if (road_string=="00000\n01100") {
            car.turnLeft(15);
            car.moveStep(400);
        }
        else if (turn_forward >= turn_left && turn_forward >= turn_right && turn_forward > 0) {
            car.turnCenter();
            car.moveStep(600);
        } else if (turn_left > turn_right) {
            car.turnLeft(15);
            car.moveStep(400);
        } else if (turn_right > turn_left) {
            car.turnRight(15);
            car.moveStep(400);
        } else if (road_string=="00000\n01010") {
            car.turnCenter();
            car.moveStep(600);
        } else {
            car.stop();
        }

        final String road_string_final = road_string;
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                imageViewResult.setImageBitmap(segmentedBitmap);
                textViewResult.setText(
                        "" +
                        //                        results +
                        //                        "\nbitmapSize: "+
                        //                        bw+":"+bh +
                        //                        "\nscaledBitmapSize: "+
                        //                        cbw+":"+cbh +
                        //                        "\nsegmentedBitmap sizes: "+
                        //                        sbw+":"+sbh +
                        //                        "\nrecognize seq: "+
                        //                        recognizeSequence+
                        //                        "\nsegment left,top:"+
                        //                        left+","+top+
                        "forward: "+turn_forward+
                        "\nleft: "+turn_left+
                        "\nright: "+turn_right+
                        "\nROAD:\n" +
                        road_string_final
                );
            }
        });

//        recognizeSequence += 1;
//        if (recognizeSequence >= recognizeSequenceLimit) {
//            recognizeSequence = 3;
//        }
        if (this.is_running) {
            cameraView.captureImage(this);//loop
        }
    }


    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        cameraView.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    @Override
    protected void onStart() {
        super.onStart();
        cameraView.onStart();
    }

    @Override
    protected void onResume() {
        super.onResume();
        cameraView.onResume();
    }

    @Override
    protected void onPause() {
        cameraView.onPause();
        super.onPause();
    }

    @Override
    protected void onStop() {
        cameraView.onStop();
        super.onStop();
    }


    @Override
    protected void onDestroy() {
        super.onDestroy();
        executor.execute(new Runnable() {
            @Override
            public void run() {
                classifier.close();
            }
        });
    }

    private void initTensorFlowAndLoadModel() {
        executor.execute(new Runnable() {
            @Override
            public void run() {
                try {
                    classifier = RoadClassifier.create(
                            getAssets(),
                            MODEL_PATH,
                            LABEL_PATH,
                            INPUT_SIZE,
                            QUANT);
                } catch (final Exception e) {
                    Log.e(MAKIN, "kesalahan ada pada");
                    Log.e(MAKIN, e.getMessage());
                    throw new RuntimeException("Error initializing TensorFlow!", e);
                }
            }
        });
    }



    @Override
    public void onClick(View v) {
        int id = v.getId();
        if (id==R.id.btnDetectObject) {
            cameraView.captureImage(this);
        }
    }

    @Override
    public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
        final int id = buttonView.getId();
        if (id==R.id.sw_running) {
            if (this.is_running == false) {
                cameraView.captureImage(this);
            }
            this.is_running = isChecked;
        }
        else if (id==R.id.sw_flash) {
            if (isChecked) {
                cameraView.setFlash(CameraKit.FLASH_TORCH);
            }
            else {
                cameraView.setFlash(CameraKit.FLASH_OFF);
            }
        }
        else if (id==R.id.sw_save) {
            saveimg = isChecked;
        }
    }

    private void saveBitmap(Bitmap bitmap,String path){
        if(bitmap!=null){
            try {
                FileOutputStream outputStream = null;
                try {
                    outputStream = new FileOutputStream(path); //here is set your file path where you want to save or also here you can set file object directly

                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream); // bitmap is your Bitmap instance, if you want to compress it you can compress reduce percentage
                    // PNG is a lossless format, the compression factor (100) is ignored
                } catch (Exception e) {
                    e.printStackTrace();
                } finally {
                    try {
                        if (outputStream != null) {
                            outputStream.close();
                        }
                    } catch (IOException e) {
                        e.printStackTrace();
                    }
                }
            } catch (Exception e) {
                e.printStackTrace();
            }
        }
    }
}
