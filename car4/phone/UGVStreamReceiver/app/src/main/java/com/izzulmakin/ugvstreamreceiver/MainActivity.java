package com.izzulmakin.ugvstreamreceiver;

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
import android.provider.ContactsContract;
import android.util.Log;
import android.widget.CompoundButton;
import android.widget.ImageView;
import android.widget.Switch;

import java.io.IOException;
import java.net.DatagramPacket;
import java.net.DatagramSocket;
import java.net.Inet4Address;
import java.net.InetAddress;
import java.net.MulticastSocket;
import java.nio.ByteBuffer;

import static android.os.SystemClock.elapsedRealtime;

public class MainActivity extends AppCompatActivity implements CompoundButton.OnCheckedChangeListener {

    private InetAddress broadcastAddress;
    private DatagramSocket socket;
    private byte[] receivebuff;
    private MainActivity thisActivity;
    private Bitmap img100x75;
    private Bitmap img75x56;
    private boolean running;

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


    class StreamReceiver extends AsyncTask<Void, Void, Integer> {

        private Exception exception;

        protected Integer doInBackground(Void... data) {
            long s = elapsedRealtime();
            try {
                DatagramPacket dt = new DatagramPacket(receivebuff,receivebuff.length);
                socket.receive(dt);
                byte[] received = dt.getData();
                int w = 56;
                int h = 75;
                Log.i("MAKIN","Received! "+received.length);

                byte channel = received[0];//which rgb channel

                if (received.length>4201) {
                    w = 100;
                    h = 75;
                    for (int y=0;y<h;y++) {
                        for (int x=0;x<w;x++) {
                            int p = (0xff & received[1+ y*w + x]); //1+ is for channel

                            img100x75.setPixel(x,y,Color.argb(255,p,p,p));

//                            int orig = img100x75.getPixel(x,y);
//                            int or = Color.red(orig);
//                            int og = Color.green(orig);
//                            int ob = Color.blue(orig);
//                            if (channel==0) {
//                                img100x75.setPixel(x,y,Color.argb(255,p,og,ob));
//                            }if (channel==1) {
//                                img100x75.setPixel(x,y,Color.argb(255,or,p,ob));
//                            }if (channel==2) {
//                                img100x75.setPixel(x,y,Color.argb(255,or,og,p));
//                            }
                        }
                    }
                    thisActivity.changeImage(img100x75);
                }
                else {
                    w = 56;
                    h = 75;
                    for (int y=0;y<h;y++) {
                        for (int x=0;x<w;x++) {
                            int p = received[1+y*h + x];

                            img100x75.setPixel(x,y,Color.argb(255,p,p,p));

//                            int orig = img75x56.getPixel(x,y);
//                            int or = Color.red(orig);
//                            int og = Color.green(orig);
//                            int ob = Color.blue(orig);
//                            if (channel==0) {
//                                img75x56.setPixel(x,y,Color.argb(255,p,og,ob));
//                            }if (channel==1) {
//                                img75x56.setPixel(x,y,Color.argb(255,or,p,ob));
//                            }if (channel==2) {
//                                img75x56.setPixel(x,y,Color.argb(255,or,og,p));
//                            }
                        }
                    }
                    thisActivity.changeImage(img75x56);
                }
            } catch (Exception e) {
                this.exception = e;
                e.printStackTrace();
            } finally {
//                Log.i("MAKIN", "nyampe finally. time elapsed: "+ (elapsedRealtime() - s));
            }
            return 1;
        }

        protected void onPostExecute(Integer res) {
            if (running) {
                (new StreamReceiver()).execute();
            }
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);
        thisActivity = this;

        img100x75 = Bitmap.createBitmap(100,75,Bitmap.Config.ARGB_8888);
        img75x56 = Bitmap.createBitmap(75,56,Bitmap.Config.ARGB_8888);
        ((Switch)findViewById(R.id.running)).setOnCheckedChangeListener(this);


        receivebuff = new byte[7501];
        try {
            broadcastAddress = getBroadcastAddress();
            Log.i("MAKIN", "broadcast-address: "+broadcastAddress.toString());
            socket = new DatagramSocket(5000, InetAddress.getByName("0.0.0.0"));
            socket.setBroadcast(true);
        } catch (IOException e) {
            e.printStackTrace();
        }
    }

    void changeImage(final Bitmap img) {
        runOnUiThread(new Runnable() {
            @Override
            public void run() {
                ((ImageView)findViewById(R.id.image)).setImageBitmap(img);
            }
        });
    }


    @Override
    public void onCheckedChanged(CompoundButton buttonView, boolean isChecked) {
        if (buttonView.getId()==R.id.running) {
            if (running==false && isChecked) {
                (new StreamReceiver()).execute();
            }
            running = isChecked;
        }
    }

}
