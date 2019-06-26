led = 4

bt_right = 5
bt_left = 6
bt_forward = 7
bt_backward = 3

_G.udpsocket = 0

car_net_ip = "192.168.4.1"
car_net_port = 5000

steer_center = 75
current_steer = steer_center
current_direction = 1
current_speed = 0
  -- 0b 11111111 1111
  -- least significant 4 bit: gpio of relay: bit 3 to 0: IN4 IN3 IN2 IN1
  -- following 8 bits: steering pwm value
  
last_data = 1295 -- (80<<4) | 0b1111
stop_checking_button = false
ssid = {}

_G.check_button = function()
    _G.udpsocket = net.createUDPSocket()
    broadcast_ip = wifi.sta.getbroadcast()
    _G.udpsocket:on("receive", function(s,d,p,i)
        if d=="ack" then
            gpio.write(led, 0)
        end
        print(d)
    end)
    _G.udpsocket:send(car_net_port, broadcast_ip, "test")
    while true do
        if (gpio.read(bt_right)==0) then
            current_steer = steer_center + 20
        elseif (gpio.read(bt_left)==0) then
            current_steer = steer_center - 20
        else
            current_steer = steer_center
        end
        
        -- current steer in data-ready bit position
        current_steer = bit.lshift(current_steer, 4)
        
        data = 0
        if (gpio.read(bt_forward)==0) then
            data = 11 -- 0b1011
            --~ if (gpio.read(bt_backward)==0) then
                --~ break -- end loop DEBUG
            --~ end
        elseif (gpio.read(bt_backward)==0) then
            data = 7 -- 0b0111
        else
            data = 15 -- 0b1111 (stop)
        end
        data = data + current_steer
        
        if not (data==last_data) then
            _G.udpsocket:send(car_net_port, broadcast_ip, tostring(data))
            print("sending " .. tostring(data))
            last_data = data
            _G.data = data
        end
        if stop_checking_button then break end
        tmr.delay(500)
    end
end
_G.wifi_connected_cb = function(ssid, bssid, channel)
    print("nyambung")
    gpio.write(led, 1)
    --~ _G.udpsocket:listen(5001)
    --~ _G.udpsocket:on("receive", function(s, data, port, ip)
        --~ print(string.format("received '%s' from %s:%d", data, ip, port))
        --~ s:send(port, ip, "echo: " .. data)
    --~ end)
    --~ port, ip = _G.udpSocket:getaddr()
    --~ print(string.format("local UDP socket address / port: %s:%d", ip, port))
    stop_checking_button = false
    --~ _G.check_button()
end
_G.initremote = function()
    gpio.mode(led,          gpio.OUTPUT)
    gpio.mode(bt_right,     gpio.INPUT, gpio.PULLUP)
    gpio.mode(bt_left,      gpio.INPUT, gpio.PULLUP)
    gpio.mode(bt_forward,   gpio.INPUT, gpio.PULLUP)
    gpio.mode(bt_backward,  gpio.INPUT, gpio.PULLUP)
    
    gpio.write(led, 0)
    wifi.setmode(wifi.STATION)
    --~ wifi.setphymode(wifi.PHYMODE_B)
    ssid = {}
    ssid.ssid = "ugvmakin"
    ssid.pwd = "astaughfirullah"
    ssid.auto = false
    ssid.save = false
    ssid.stadisconnected_cb = function(ssid,bssid,channel)
        print("disconnected")
        stop_checking_button = true
    end
    wifi.sta.config(ssid)
    wifi.sta.connect(_G.wifi_connected_cb)
end



_G.initremote()
