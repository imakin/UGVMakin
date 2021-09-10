#!/home/kareem/anaconda3/bin/python3.6
"""
requires:
    socket
    pynput
"""
import os
import logging
import socket
from pynput import keyboard

DEBUG = True

if not DEBUG:
    logging.getLogger().setLevel(100)

def printlog(x):
    if DEBUG:
        print(x)

class Car(object):
    # ~ ip = "192.168.1.100"
    ip = "192.168.4.1"
    port = 5000 #nodemcu udp socket port
    
    steer_center = 82
    steer_min = 60
    steer_max = 100
    speed_base = 300
    speed_differential = 200 #when turning left/right, differs lower speed to be this value
    requesting = False
    
    last_command = None
    last_payload = None
    current_speed = 0
    current_steer = 75
    
    # ~ -- 0b 11111111 1111
    # ~ -- least significant 4 bit: gpio of relay: bit 3 to 0: IN4 IN3 IN2 IN1
    # ~ -- following 8 bits: steering pwm value
    current_value = 75<<4 #current value
    
    # keyboard keys that control car
    key_forward = '`'
    key_forward1 = '1' #more speed
    key_forward2 = '2' #max speed
    key_backward = keyboard.Key.tab
    key_left = '*' #good in numpad position
    key_right = '-'#good in numpad position

    def __init__(self):
        self.client = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

        # blocking listener to keyboard events
        with keyboard.Listener(
            on_press=self.key_press,
            on_release=self.key_release
        ) as listener:
            listener.join()
    
    
    def socket_send(self, data=None):
        """
        send self.current_value, or send data (type: str)
        
        """
        msg = bytearray()
        if data!=None:
            msg.extend(map(ord, str(data)))
            printlog("sending ({})".format(data))
        else:
            msg.extend(map(ord, str(self.current_value)))
            printlog("sending ({})".format(self.current_value))
        return self.client.sendto(msg, (self.ip, self.port))
        
    def forward(self, speed=None, sendnow=True):
        """
        car go forward
        @param speed range 0~1023
        """
        if self.last_command==self.forward and abs(self.last_payload-speed)<200:
            return
        self.last_command = self.forward
        self.last_payload = speed

        self.current_value = (self.current_value & 0b111111111011) | 0b1000
        if speed!=None:
            self.speed(speed,sendnow) # socket_send called there
        elif sendnow:
            self.socket_send()


    def backward(self, speed=None, sendnow=True):
        """
        car go backward
        @param speed range 0~1023
        """
        if self.last_command==self.backward and abs(self.last_payload-speed)<100:
            return
        self.last_command = self.backward
        self.last_payload = speed
        
        self.current_value = (self.current_value & 0b111111110111) | 0b100
        if speed!=None:
            self.speed(speed,sendnow) # socket_send called there
        elif sendnow:
            self.socket_send()


    def speed(self, speed, sendnow=True):
        """
        change the current speed
        @param speed range 0~3
        """
        speed_encoded = 0
        if speed==0:
            self.current_value |= 0b1111 #stop
        elif speed==1:
            self.current_value = (self.current_value & 0b111111111100) | 0b11
        elif speed==2:
            self.current_value = (self.current_value & 0b111111111100) | 0b10
        elif speed==3:
            self.current_value = (self.current_value & 0b111111111100)
        
        print(speed)
        if sendnow:self.socket_send()

    def stop(self, sendnow=True):
        """
        stop the car
        """
        if self.last_command==self.stop:
            return
        self.last_command = self.stop
        
        self.speed(0, sendnow)


    def steer(self, degree, sendnow=True):
        """
        @param degree is the pwm value of steering, 80 center, range 80-20 to 80+20
        """
        if degree<60:
            degree = 60
        elif degree>100:
            degree = 100
        
        if self.last_command==self.steer and self.last_payload==degree:
            return
        self.last_command = self.steer
        self.last_payload = degree
        
        self.current_value &= 0b000000001111
        self.current_value |= (degree<<4)
        
        if sendnow: self.socket_send()
        

    def key_press(self, key):
        """
        remote controll, on key press
        """
        try:
            printlog('alphanumeric key {0} pressed'.format(key.char))
            
            if (key.char==self.key_forward):
                self.current_speed = 1
                self.forward(self.current_speed)
            
            elif (key.char==self.key_forward1):
                self.current_speed = 2
                self.forward(self.current_speed)
            
            elif (key.char==self.key_forward2):
                self.current_speed = 3
                self.forward(self.current_speed)

            elif key.char==self.key_left or key.char==self.key_right:
                if key.char==self.key_left:
                    if self.current_steer<=self.steer_center:
                        self.current_steer = self.steer_center+10
                    self.current_steer += 5
                
                if key.char==self.key_right:
                    if self.current_steer>=self.steer_center:
                        self.current_steer = self.steer_center-10
                    self.current_steer -= 5
                
                if self.current_steer<self.steer_min:
                    self.current_steer = self.steer_min
                elif self.current_steer>self.steer_max:
                    self.current_steer = self.steer_max
                
                self.steer(self.current_steer)
            
            #set wifi mode
            elif key.char=="8":
                self.speed_base = self.speed_base + 100
                if self.speed_base>1023:
                    self.speed_base = 1023
                if self.current_speed!=0:
                    self.current_speed = self.speed_base
                    self.speed(self.speed_base)
            elif key.char=="2":
                self.speed_base = self.speed_base - 100
                if self.speed_base<0:
                    self.speed_base = 0
                if self.current_speed!=0:
                    self.current_speed = self.speed_base
                    self.speed(self.speed_base)
                else:
                    self.current_speed = self.speed_base - 100
                self.speed_base = self.current_speed
            # ~ elif key.char=="b":
                # ~ self.socket_send("b")
            # ~ elif key.char=="g":
                # ~ self.socket_send("g")
            # ~ elif key.char=="n":
                # ~ self.socket_send("n")
            

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
            if key==self.key_backward or key.char in [self.key_forward, self.key_forward1, self.key_forward2]:
                self.stop()
                self.current_speed = 0
            elif key.char==self.key_left or key.char==self.key_right:
                self.steer(self.steer_center, sendnow=False)
                self.current_steer = self.steer_center
                if self.current_speed>0:
                    self.speed(self.speed_base, sendnow=False)
                self.socket_send()
        except AttributeError:pass #cant call key.char
        
        # ~ if key == keyboard.Key.esc:
            # ~ # Stop listener
            # ~ return False

app = Car()
