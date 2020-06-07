package com.izzulmakin.ugvstreamer;

import androidx.appcompat.app.AppCompatActivity;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.RectF;
import android.net.DhcpInfo;
import android.net.wifi.WifiManager;
import android.os.AsyncTask;
import android.os.Bundle;
import android.util.Log;
import android.widget.CompoundButton;
import android.widget.Switch;

import com.camerakit.CameraKitView;

import java.io.IOException;
import java.io.OutputStream;
import java.io.PrintWriter;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.MulticastSocket;
import java.net.ServerSocket;
import java.net.Socket;
import java.nio.ByteBuffer;
import java.util.logging.Logger;

import static android.os.SystemClock.elapsedRealtime;

public class MainActivity extends AppCompatActivity
        implements CameraKitView.ImageCallback,
        CompoundButton.OnCheckedChangeListener {
    private CameraKitView cameraKitView;
    private boolean running = false;
    private InetAddress broadcastAddress;
    private ByteBuffer datatosend;
    private byte sendseq = 0;
    private byte sendseqmax = 3;

    DatagramSocket socket;
    MainActivity thisActivity;

    InetAddress getBroadcastAddress() throws IOException {
        WifiManager wifi = (WifiManager) getApplicationContext().getSystemService(Context.WIFI_SERVICE);
        DhcpInfo dhcp = wifi.getDhcpInfo();
        // handle null somehow

        int broadcast = (dhcp.ipAddress & dhcp.netmask) | ~dhcp.netmask;
        byte[] quads = new byte[4];
        for (int k = 0; k < 4; k++)
            quads[k] = (byte) ((broadcast >> k * 8) & 0xFF);
        return InetAddress.getByAddress(quads);
    }

    class SendSocket extends AsyncTask<byte[], Void, Integer> {

        private Exception exception;

        protected Integer doInBackground(byte[]... data) {
            long s = elapsedRealtime();
            try {
//                Socket socket = new Socket(InetAddress.getByAddress(new Byte(192,168,1,102)), 5000);
//
//                OutputStream out = socket.getOutputStream();
//                PrintWriter output = new PrintWriter(out);
//                output.println(datastring);
//
//                out.flush();
//                out.close();
//                socket.close();


//                //Open a random port to send the package
//                DatagramSocket socket = new DatagramSocket();
//                socket.setBroadcast(true);
//                Log.i("MAKIN", "ngirim "+data[0].length);
//                DatagramPacket sendPacket = new DatagramPacket(data[0], data[0].length, broadcastAddress, 5000);
//                socket.send(sendPacket);
//                Log.i("MAKIN", "packet sent");

                //Open a random port to send the package
//                socket.joinGroup(broadcastAddress);



                //decode to bitmap
                Bitmap bitmap = BitmapFactory.decodeByteArray(data[0], 0, data[0].length);

                //scale bitmap
                int reqW = 100;
                int reqH = 75;
                Matrix matrix = new Matrix();
                matrix .setRectToRect(new RectF(0, 0, bitmap.getWidth(), bitmap.getHeight()), new RectF(0, 0, reqW, reqH), Matrix.ScaleToFit.CENTER);
                final Bitmap scaledBitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), matrix, true);

                //get bytearray
                int size = scaledBitmap.getWidth() * scaledBitmap.getHeight()+1;//1 byte is for the channel
                Log.i("MAKIN", "w:"+scaledBitmap.getWidth()+ " h:"+scaledBitmap.getHeight()+" size: "+size);
                try {
                    datatosend.clear();
                } catch (NullPointerException e) {
                    datatosend = ByteBuffer.allocate(size);
                }

                datatosend.put(sendseq);

                for (int y=0; y<scaledBitmap.getHeight();y++) {
                    for (int x=0; x<scaledBitmap.getWidth();x++) {
                        int pixel = scaledBitmap.getPixel(x,y);
//                        if (sendseq==0) {
//                            datatosend.put((byte) Color.red(pixel));
//                        }if (sendseq==1) {
//                            datatosend.put((byte) Color.green(pixel));
//                        }if (sendseq==2) {
//                            datatosend.put((byte) Color.blue(pixel));
//                        }
                        int gray = (Color.red(pixel) + Color.green(pixel) + Color.blue(pixel))/3; //take 0.33333 of each portion
                        datatosend.put((byte)gray);
                    }
                }
                sendseq += 1;
                if (sendseq>=sendseqmax) {
                    sendseq = 0;
                }

//                Log.i("MAKIN", "nyampe2");
//                scaledBitmap.copyPixelsToBuffer(datatosend);
                byte[] byteArray = datatosend.array();
                Log.i("MAKIN", "preparing data elapsed in "+ (elapsedRealtime() - s));

                DatagramPacket dt = new DatagramPacket(byteArray, byteArray.length, broadcastAddress,5000);
                Log.i("MAKIN", "ngirim "+byteArray.length);
                socket.send(dt);
                Log.i("MAKIN", "packet sent");


                return 0;
            } catch (IOException e) {
                this.exception = e;
                e.printStackTrace();
            } catch (Exception e) {
                this.exception = e;
                e.printStackTrace();
            } finally {
                Log.i("MAKIN", "nyampe finally. time elapsed: "+ (elapsedRealtime() - s));
            }
            return 1;
        }

        protected void onPostExecute(Integer res) {
            // TODO: check this.exception
            // TODO: do something with the feed
            Log.i("MAKIN", "lagi?: "+running);
            if (running) {
                cameraKitView.captureImage(thisActivity);
            }
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        thisActivity = this;
        setContentView(R.layout.activity_main);
        cameraKitView = findViewById(R.id.camera);
        try {
            broadcastAddress = getBroadcastAddress();
            socket = new DatagramSocket();
            socket.setBroadcast(true);

        } catch (IOException e) {
            e.printStackTrace();
        }
        ((Switch) findViewById(R.id.sw_camera)).setOnCheckedChangeListener(this);
    }


    @Override
    public void onImage(CameraKitView cameraKitView, byte[] bytes) {
//        Bitmap bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.length);
//        int reqW = 100;
//        int reqH = 75;
//        Matrix matrix = new Matrix();
//        matrix .setRectToRect(new RectF(0, 0, bitmap.getWidth(), bitmap.getHeight()), new RectF(0, 0, reqW, reqH), Matrix.ScaleToFit.CENTER);
//        final Bitmap scaledBitmap = Bitmap.createBitmap(bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), matrix, true);
//
//
//        Log.i("MAKIN","Image filesize: "+scaledBitmap.getByteCount());
//        byte[] x = new byte[4];
//        x[0] = (byte)(scaledBitmap.getWidth()>>8);
//        x[1] = (byte)(scaledBitmap.getWidth());
//        x[2] = (byte)(scaledBitmap.getHeight()>>8);
//        x[3] = (byte)(scaledBitmap.getHeight()>>8);
        Log.v("MAKIN","ambil gambar");
        new SendSocket().execute(bytes);
    }


    @Override
    protected void onStart() {
        super.onStart();
        cameraKitView.onStart();
    }

    @Override
    protected void onResume() {
        super.onResume();
        cameraKitView.onResume();
    }

    @Override
    protected void onPause() {
        cameraKitView.onPause();
        super.onPause();

    }

    @Override
    protected void onStop() {
        cameraKitView.onStop();
        super.onStop();
    }

    @Override
    public void onRequestPermissionsResult(int requestCode, String[] permissions, int[] grantResults) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        cameraKitView.onRequestPermissionsResult(requestCode, permissions, grantResults);
    }

    @Override
    public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
        if (buttonView.getId()==R.id.sw_camera) {
            Log.i("MAKIN", "jalankan?:"+isChecked);
            if (isChecked && (running==false)) {
                running = true;
                cameraKitView.captureImage(this);
            }
            else if (running && isChecked==false) {
                running = false;
            }
        }
    }
}
