led = 4

bt_right = 5
bt_left = 6
bt_forward = 2
bt_backward = 3

_G.udpsocket = 0

car_net_ip = "192.168.4.1"
car_net_port = 5000

steer_center = 81
current_steer = steer_center
current_direction = 1
default_speed = 0
current_speed = default_speed

_G.timer_last_forward = 0
_G.timer_last_speed_changed = 0

direction_adjust_delay_ms = 1000 -- time to trigger adjust dir
direction_adjust_duration_ms = 1000 -- duration of adjust dir 


  -- 0b 11111111 1111
  -- least significant 4 bit: gpio of relay: bit 3 to 0: IN4 IN3 IN2 IN1
  -- following 8 bits: steering pwm value
data = 0
last_data = 1295 -- (80<<4) | 0b1111
stop_checking_button = false
ssid = {}

direction_adjust_timer = tmr.create()
direction_adjust_timer:register(
    direction_adjust_delay_ms,
    tmr.ALARM_AUTO,
    function (timerobj)
        if gpio.read(bt_forward)==0 and gpio.read(bt_right)==1 and gpio.read(bt_left)==1 then
            data = 0
            if steer_center==81 then
                steer_center = 83
                timerobj:interval(direction_adjust_duration_ms)
            else
                steer_center = 81
                timerobj:interval(direction_adjust_delay_ms)
            end
            
            --~ if (current_steer==1296) then -- equal to 81 << 4
                --~ data = bit.band(last_data, 15) -- mask with 0b000000001111
                --~ data = data + 1328 -- ORed with 83<<4
                --~ current_steer = 1328
                --~ print("adjust on")
            --~ else
                --~ data = bit.band(last_data, 15)
                --~ data = data + 1296
                --~ current_steer = 1296
                --~ print("adjust off")
            --~ end
                
            --~ _G.udpsocket:send(car_net_port, broadcast_ip, tostring(data))
            
            --~ _G.data = data
        end
    end
)


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
    buttonlistener = tmr.create()
    buttonlistener:register(100, tmr.ALARM_AUTO, function()
    
        if (gpio.read(bt_right)==0) then
            if gpio.read(bt_left)==0 and (tmr.now() - timer_last_speed_changed)>1000000  then
                _G.timer_last_speed_changed = tmr.now()
                default_speed = default_speed + 1
                if default_speed>3 then
                    default_speed = 0
                end
                --~ print("default speed updated " .. default_speed)
            end
            
            if current_speed==3 then
                current_steer = steer_center - 5
            elseif current_speed==2 then
                current_steer = steer_center - 10
            elseif current_speed==1 then
                current_steer = steer_center - 15
            else
                current_steer = steer_center - 20
            end
        elseif (gpio.read(bt_left)==0) then
            if current_speed==3 then
                current_steer = steer_center + 5
            elseif current_speed==2 then
                current_steer = steer_center + 10
            elseif current_speed==1 then
                current_steer = steer_center + 15
            else
                current_steer = steer_center + 20
            end
        else
            current_steer = steer_center
        end
        
        -- current steer in data-ready bit position
        current_steer = bit.lshift(current_steer, 4)
        
        data = 0
        if (gpio.read(bt_forward)==0) then
            
            if gpio.read(bt_backward)==0 and (tmr.now() - timer_last_speed_changed)>1000000 then --half second length to consider as double click
                if current_speed<3 then
                    _G.timer_last_speed_changed = tmr.now()
                    current_speed = current_speed + 1
                end
            end
            direction_adjust_timer:start()
            
            if current_speed==3 then
                data = 8 --0b1000
            elseif current_speed==2 then
                data = 9 --0b1001
            elseif current_speed==1 then -- from speed 0 or 1
                data = 10 --0b1010
            else --speed = 0
                data = 11 -- 0b1011
            end
            _G.timer_last_forward = tmr.now()
        elseif (gpio.read(bt_backward)==0) then
            data = 6 -- 0b0110
            direction_adjust_timer:stop()
        else -- no forward / backward (stop)
            data = 15 -- 0b1111
            current_speed = default_speed
            direction_adjust_timer:stop()
        end
        data = data + current_steer
        
        if not (data==last_data) then
            _G.udpsocket:send(car_net_port, broadcast_ip, tostring(data))
            --~ print("sending " .. tostring(data))
            last_data = data
            _G.data = data
        end
    end)
    buttonlistener:start()
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
    starter = tmr.create()
    starter:register(3000, tmr.ALARM_SINGLE, function()
        check_button()
    end)
    starter:start()
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
