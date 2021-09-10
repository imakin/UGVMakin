led = 2

motorA0 = 0
motorA1 = 1
motorApwm = 4
motorB0 = 2
motorB1 = 3
motorBpwm = 5

steeringpwm = 6
STEER_CENTER = 80
current_steer = STEER_CENTER

speed_timer = tmr.create()
cs = "coapserver"
udpSocket = "udpsocket"
tcpsocket = "tcpsocket"

function car_init()
  gpio.mode(motorA0, gpio.OUTPUT)
  gpio.mode(motorA1, gpio.OUTPUT)
  gpio.mode(motorB0, gpio.OUTPUT)
  gpio.mode(motorB1, gpio.OUTPUT)
  pwm.setup(motorApwm, 2000, 0)
  pwm.setup(motorBpwm, 2000, 0)
  pwm.start(motorApwm)
  pwm.start(motorBpwm)
  pwm.setup(steeringpwm, 50, STEER_CENTER)
  pwm.start(steeringpwm)
  
  speed_timer:register(5000, tmr.ALARM_SEMI, function (timerobject)
    car_stop()
  end)

  return "init"
end

function car_stop()
  gpio.write(motorA0, 0)
  gpio.write(motorA1, 0)
  gpio.write(motorB0, 0)
  gpio.write(motorB1, 0)
  pwm.setduty(motorApwm, 0)
  pwm.setduty(motorBpwm, 0)
  return "s"
end

function car_speed(speed)
  --~ speed_timer:stop()
  pwm.setduty(motorApwm, tonumber(speed))
  pwm.setduty(motorBpwm, tonumber(speed))
  --~ speed_timer:start()
  return "p"
end

function car_speedA(sA)
  pwm.setduty(motorApwm, tonumber(sA))
  return "pA"
end

function car_speedB(sB)
  pwm.setduty(motorBpwm, tonumber(sB))
  return "pB"
end

function car_forward(speed)
  gpio.write(motorA0, 0)
  gpio.write(motorA1, 1)
  gpio.write(motorB0, 1)
  gpio.write(motorB1, 0)
  if not (speed==nil) then
    car_speed(speed)
  end
  return "f"
end

function car_backward(speed)
  gpio.write(motorA0, 1)
  gpio.write(motorA1, 0)
  gpio.write(motorB0, 0)
  gpio.write(motorB1, 1)
  if not (speed==nil) then
    car_speed(speed)
  end
  return "b"
end

function car_steer_center()
  pwm.setduty(steeringpwm, 80)
  current_steer = STEER_CENTER
  return "c"
end

--**
--* turn the steering, d middle is 80, range between d-20 to d+20
--**
function car_steer(d)
  local steerint = tonumber(d)
  pwm.setduty(steeringpwm, steerint)
  current_steer = steerint
  return "t"
end


function coap_init()
  cs = coap.Server()
  cs:listen(5683)
  cs:func("car_stop")
  cs:func("car_speed")
  cs:func("car_speedA")
  cs:func("car_speedB")
  cs:func("car_forward")
  cs:func("car_backward")
  cs:func("car_steer")
  cs:func("car_steer_center")
  print("coap initialized")
end

function net_init_udp()
  udpSocket = net.createUDPSocket()
  print("listening to net")
  udpSocket:listen(5000)
  udpSocket:on("receive", function(s, datanum, port, ip)
      print(string.format("'%s' from %s:%d", datanum, ip, port))
      --~ s:send(port, ip, "ack")
      
      -- 0b 1111111111 1111111111 11111111 1
      -- least significant 1 bit: direction 1 forward, 0 backward
      -- following 8 bits: steering pwm value
      -- most significant 20 bits: MSB 10 bits motor A PWM, LSB 10 bits motor B PWM
      if datanum=="b" then
        wifi.setphymode(wifi.PHYMODE_B)
        print("wifi:B")
      elseif datanum=="g" then
        wifi.setphymode(wifi.PHYMODE_G)
        print("wifi:G")
      elseif datanum=="n" then
        wifi.setphymode(wifi.PHYMODE_N)
        print("wifi:N")
      else
        local datanum = tonumber(datanum)
        if datanum==nil then
          print("tonumber(message) results in nil")
          return false
        end
        local direction = bit.band(datanum, 1)
        datanum = bit.rshift(datanum, 1)
        local steering = bit.band(datanum, 255)
        datanum = bit.rshift(datanum, 8)
        local motor_b = bit.band(datanum, 1023)
        datanum = bit.rshift(datanum, 10)
        local motor_a = bit.band(datanum, 1023)
        
        if (direction==0) then
          car_backward()
        else
          car_forward()
        end
        car_steer(steering)
        car_speedA(motor_a)
        car_speedB(motor_b)
      end
  end)
end

function remote_init_as_client()
  gpio.write(led, 1)
  wifi.setmode(wifi.STATION)
  --~ wifi.setphymode(wifi.PHYMODE_B)
  local ssid = {}
  ssid.ssid = "recording_your_data"
  ssid.pwd = "ldks297599_--"
  ssid.auto = false
  ssid.save = false
  wifi.sta.config(ssid)
  ipcfg = {
    ip = "192.168.1.100",
    netmask = "255.255.255.0",
    gateway = "192.168.1.1"
  }
  wifi.sta.setip(ipcfg)
  wifi.sta.connect(function (ssid,bssid, ch)
    gpio.write(led, 0)
    net_init_udp()
  end)
end

function remote_init_as_server()
  gpio.write(led, 1)
  wifi.setmode(wifi.SOFTAP)
  wifi.setphymode(wifi.PHYMODE_B)
  local ssid = {}
  ssid.ssid = "ugvmakin"
  ssid.auth = wifi.WPA_WPA2_PSK
  ssid.pwd = "astaughfirullah"
  ssid.save = false
  ssid.staconnected_cb = function(mac, aid)
    gpio.write(led, 0)
    print("connected: ")
    print(mac)
    net_init_udp()
   end
  ssid.stadisconnected_cb = function(mac, aid)
    print("disconnected: ")
    print(mac)
  end
  wifi.ap.config(ssid)
end

car_init()
remote_init_as_server()
