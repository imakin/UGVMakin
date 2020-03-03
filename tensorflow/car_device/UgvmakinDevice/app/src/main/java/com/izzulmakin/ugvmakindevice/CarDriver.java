package com.izzulmakin.ugvmakindevice;

import android.util.Log;

import androidx.appcompat.app.AppCompatActivity;

import com.android.volley.Request;
import com.android.volley.RequestQueue;
import com.android.volley.Response;
import com.android.volley.VolleyError;
import com.android.volley.toolbox.StringRequest;
import com.android.volley.toolbox.Volley;

import java.io.IOException;
import java.net.HttpURLConnection;
import java.net.MalformedURLException;
import java.net.URL;

public class CarDriver {
    public int steer_pwm;//steer
    //these relay is active-low
    public int relays; //forward relay1, backward relay2, speed relay3, 4wd relay4
    public int direction; //relay1 relay2
    public int speed; //relay3
    public int wheel; //relay4

    private static final int STEER_CENTER = 84;
    private static final int STEER_MAX_TURN = 15;

    private static final String car_address = "192.168.4.1";
    private static final int car_port = 5000;
    private AppCompatActivity compatActivity;

    RequestQueue queue;

    CarDriver(AppCompatActivity _compatActivity) {
        compatActivity = _compatActivity;
        queue = Volley.newRequestQueue(compatActivity);
    }

    public void setRelay(int relay_state) {
        relays = relay_state;
    }
    public void setTurn(int steer) {
        steer_pwm = steer;
    }

    public void turnLeft(int steer_offset) {
        if (steer_offset>STEER_MAX_TURN) {
            steer_offset = STEER_MAX_TURN;
        }
        steer_pwm = STEER_CENTER + steer_offset;
    }

    public void turnRight(int steer_offset) {
        if (steer_offset>STEER_MAX_TURN) {
            steer_offset = STEER_MAX_TURN;
        }
        steer_pwm = STEER_CENTER - steer_offset;
    }

    public void turnCenter(){
        steer_pwm = STEER_CENTER;
    }

    //set 4wd/rear drive 2wd (4th bit low)
    public void setWheel(boolean allwheel) {
        if (allwheel) {
            relays &= 0b0111;
        } else {
            relays |= 0b1000;
        }
    }

    // set speed high/low (3rd bit low)
    public void setSpeed(boolean highspeed) {
        if (highspeed) {
            relays &= 0b1011;
        }
        else  {
            relays |= 0b0100;
        }
    }

    // move forward (2nd bit high, 1st bit low)
    public void forward() {
        relays &= 0b1100;
        relays |= 0b0010;
    }

    // move backward (2nd bit low, 1st bit high)
    public void backward() {
        relays &= 0b1100;
        relays |= 0b0001;
    }

    // stop (2nd 1st bit hight
    public void stop() {
        relays |= 0b0011;
    }

    public void send() {
        int data = (steer_pwm<<4) | relays;
        String urlstring ="http://"+car_address+"/"+data;


        // Request a string response from the provided URL.
        StringRequest stringRequest = new StringRequest(Request.Method.GET, urlstring,
            new Response.Listener<String>() {
                @Override
                public void onResponse(String response) {
                    // Display the first 500 characters of the response string.
                    Log.v("MAKIN","Response is: "+ response);
                }
            }, new Response.ErrorListener() {
            @Override
            public void onErrorResponse(VolleyError error) {
                error.printStackTrace();
                Log.e("MAKIN","That didn't work!");
            }
        });
        queue.add(stringRequest);
    }


    public void moveStep(){
        moveStep(500);
    }
    //move forward, wait length milisecond, then stop
    public void moveStep(int length) {

        this.setSpeed(false);
        this.setWheel(true);
        this.forward();
        Log.v("MAKIN", "movestep");
        this.send();
        final CarDriver self = this;

        new android.os.Handler().postDelayed(
                new Runnable() {
                    public void run() {
                        Log.i("tag", "This'll run 300 milliseconds later");
                        self.stop();
                        self.send();
                    }
                },
                length);
    }


}
