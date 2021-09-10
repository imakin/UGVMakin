_G.config = dofile('v2_config.lua')
_G.lcd = dofile('lcd.lua')
_G.connection = dofile('v2_wifi.lua')
_G.com = dofile("v2_com.lua")
listen_button_loop = tmr.create()
last_data = 0
_G.timer_last_sending = tmr.now()
_G.current_steer = config.steer_center
make_steer_data = function(steer, relay)
    -- current steer in data-ready bit position
    steer = bit.lshift(steer,4)
    relay = bit.band(relay,config.data_mask)
    relay = relay+steer
    return relay
end
listen_button_step = function()
    if (gpio.read(config.bt_left)==0) then
        _G.current_steer = current_steer + 1
    else
        if (gpio.read(config.bt_right)==0) then
            _G.current_steer = current_steer - 1
        end
    end
    lcd.lcdprint(lcd.makeline(">"..current_steer),2,0)
    print("nah" .. current_steer)
    data = 15 -- 0b1111

    _G.data = make_steer_data(current_steer,data)
    print("nah2 "..data)
    com.send(tostring(data))
    
end

button_loop_interval = 500
listen_button_loop:register(button_loop_interval, tmr.ALARM_AUTO, listen_button_step)

lcd.logprint("start remote app")
_G.v2_wifi_on_ready = function()
    lcd.logprint("wifi ready ovr")
    com.init()
    listen_button_loop:start()
end
connection.init()
