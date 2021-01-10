_G.config = dofile('v2_config.lua')
_G.lcd = dofile('lcd.lua')
_G.connection = dofile('v2_wifi.lua')
_G.com = dofile("v2_com.lua")
listen_button_loop = tmr.create()
last_data = 0
_G.timer_last_sending = tmr.now()

make_steer_data = function(steer, relay)
    -- current steer in data-ready bit position
    steer = bit.lshift(steer,4)
    relay = bit.band(relay,config.data_mask)
    relay = relay+steer
    return relay
end
if config.steer_distance>0 then
    steer_max = config.steer_center + config.steer_distance
    steer_min = config.steer_center - config.steer_distance
else
    steer_max = config.steer_center - config.steer_distance
    steer_min = config.steer_center + config.steer_distance
end
steer_min = config.steer_center - config.steer_distance
listen_button_step = function()
    if (gpio.read(config.bt_left)==0) then
        -- aslinya cuma current_steer = config.steer_center + config.steer_distance
        -- kalau config.steer_distance positive current steer bertambah
        -- kalau config.steer_distance negative current steer berkurang
        if (config.steer_distance>0) then
            if (current_steer<steer_max) then
                -- config.steer_distance positive
                -- tombol kiri dipencet, ekspektasi steer++ selama kurang dr steer_max
                current_steer = current_steer + 1
            end
        else
            if (current_steer>steer_min) then
                -- config.steer_distance negative
                -- tombol kiri dipencet, ekspektasi steer-- selama lebih dr steer_min
                current_steer = current_steer - 1
            end
        end
    elseif (gpio.read(config.bt_right)==0) then
        -- aslinya cuma current_steer = config.steer_center - config.steer_distance
        -- kalau config.steer_distance positive current steer berkurang
        -- kalau config.steer_distance negative current steer bertambah
        if config.steer_distance<0 then
            if currrent_steer<steer_max then
                current_steer = current_steer + 1
            end
        else
            if current_steer>steer_min then
                current_steer = current_steer - 1
            end
        end
    else
        current_steer = config.steer_center
    end


    --forward direction
    if (gpio.read(config.bt_forward)==0) then
        --direction_adjust_timer:start()
        data = 2 --0010 4WDH
    --backward
    elseif (gpio.read(config.bt_backward)==0) then
        data = 1 --0001
        --direction_adjust_timer:start()
    else -- no forward / backward (stop)
        data = 15 -- 0b1111
        --direction_adjust_timer:stop()
    end

    _G.data = make_steer_data(current_steer,data)
    if (
        (not (data==last_data)) or
        ((tmr.now() - _G.timer_last_sending) > config.timer_last_sending_limit)
    )then
        last_data = data
        _G.timer_last_sending = tmr.now()
        com.send(tostring(data))
    end
end

button_loop_interval = config.timer_last_sending_limit / 4000
listen_button_loop:register(button_loop_interval, tmr.ALARM_AUTO, listen_button_step)

lcd.logprint("start remote app")
_G.v2_wifi_on_ready = function()
    lcd.logprint("wifi ready ovr")
    com.init()
    listen_button_loop:start()
end
connection.init()
