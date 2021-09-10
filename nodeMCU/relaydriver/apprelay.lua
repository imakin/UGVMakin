led = 5

driverIN1 = 1
driverIN2 = 2
driverIN3 = 3
driverIN4 = 4

steeringpwm = 6
STEER_CENTER = 82
current_steer = STEER_CENTER

cs = "coapserver"
udpSocket = "udpsocket"
tcpsocket = "tcpsocket"

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
  
  pwm.setup(steeringpwm, 50, STEER_CENTER)
  pwm.start(steeringpwm)
  

  return "init"
end

--**
--* turn the steering, d middle is STEER_CENTER, range between d-20 to d+20
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
      
      gpio.write(driverIN1, (bit.isset(datanum, 0) and 1 or 0))
      gpio.write(driverIN2, (bit.isset(datanum, 1) and 1 or 0))
      gpio.write(driverIN3, (bit.isset(datanum, 2) and 1 or 0))
      gpio.write(driverIN4, (bit.isset(datanum, 3) and 1 or 0))
      
      datanum = bit.rshift(datanum, 4)
      car_steer(datanum)
      return true
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
