package com.izzulmakin.ugvmakindevice;

import androidx.appcompat.app.AppCompatActivity;

import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
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

//the recent library is worse than com.wonderkiln version
import com.camerakit.CameraKitView;
import com.camerakit.CameraKitView.ImageCallback;
//import com.wonderkiln.camerakit.CameraKitError;
//import com.wonderkiln.camerakit.CameraKitEvent;
//import com.wonderkiln.camerakit.CameraKitEventListener;
//import com.wonderkiln.camerakit.CameraKitImage;
//import com.wonderkiln.camerakit.CameraKitVideo;
//import com.wonderkiln.camerakit.CameraView;

import java.io.File;
import java.io.FileOutputStream;
import java.util.List;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;


public class MainActivity extends AppCompatActivity
implements ImageCallback,CompoundButton.OnCheckedChangeListener,View.OnClickListener
{
    public static final String MAKIN = "makin";
    private static final String MODEL_PATH = "road.tflite";
    private static final boolean QUANT = false;
    private static final String LABEL_PATH = "road_label.txt";
    private static final int INPUT_SIZE = 224;

    private RoadClassifier classifier;

    private Executor executor = Executors.newSingleThreadExecutor();
    private TextView textViewResult;
    private Button btnDetectObject;
    private ImageView imageViewResult;
    private CameraKitView cameraView;
    private Switch sw_running;

    private static boolean is_running = false;




    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        cameraView = findViewById(R.id.cameraView);
        cameraView.setImageMegaPixels(0.5f);
        cameraView.setAspectRatio(1f);

        imageViewResult = findViewById(R.id.imageViewResult);
        textViewResult = findViewById(R.id.textViewResult);
        textViewResult.setMovementMethod(new ScrollingMovementMethod());
        sw_running = findViewById(R.id.sw_running);
        btnDetectObject = findViewById(R.id.btnDetectObject);

        sw_running.setOnCheckedChangeListener((CompoundButton.OnCheckedChangeListener) this);

        btnDetectObject.setOnClickListener(this);

        initTensorFlowAndLoadModel();
    }

    @Override
    public void onImage(CameraKitView cameraKitView, final byte[] capturedImage) {
        // capturedImage contains the image from the CameraKitView.
        Bitmap bitmap = BitmapFactory.decodeByteArray(capturedImage, 0, capturedImage.length);

        final Bitmap scaledBitmap = Bitmap.createScaledBitmap(
                bitmap,
                INPUT_SIZE, INPUT_SIZE,
                false
        );
        Log.i(MAKIN, "Bitmap sizes: "+bitmap.getWidth()+":"+bitmap.getHeight());
        Log.i(MAKIN, "scaledBitmap sizes: "+scaledBitmap.getWidth()+":"+scaledBitmap.getHeight());


        final int results = classifier.isRoad(scaledBitmap);

        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                imageViewResult.setImageBitmap(scaledBitmap);
                textViewResult.setText("" + results);
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
        if (v.getId()==R.id.btnDetectObject) {
            cameraView.captureImage(this);
        }
    }

    @Override
    public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
        if (this.is_running==false) {
            cameraView.captureImage(this);
        }
        this.is_running = isChecked;
    }
}
