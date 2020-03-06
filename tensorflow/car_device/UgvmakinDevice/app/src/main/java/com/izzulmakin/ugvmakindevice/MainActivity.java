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
    private static final String MODEL_PATH = "leftright.tflite";
    private static final boolean QUANT = false;
    private static final String LABEL_PATH = "leftright_labels.txt";
    private static final int INPUT_SIZE = 128;

    private static final boolean USE_TURN = true; //determine left/right turn from pic, if false, determine only from segmentation

    private RoadClassifier classifier;
    private SensorListener sensorListener;

    private Executor executor = Executors.newSingleThreadExecutor();
    private TextView textViewResult;
    private Button btnDetectObject;
    private ImageView imageViewResult;
    private CameraKitView cameraView;
    private TextView tv_orientation;

    private static boolean is_running = false;
    private Bitmap segmentedBitmap = null; //croppedBitmap might be cropped again, into 9 segments
    private static final int recognizeSequenceLimit = 10;//makin: counter for recognize attempt, may reset to 0 when reached this limit
    private int recognizeSequence = 0;//makin: counter for recognize attempt, counter reset at certain limit
    private static final int recognizeSequenceSegmentation_column = 5; //for a frame, divide it into recognizeSequenceLimit segments, which is recognizeSequenceSegmentation_column column
    private static final int recognizeSequenceSegmentation_row = recognizeSequenceLimit/recognizeSequenceSegmentation_column;

    private byte[] road;    //containing the segmented frame, values if road or not.
                            // 2 dimension [recognizeSequenceSegmentation_column,recognizeSequenceSegmentation_row] stored in 1 dimension
    private String[] road_label;    //road, but in labels string,
                                    // each element could be Forward, Left, Right, Stop or Obstacle, Road depends on USE_TURN
    private boolean saveimg = false;
    private String saveimg_id;

    private CarDriver car;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        sensorListener = new SensorListener(this);
        car = new CarDriver(this);
        cameraView = findViewById(R.id.cameraView);
        cameraView.setImageMegaPixels(0.4f);
        cameraView.setAspectRatio(1f);

        imageViewResult = findViewById(R.id.imageViewResult);
        textViewResult = findViewById(R.id.textViewResult);
        textViewResult.setMovementMethod(new ScrollingMovementMethod());
        btnDetectObject = findViewById(R.id.btnDetectObject);
        tv_orientation = findViewById(R.id.tv_orientation);

        ((Switch)findViewById(R.id.sw_running)).setOnCheckedChangeListener(this);
        ((Switch)findViewById(R.id.sw_flash)).setOnCheckedChangeListener(this);
        ((Switch)findViewById(R.id.sw_save)).setOnCheckedChangeListener(this);

        btnDetectObject.setOnClickListener(this);

        initTensorFlowAndLoadModel();
        segmentedBitmap = Bitmap.createBitmap(INPUT_SIZE, INPUT_SIZE, Bitmap.Config.ARGB_8888);
        road = new byte[recognizeSequenceSegmentation_column * recognizeSequenceSegmentation_row];
        road_label = new String[recognizeSequenceSegmentation_column * recognizeSequenceSegmentation_row];
    }

    @Override
    public void onImage(CameraKitView cameraKitView, final byte[] capturedImage) {
        // capturedImage contains the image from the CameraKitView.
        Bitmap scaledBitmap = BitmapFactory.decodeByteArray(capturedImage, 0, capturedImage.length);
/*      final int bw = bitmap.getWidth();
        final int bh = bitmap.getHeight();

        //scale it
        int reqH = INPUT_SIZE*recognizeSequenceSegmentation_row;
        int reqW = INPUT_SIZE*recognizeSequenceSegmentation_column;
        if (bw>bh) {
            reqW = Math.round(reqH*bw/bh); //slightly increase reqW so reqH can be fulfilled
        }
        else {
            reqH = Math.round(reqW*bh/bw); //slightly increase reqH so reqW can be fulfilled
        }
        Matrix matrix = new Matrix();
        matrix .setRectToRect(new RectF(0, 0, bitmap.getWidth(), bitmap.getHeight()), new RectF(0, 0, reqW, reqH), Matrix.ScaleToFit.CENTER);
        final Bitmap scaledBitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), matrix, true);
*/
        //clear road
        for (int i = 0; i < road.length; i++) {
            if (USE_TURN) {
                road[i] = RoadClassifier.STOP_LABEL_POS;
            }
            road[i] = 0;
            road_label[i] = "Stop";
        }
        // 012
        // 345
        // 5x2:
        // 01234
        // 56789
        boolean savebitmap = saveimg;
        if (savebitmap) {
            String new_saveimg_id = "" + elapsedRealtime() / 5000;//per 5k, once every 5sec
            if (saveimg_id == new_saveimg_id) {
                savebitmap = false;
            }
            else {
                saveimg_id = new_saveimg_id;
            }
        }
        if (savebitmap) {
            saveBitmap(
                    scaledBitmap,
                    Environment.getExternalStorageDirectory() + "/makin/ugvtraining/ugvmakin_" + saveimg_id + "_FRAME.png"
            );
        }
        byte[] optimized_seq = {2, 7, 6, 8, 5, 9, 0, 1, 3, 4};
        for (byte b : optimized_seq) {
            long s = elapsedRealtime();
            recognizeSequence = b;
            //crop it per segment, one sequence one segment
            final int cbw = scaledBitmap.getWidth();
            final int cbh = scaledBitmap.getHeight();

            int left_offset = 0;
            int top_offset = 0;
            left_offset = Math.round((cbw - (INPUT_SIZE * recognizeSequenceSegmentation_column)) / 2); //to crop exess width, take center
            top_offset = -45 + Math.round((cbh - (INPUT_SIZE * recognizeSequenceSegmentation_row))); //to crop exess height, don't center it but bottom-first
            //hardcoded 45: the height of Car Front captured in frame

            final int left = left_offset + INPUT_SIZE * (recognizeSequence % recognizeSequenceSegmentation_column);
            final int top = top_offset + INPUT_SIZE * ((int) (Math.floor(recognizeSequence / recognizeSequenceSegmentation_column)));
            new Canvas(segmentedBitmap).drawBitmap(
                    scaledBitmap,
                    new Rect(left, top, left + INPUT_SIZE, top + INPUT_SIZE),
                    new Rect(0, 0, INPUT_SIZE, INPUT_SIZE),
                    null
            );


            if (savebitmap) {
                saveBitmap(
                        segmentedBitmap,
                        Environment.getExternalStorageDirectory() + "/makin/ugvtraining/ugvmakin_" + saveimg_id + "_" + recognizeSequence + ".png"
                );
            }

            Log.v(MAKIN, "segmentedBitmap sizes: " + segmentedBitmap.getWidth() + ":" + segmentedBitmap.getHeight());
            final int sbw = segmentedBitmap.getWidth();
            final int sbh = segmentedBitmap.getHeight();
            Log.v(MAKIN, "Bitmap preparation: " + (elapsedRealtime() - s));
            byte result;
            if (USE_TURN) {
                //try to detect best possible turn for each frame
                result = classifier.isRoadTurn(segmentedBitmap);
            } else {
                //detect only obstacle/road, determine turn from the segment/sequence
                result = classifier.isRoad(segmentedBitmap);
            }
            road[recognizeSequence] = result;
            road_label[recognizeSequence] = classifier.labelList.get(result);
            // 5x2:
            // 01234
            // 56789
            if (USE_TURN) {
                if (
                        (recognizeSequence == 7 && !road_label[recognizeSequence].equals("Stop")) ||
                        (recognizeSequence == 2 && !road_label[recognizeSequence].equals("Stop")) ||
                        (recognizeSequence == 6 && !road_label[recognizeSequence].equals("Stop")) ||
                        (recognizeSequence == 8 && !road_label[recognizeSequence].equals("Stop")) ||
                        (recognizeSequence == 5 && !road_label[recognizeSequence].equals("Stop")) ||
                        (recognizeSequence == 9 && !road_label[recognizeSequence].equals("Stop"))
                ) {
                    break;
                }
            }
            else if (
                    (recognizeSequence == 2 && result > 0)
                    || (recognizeSequence == 6 && result > 0)
                    || (recognizeSequence == 8 && result > 0)
                    || (recognizeSequence == 5 && result > 0)
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

        boolean speed = false;
        if (sensorListener.orientation[2] < -1.7) {
            speed = true;
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    if (tv_orientation.getText() != "steep hill more power")
                        tv_orientation.setText("steep hill more power");
                }
            });
        }
        else {
            runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    if (tv_orientation.getText()!="flat land normal power")
                        tv_orientation.setText("flat land normal power");
                }
            });
        }

        // 01234
        // 56789
        if (USE_TURN) {
            //hardcoded
            for (int i=0;i<1;i++) {//once looped loop, so that it can break;
                String turn = "Stop";
                if (!road_label[2].equals("Stop")) {
                    turn = road_label[2];
                }
                if (!road_label[7].equals("Stop")) {
                    turn = road_label[7];
                }
                if (!turn.equals("Stop")) {
                    if (turn.equals("Left")) {
                        car.turnLeft(10);
                        car.moveStep(500, speed);
                    }
                    else if (turn.equals("Right")) {
                        car.turnRight(10);
                        car.moveStep(500, speed);
                    }
                    else {
                        car.turnCenter();
                        car.moveStep(600, speed);
                    }
                    break;
                }

                if (
                    !road_label[0].equals("Stop") ||
                    !road_label[1].equals("Stop") ||
                    !road_label[5].equals("Stop") ||
                    !road_label[6].equals("Stop")
                ) {
                    car.turnLeft(15);
                    car.moveStep(400, speed);
                    break;
                }

                if (
                        !road_label[3].equals("Stop") ||
                        !road_label[4].equals("Stop") ||
                        !road_label[8].equals("Stop") ||
                        !road_label[9].equals("Stop")
                ) {
                    car.turnRight(15);
                    car.moveStep(400, speed);
                    break;
                }
                car.stop();
                car.send();
            }
        }
        else {
            if (road_string.equals("00000\n00110")) {
                car.turnRight(15);
                car.moveStep(400, speed);
            } else if (road_string.equals("00000\n01100")) {
                car.turnLeft(15);
                car.moveStep(400, speed);
            } else if (turn_forward >= turn_left && turn_forward >= turn_right && turn_forward > 0) {
                car.turnCenter();
                car.moveStep(600, speed);
            } else if (turn_left > turn_right) {
                car.turnLeft(15);
                car.moveStep(400, speed);
            } else if (turn_right > turn_left) {
                car.turnRight(15);
                car.moveStep(400, speed);
            } else if (road_string.equals("00000\n01010")) {
                car.turnCenter();
                car.moveStep(600, speed);
            } else {
                car.stop();
                car.send();
            }
        }

        final String road_string_final = road_string;
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                imageViewResult.setImageBitmap(segmentedBitmap);
                textViewResult.setText(
                    "forward: "+turn_forward+
                    "\nleft: "+turn_left+
                    "\nright: "+turn_right+
                    "\nROAD:\n" +
                    road_string_final
                );
            }
        });

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
        sensorListener.onResume();
    }

    @Override
    protected void onPause() {
        cameraView.onPause();
        sensorListener.onPause();
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

    public void showOrientation(final float val) {

        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                tv_orientation.setText(""+val);
            }
        });
    }
}
