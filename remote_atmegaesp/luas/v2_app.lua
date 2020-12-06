_G.config = dofile('v2_config.lua')
_G.lcd = dofile('lcd.lua')
_G.connection = dofile('v2_wifi.lua')
_G.com = dofile("v2_com.lua")
listen_button_loop = tmr.create()
last_data = 0
_G.timer_last_sending = tmr.now()

listen_button_step = function()
    if (gpio.read(config.bt_left)==0) then
        current_steer = config.steer_center + config.steer_distance
    elseif (gpio.read(config.bt_right)==0) then
        current_steer = config.steer_center - config.steer_distance
    else
        current_steer = config.steer_center
    end

    -- current steer in data-ready bit position
    current_steer = bit.lshift(current_steer, 4)

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

    data = bit.band(data, config.data_mask)
    data = data + current_steer
    _G.data = data
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
