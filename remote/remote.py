#!/home/kareem/anaconda3/bin/python3.6
"""
requires:
    Coapthon3
    pynput
"""
import curses
import os
import logging
from coapthon.client.helperclient import HelperClient
from pynput import keyboard

DEBUG = False

if not DEBUG:
    logging.getLogger().setLevel(100)

def printlog(x):
    if DEBUG:
        print(x)

class Car(object):
    # ~ ip = "192.168.1.100"
    ip = "192.168.4.1"
    port = 5683 #coap port
    path_prepend = "/v1/f/"
    path_forward = path_prepend + "car_forward"
    path_backward =path_prepend + "car_backward"
    path_speed = path_prepend   + "car_speed"
    path_speedA = path_prepend   + "car_speedA"
    path_speedB = path_prepend   + "car_speedB"
    path_steer = path_prepend   + "car_steer"
    
    steer_center = 80
    steer_min = 60
    steer_max = 100
    speed_base = 1020
    speed_differential = 400 #when turning left/right, differs lower speed to be this value
    requesting = False
    
    last_command = None
    last_payload = None
    current_speed = 0
    current_steer = 80
    
    # keyboard keys that control car
    key_forward = '`'
    key_backward = keyboard.Key.tab
    key_left = '*' #good in numpad position
    key_right = '-'#good in numpad position

    def __init__(self):
        self.client = HelperClient(server=(Car.ip, Car.port))

        # blocking listener to keyboard events
        with keyboard.Listener(
            on_press=self.key_press,
            on_release=self.key_release
        ) as listener:
            listener.join()

    def notrequesting(self, response):
        self.requesting = False
        print(response)
        
        
    def forward(self, speed):
        """
        car go forward
        @param speed range 0~1023
        """
        if self.last_command==self.forward and abs(self.last_payload-speed)<200:
            return
        self.last_command = self.forward
        self.last_payload = speed
        
        self.client.post(self.path_forward, str(speed), timeout=0.1)


    def backward(self, speed):
        """
        car go backward
        @param speed range 0~1023
        """
        if self.last_command==self.backward and abs(self.last_payload-speed)<100:
            return
        self.last_command = self.backward
        self.last_payload = speed
        
        self.client.post(self.path_backward, str(speed), timeout=0.1)


    def speed(self, speed):
        """
        change the current speed
        @param speed range 0~1023
        """
        self.client.post(self.path_speed, str(speed), timeout=0.1)

    def speed_a(self, speed):
        """
        change the current speed
        @param speed range 0~1023
        """
        self.client.post(self.path_speedA, str(speed), timeout=0.1)
        
    def speed_b(self, speed):
        """
        change the current speed
        @param speed range 0~1023
        """
        self.client.post(self.path_speedB, str(speed), timeout=0.1)


    def stop(self):
        """
        stop the car
        """
        if self.last_command==self.stop:
            return
        self.last_command = self.stop
        
        self.speed(0)


    def steer(self, degree):
        """
        @param steer 80 center, range 80-20 to 80+20
        """
        if degree<60:
            degree = 60
        elif degree>100:
            degree = 100
        
        if self.last_command==self.steer and self.last_payload==degree:
            return
        self.last_command = self.steer
        self.last_payload = degree
        
        self.client.post(self.path_steer, str(degree), timeout=0.1)
        if self.current_speed>0:
            if degree>self.steer_center:
                self.speed_b(self.speed_differential)
            elif degree<self.steer_center:
                self.speed_a(self.speed_differential)


    def key_press(self, key):
        """
        remote controll, on key press
        """
        try:
            printlog('alphanumeric key {0} pressed'.format(key.char))
            
            if (key.char==self.key_forward):
                if self.current_speed==0:
                    self.current_speed = self.speed_base
                self.current_speed += 1
                self.forward(self.current_speed)

            elif key.char==self.key_left or key.char==self.key_right:
                if key.char==self.key_left:
                    if self.current_steer>=self.steer_center:
                        self.current_steer = self.steer_center-10
                    self.current_steer -= 5
                
                if key.char==self.key_right:
                    if self.current_steer<=self.steer_center:
                        self.current_steer = self.steer_center+10
                    self.current_steer += 5
                
                if self.current_steer<self.steer_min:
                    self.current_steer = self.steer_min
                elif self.current_steer>self.steer_max:
                    self.current_steer = self.steer_max
                
                self.steer(self.current_steer)
                
        except AttributeError: #cant call key.char
            if (key==self.key_backward):
                if self.current_speed==0:
                    self.current_speed = self.speed_base
                self.current_speed += 1
                self.backward(int(self.current_speed))
                
    def key_release(self, key):
        """
        remote controll, on key released
        """
        printlog('{0} released'.format(key))
        try:
            if key==self.key_backward or key.char==self.key_forward:
                self.stop()
                self.current_speed = 0
            elif key.char==self.key_left or key.char==self.key_right:
                self.steer(self.steer_center)
                self.current_steer = self.steer_center
                if self.current_speed>0:
                    self.speed(self.speed_base)
        except AttributeError:pass #cant call key.char
        
        # ~ if key == keyboard.Key.esc:
            # ~ # Stop listener
            # ~ return False

app = Car()
