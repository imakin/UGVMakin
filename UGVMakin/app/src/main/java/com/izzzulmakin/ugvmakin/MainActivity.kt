package com.izzzulmakin.ugvmakin

import android.content.Context
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbManager
import android.support.v7.app.AppCompatActivity
import android.os.Bundle
import android.support.constraint.solver.widgets.Helper
import android.view.View
import android.widget.TextView
import android.widget.Toast
import com.izzzulmakin.ugvmakin.example;
import kotlinx.android.synthetic.main.activity_main.*
import org.w3c.dom.Text
import com.hoho.android.usbserial.driver.UsbSerialProber
import com.hoho.android.usbserial.driver.UsbSerialDriver
import com.hoho.android.usbserial.driver.UsbSerialPort



class MainActivity : AppCompatActivity() {
    lateinit var tv_output:TextView;
    lateinit var tv_readstatus:TextView;
    lateinit var tv_sendstatus:TextView;

    lateinit var usbManager:UsbManager;
    lateinit var usbConnection:UsbDeviceConnection;
    lateinit var usbPort: UsbSerialPort;

    var is_usbPortOpen = false
    var is_usbDeviceInitialized = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_main)

        tv_readstatus = findViewById(R.id.tv_readstatus)
        tv_sendstatus = findViewById(R.id.tv_sendstatus)
        tv_output = findViewById(R.id.tv_output)

    }

    fun init_serial() {
        val availableDrivers = UsbSerialProber.getDefaultProber().findAllDrivers(usbManager)
        if (availableDrivers.isEmpty()) {
            return
        }

        // Open a connection to the first available driver.
        var driver:UsbSerialDriver = availableDrivers.get(0)
        usbConnection = usbManager.openDevice(driver.getDevice())
        if (usbConnection == null) {
            // You probably need to call UsbManager.requestPermission(driver.getDevice(), ..)
            return;
        }

        // Read some data! Most have just one port (port 0).
        usbPort = driver.getPorts().get(0)

        is_usbDeviceInitialized = true;
    }

    fun usbPortOpen() {
        (Toast.makeText(applicationContext, "port open", Toast.LENGTH_LONG)).show()
        if (is_usbDeviceInitialized) {
            usbPort.open(usbConnection)
            usbPort.setParameters(115200, 8, UsbSerialPort.STOPBITS_1, UsbSerialPort.PARITY_NONE)
            is_usbPortOpen = true
        }
    }

    fun usbPortClose() {
        (Toast.makeText(applicationContext, "port closed", Toast.LENGTH_LONG)).show()
        if (is_usbDeviceInitialized) {
            usbPort.close()
            is_usbPortOpen = false
        }
    }

    fun start(v:View) {
        try {
            usbManager =  getSystemService(Context.USB_SERVICE) as UsbManager;
            init_serial()
            usbPortOpen()
        }
        catch (e:Exception) {
            tv_output.setText(e.message)
        }
    }

    fun read(v:View) {
        val buffer = ByteArray(100)
        val numBytesRead = usbPort.read(buffer, 2000)
        tv_readstatus.setText(String(buffer, Charsets.UTF_8));
    }

    fun send(v:View) {
        val b = "sendTest()\n".toByteArray()
        usbPort.write(b, 1000)
        tv_sendstatus.setText("sendTest()\n")
    }


    override fun onPause() {
        super.onPause()
        usbPortClose()

    }

    override fun onDestroy() {
        super.onDestroy()
        usbPortClose()
    }

    override fun onResume() {
        super.onResume()
        usbPortOpen()
    }
}
