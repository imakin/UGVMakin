led = 4

bt_right = 6
bt_left = 7
bt_forward = 5
bt_backward = 0
gpio.mode(bt_right,     gpio.INPUT, gpio.PULLUP)
gpio.mode(bt_left,      gpio.INPUT, gpio.PULLUP)
gpio.mode(bt_forward,   gpio.INPUT, gpio.PULLUP)
gpio.mode(bt_backward,  gpio.INPUT, gpio.PULLUP)

--old joystick
--~ joystick_1_select = 0
--~ joystick_2_select = 1
--~ joystick_1_bt = 3 -- 1nd joystick switch on D3, external pull-down
--~ joystick_2_bt = 2 -- 2nd joystick switch on D2, external floating, internal pull-up

--~ _G.udpsocket = 0

car_net_ip = "192.168.4.1"
car_net_port = 5000

--~ steer_center = 80
_G.steer_center = 87
current_steer = steer_center
steer_distance = -8 --the distance of the steering, negative for invert direction
current_direction = 1
default_speed = 1
current_speed = default_speed
current_relay = 15 -- gpio condition that drive relay

-- if data to be send was never changed, we will not send it repeatedly,
-- except if (timer_last_sending_limit) amount of time has passed
_G.timer_last_sending = 0
timer_last_sending_limit = 500*1000 --maximum time passed before sending the same data again, in microsec
_G.timer_last_speed_changed = 0

direction_adjust_right_delay_ms = 250 -- time to trigger adjust dir
direction_adjust_left_delay_ms = 260 -- duration of adjust dir
direction_adjust_right_steer = 87
direction_adjust_left_steer = 87

  -- 0b 11111111 1111
  -- least significant 4 bit: gpio of relay: bit 3 to 0: IN4 IN3 IN2 IN1
  -- following 8 bits: steering pwm value
data = 0
_G.data_mask = 15 -- will be masked for data, used when need to force certain relay to ON
last_data = 1295 -- (80<<4) | 0b1111
stop_checking_button = false
ssid = {}

torque_started_flag = false
torque_starter = tmr.create()
torque_starter:register(100, tmr.ALARM_SEMI,
    function(timer_object)
        _G.data_mask = 15
    end)
function torque_start()
    torque_started_flag = true
    _G.data_mask = 12
    torque_starter:start()
end

--- compare x against ref if within tolerance value, return true, else return false
function closevalue(x, ref, tolerance)
    if x==ref then
        return true
    elseif (x>ref) and ((x-ref)<tolerance) then
        return true
    elseif (ref>x) and ((ref-x)<tolerance) then
        return true
    end
    return false
end

direction_adjust_timer = tmr.create()
direction_adjust_timer:register(
    direction_adjust_right_delay_ms,
    tmr.ALARM_AUTO,
    function (timerobj)
        if (gpio.read(bt_forward)==0 or gpio.read(bt_backward)==0) and gpio.read(bt_right)==1 and gpio.read(bt_left)==1 then
            data = 0
            if steer_center==direction_adjust_right_steer then
                steer_center = direction_adjust_left_steer
                timerobj:interval(direction_adjust_left_delay_ms)
            else
                steer_center = direction_adjust_right_steer
                timerobj:interval(direction_adjust_right_delay_ms)
            end
        end
    end
)

----------------
--- BUTTON MODE-
----------------
_G.check_button = function(starterobject)
    broadcast_ip = wifi.sta.getbroadcast()
    if not(broadcast_ip) then
        print("broadcast ip fetch not ready, retrying")
        starterobject:start()
        return
    else
        starterobject:unregister()
    end

    if _G.udpsocket==nil then
        print("UDP socket make new")
        _G.udpsocket = net.createUDPSocket()
        _G.udpsocket:on("receive", function(s,d,p,i)
            if d=="ack" then
                gpio.write(led, 0)
            end
            print(d)
        end)
    end
    
    _G.udpsocket:send(car_net_port, broadcast_ip, "test")
    buttonlistener = tmr.create()
    buttonlistener:register(100, tmr.ALARM_AUTO, function()

        if (gpio.read(bt_left)==0) then
            current_steer = steer_center + steer_distance
        elseif (gpio.read(bt_right)==0) then
            current_steer = steer_center - steer_distance
        else
            current_steer = steer_center
        end

        -- current steer in data-ready bit position
        current_steer = bit.lshift(current_steer, 4)

        data = 0
        if (gpio.read(bt_forward)==0) then
            direction_adjust_timer:start()
            -- in ../../ (4wd) direction is 3 2, speed is 1 0
            -- here position speed is 3 2, direction is 1 0
            -- 3th bit is front wheel activation
            if current_speed==3 then
                data = 10 --1010 2WDH
            elseif current_speed==2 then
                data = 14 --1110 2WDL
            elseif current_speed==1 then -- from speed 0 or 1
                data = 2 --0010 4WDH
            else --speed = 0
                data = 6 --0110 4WDL
            end
            
            
            --~ -- 4wd: no speed
            --~ data = 10
        elseif (gpio.read(bt_backward)==0) then
            -- in ../../ (4wd) direction is 3 2, speed is 1 0
            -- here position speed is 3 2, direction is 1 0
            if current_speed==3 then
                data = 9 --1001
            elseif current_speed==2 then
                data = 13 -- 1101
            elseif current_speed==1 then
                data = 1 --0001
            else --speed = 0
                data = 5 --0101
            end
            -- 4wd: no speed
            --~ data = 5
            direction_adjust_timer:start()
        else -- no forward / backward (stop)
            data = 15 -- 0b1111
            current_speed = default_speed
            direction_adjust_timer:stop()
            torque_started_flag = false
        end
        
        --~ if not(torque_started_flag or data==15) then
            --~ torque_start()
        --~ end
        
        data = bit.band(data, data_mask)
        current_relay = data
        data = data + current_steer
        
        if (
            (not (data==last_data)) or
            ((tmr.now() - _G.timer_last_sending) > timer_last_sending_limit)
        )then
            _G.udpsocket:send(car_net_port, broadcast_ip, tostring(data))
            --~ print("sending " .. tostring(data))
            last_data = data
            _G.data = data
            _G.timer_last_sending = tmr.now()
        end
    end)
    buttonlistener:start()
end

starter = tmr.create()
starter:register(3000, tmr.ALARM_SEMI, check_button)
runremote = function()
    starter:start()
end

_G.wifi_connected_cb = function(ssid, bssid, channel)
    print("nyambung")
    gpio.write(led, 1)

    stop_checking_button = false
    runremote()
end
_G.init_remote = function()
    gpio.mode(led,          gpio.OUTPUT)
    gpio.write(led, 0)
    wifi.setmode(wifi.STATION)
    wifi.setphymode(wifi.PHYMODE_B)
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


--~ _G.init_remote()
remote = {}
remote.init_remote = init_remote
remote.check_button = check_button
remote.run_remote = run_remote
return remote
