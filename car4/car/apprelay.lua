led = 5

driverIN1 = 1
driverIN2 = 2
driverIN3 = 3
driverIN4 = 4
---
--- 4WD: IN4 = 0, 2WD: IN4 = 1
--- SLOW WIRE: IN3 = 0, SLOW WIRE DISCONNECT: IN3 = 1
--- FORWARD: IN1=0 IN2=1, BACKWARD: IN1=1 IN2=0
--- STOP: IN1=1 IN2=1
steeringpwm_pin = 6
STEER_CENTER = 82
current_steer = STEER_CENTER

cs = "coapserver"
udpSocket = "udpsocket"
tcpsocket = "tcpsocket"

clients_connected = 0

function car_init()
  gpio.mode(driverIN1, gpio.OUTPUT)
  gpio.mode(driverIN2, gpio.OUTPUT)
  gpio.mode(driverIN3, gpio.OUTPUT)
  gpio.mode(driverIN4, gpio.OUTPUT)
  gpio.mode(led, gpio.OUTPUT)
  gpio.write(driverIN1, 1)
  gpio.write(driverIN2, 1)
  gpio.write(driverIN3, 1)
  gpio.write(driverIN4, 1)
  gpio.write(led, 1)

  pwm.setup(steeringpwm_pin, 50, STEER_CENTER)
  pwm.start(steeringpwm_pin)


  return "init"
end

--**
--* turn the steering, d middle is STEER_CENTER, range between d-20 to d+20
--**
function car_steer(d)
  local steerint = tonumber(d)
  pwm.setduty(steeringpwm_pin, steerint)
  current_steer = steerint
  return "t"
end

function car_stop()
  -- then stop
  gpio.write(4,0) --all wheel
  gpio.write(3,1) --dont use slow wire
  gpio.write(2,1) 
  gpio.write(1,1)
end

function car_forward()
  gpio.write(4,0) --all wheel
  gpio.write(3,1) --dont use slow wire
  gpio.write(2,1)
  gpio.write(1,0)
end
function car_backward()
  gpio.write(4,0) --all wheel
  gpio.write(3,1) --dont use slow wire
  gpio.write(2,0)
  gpio.write(1,1)
end

--- 4WD: IN4 = 0, 2WD: IN4 = 1
--- SLOW WIRE: IN3 = 0, SLOW WIRE DISCONNECT: IN3 = 1
--- FORWARD: IN1=0 IN2=1, BACKWARD: IN1=1 IN2=0
--- STOP: IN1=1 IN2=1
-- emergency break
function car_emergency_break()
  gpio.write(4,1) --rear only (has metal gear)
  gpio.write(3,1) --dont use slow wire
  gpio.write(2,0)
  gpio.write(1,1)
  --let it backward for 400ms
  tmr.delay(500000)
  -- then stop
  gpio.write(4,0) --all wheel
  gpio.write(3,1) --dont use slow wire
  gpio.write(2,1) 
  gpio.write(1,1)
end

car_emergency_break_timer = tmr.create()
car_emergency_break_timer:register(
  700, -- call emergency timer this seconds after triggered
  tmr.ALARM_SEMI,
  function(tmrobj)
    car_emergency_break()
  end
)

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
      --~ print(string.format("'%s' from %s:%d", datanum, ip, port))

      if datanum=="test" then
        s:send(port, ip, "ack")
      end

      -- 0b 11111111 1111
      -- least significant 4 bit: gpio of relay: bit 3 to 0: IN4 IN3 IN2 IN1
      -- following 8 bits: steering pwm value

      local datanum = tonumber(datanum)
      if datanum==nil then
        --~ print("tonumber(message) results in nil")
        return false
      end
      car_emergency_break_timer:stop()
      -- (check bit, check if it is HIGH, and cast to boolean)
      gpio.write(driverIN1, (bit.isset(datanum, 0) and 1 or 0))
      gpio.write(driverIN2, (bit.isset(datanum, 1) and 1 or 0))
      gpio.write(driverIN3, (bit.isset(datanum, 2) and 1 or 0))
      gpio.write(driverIN4, (bit.isset(datanum, 3) and 1 or 0))
      if ((bit.isset(datanum, 0)==false) and (bit.isset(datanum, 1))) then
        car_emergency_break_timer:start()
      end
      

      datanum = bit.rshift(datanum, 4)
      car_steer(datanum)
      return true
  end)
end


function net_init_http()
  srv = net.createServer(net.TCP)
  print("listening to http")
  srv:listen(80, function(server)
    server:on("receive", function(sck, payload)
      --~ print(payload)
      --~ print("slash n in:")
      --~ print(string.find(payload,' HTTP')) --http packet first line is: GET /path-url HTTP/1.1
      --~ sck:send("HTTP/1.0 200 OK\r\nContent-Type: text/html\r\n\r\n<html> <head> <style> button { font-size: 100px; font-family: 'Oxygen Mono', Arial; padding: 40px; } </style> </head> <body> <script> var p = 1359; var steer = 84; var drive = 0b1111; function send() { var newp = (steer<<4) + drive; if (newp!=p) { p = newp; document.location.pathname = '/'+p; } } function l(){ steer = 84-15; send(); } function r(){ steer = 84+15; send(); } function f(){ drive = 2; send(); } function b(){ drive = 1; send(); } </script> <div> <button onclick='l()'>&lt;</button> <button onclick='r()'>&gt;</button> <div> <div> <button onclick='f()'>F</button> <button onclick='b()'>B</button> <div> </body> </html>")
      sck:send("HTTP/1.0 200 OK\r\nContent-Type: text/html\r\n\r\nmasuk>")

      local datanum = tonumber(payload:match("%d+"))
      if datanum==nil then
        --~ print("tonumber(message) results in nil")
        return false
      end

      gpio.write(driverIN1, (bit.isset(datanum, 0) and 1 or 0))
      gpio.write(driverIN2, (bit.isset(datanum, 1) and 1 or 0))
      gpio.write(driverIN3, (bit.isset(datanum, 2) and 1 or 0))
      gpio.write(driverIN4, (bit.isset(datanum, 3) and 1 or 0))

      print(bit.band(datanum,15))
      datanum = bit.rshift(datanum, 4)
      print('steer to')
      print(datanum)
      car_steer(datanum)
      return true

    end)
    server:on("sent", function(sck) sck:close() end)
  end)
end
_G.net_init_http = net_init_http


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
    --~ net_init_http()
    if (clients_connected==0) then
      net_init_udp()
    end
    clients_connected = clients_connected + 1
    
   end
  ssid.stadisconnected_cb = function(mac, aid)
    car_emergency_break()
    print("disconnected: ")
    print(mac)
  end
  wifi.ap.config(ssid)
end

car_init()
remote_init_as_server()

api = {}
api.steer = car_steer
api.emergency_break = car_emergency_break
api.emergency_break_timer = car_emergency_break_timer
api.forward = car_forward
api.backward = car_backward
api.stop = car_stop
return api
