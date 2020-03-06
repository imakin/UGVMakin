led = 4

bt_right = 6
bt_left = 5
bt_forward = 2
bt_backward = 3

joystick_1_select = 0
joystick_2_select = 1
joystick_1_bt = 3 -- 1nd joystick switch on D3, external pull-down
joystick_2_bt = 2 -- 2nd joystick switch on D2, external floating, internal pull-up

_G.udpsocket = 0

car_net_ip = "192.168.4.1"
car_net_port = 5000

--~ steer_center = 80
steer_center = 84
current_steer = steer_center
current_direction = 1
default_speed = 0
current_speed = default_speed
current_relay = 15 -- gpio condition that drive relay

_G.timer_last_forward = 0
_G.timer_last_speed_changed = 0

direction_adjust_right_delay_ms = 250 -- time to trigger adjust dir
direction_adjust_left_delay_ms = 260 -- duration of adjust dir
direction_adjust_right_steer = 84
direction_adjust_left_steer = 84

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
    gpio.mode(bt_right,     gpio.INPUT, gpio.PULLUP)
    gpio.mode(bt_left,      gpio.INPUT, gpio.PULLUP)
    gpio.mode(bt_forward,   gpio.INPUT, gpio.PULLUP)
    gpio.mode(bt_backward,  gpio.INPUT, gpio.PULLUP)

    _G.udpsocket = net.createUDPSocket()
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
            if gpio.read(bt_left)==0 and (tmr.now() - timer_last_speed_changed)>700000  then
                _G.timer_last_speed_changed = tmr.now()
                default_speed = default_speed + 1
                if default_speed>3 then
                    default_speed = 0
                end
                --~ print("default speed updated " .. default_speed)
            end
            if (gpio.read(bt_forward)==0) then
                if current_speed==3 then
                    current_steer = steer_center + 3 ---2WD H
                elseif current_speed==2 then
                    current_steer = steer_center + 15 --- 2WD L
                elseif current_speed==1 then
                    current_steer = steer_center + 15 ---4WD H
                else
                    current_steer = steer_center + 15 ---4WD L
                end
            else
                current_steer = steer_center + 15
            end
        elseif (gpio.read(bt_left)==0) then
            if (gpio.read(bt_forward)==0) then
                if current_speed==3 then
                    current_steer = steer_center - 3
                elseif current_speed==2 then
                    current_steer = steer_center - 15
                elseif current_speed==1 then
                    current_steer = steer_center - 15
                else
                    current_steer = steer_center - 15
                end
            else
                current_steer = steer_center - 15
            end
        else
            current_steer = steer_center
        end

        -- current steer in data-ready bit position
        current_steer = bit.lshift(current_steer, 4)

        data = 0
        if (gpio.read(bt_forward)==0) then

            if gpio.read(bt_backward)==0 and (tmr.now() - timer_last_speed_changed)>300000 then --half second length to consider as double click
                if current_speed<3 then
                    _G.timer_last_speed_changed = tmr.now()
                    current_speed = current_speed + 1
                end
            end
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
            _G.timer_last_forward = tmr.now()
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

        if not (data==last_data) then
            _G.udpsocket:send(car_net_port, broadcast_ip, tostring(data))
            --~ print("sending " .. tostring(data))
            last_data = data
            _G.data = data
        end
    end)
    buttonlistener:start()
end



------------------
--- JOYSTICK MODE-
------------------
_G.check_joystick = function(starterobject)
    broadcast_ip = wifi.sta.getbroadcast()
    if not(broadcast_ip) then
        print("broadcast ip fetch not ready, retrying")
        starterobject:start()
        return
    else
        starterobject:unregister()
    end
    gpio.mode(joystick_1_bt, gpio.INPUT, gpio.FLOAT)
    gpio.mode(joystick_2_bt, gpio.INPUT, gpio.PULLUP)
    gpio.mode(joystick_1_select, gpio.OUTPUT)
    gpio.mode(joystick_2_select, gpio.OUTPUT)
    gpio.write(joystick_1_select, 0)
    gpio.write(joystick_2_select, 0)

    _G.udpsocket = net.createUDPSocket()
    _G.udpsocket:on("receive", function(s,d,p,i)
        if d=="ack" then
            gpio.write(led, 0)
        end
        print(d)
    end)
    _G.udpsocket:send(car_net_port, broadcast_ip, "test")
    buttonlistener = tmr.create()
    buttonlistener:register(100, tmr.ALARM_AUTO, function()
        local running = 0 -- 0 stop, 1 forward, -1 backward

        gpio.write(joystick_2_select,0)
        gpio.write(joystick_1_select,1)
        local throttle = adc.read(0)

        data = 0
        if closevalue(throttle, 1024, 1) then
            running = -1
        elseif closevalue(throttle, 934, 10) then
            running = 0
        else
            running = 1
        end


        gpio.write(joystick_1_select,0)
        gpio.write(joystick_2_select,1)
        local steer = adc.read(0)

        if steer>1023 then
        -- right steer
            if (running==1) then
                if current_speed==3 then
                    current_steer = steer_center - 3
                elseif current_speed==2 then
                    current_steer = steer_center - 5
                elseif current_speed==1 then
                    current_steer = steer_center - 10
                else
                    current_steer = steer_center - 15
                end
            else
                current_steer = steer_center - 20
            end
        elseif steer<500 then
            --left steering
            if (running==1) then
                if current_speed==3 then
                    current_steer = steer_center + 3
                elseif current_speed==2 then
                    current_steer = steer_center + 5
                elseif current_speed==1 then
                    current_steer = steer_center + 10
                else
                    current_steer = steer_center + 15
                end
            else
                current_steer = steer_center + 20
            end
        end
        -- current steer in data-ready bit position
        current_steer = bit.lshift(current_steer, 4)



        data = 0
        if (running==1) then
            -- joystick 2 bt internal pullup, clicked LOW
            if gpio.read(joystick_2_bt)==0 and (tmr.now() - timer_last_speed_changed)>1000000 then --half second length to consider as double click
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
        elseif (running<0) then

            if current_speed==3 then
                data = 4 --0b100
            elseif current_speed==2 then
                data = 5 --0b101
            elseif current_speed==1 then -- from speed 0 or 1
                data = 6 --0b110
            else --speed = 0
                data = 7 -- 0b111
            end
            direction_adjust_timer:start()
        else -- no forward / backward (stop)
            data = 15 -- 0b1111
            current_speed = default_speed
            direction_adjust_timer:stop()
        end

        -- joystick 1 bt external pulldown, clicked HIGH
        if gpio.read(joystick_1_bt)==1 and (tmr.now() - timer_last_speed_changed)>1000000  then
            _G.timer_last_speed_changed = tmr.now()
            default_speed = default_speed + 1
            if default_speed>3 then
                default_speed = 0
            end
            --~ print("default speed updated " .. default_speed)
        end

        current_relay = data
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

    stop_checking_button = false
    starter = tmr.create()
    starter:register(3000, tmr.ALARM_SEMI, check_button)
    starter:start()
end
_G.initremote = function()
    gpio.mode(led,          gpio.OUTPUT)
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
