m = {}
m.ready = false
m.on_ready = function()
end
_G.v2_wifi_on_ready = function()
    lcd.logprint("wifi ready")
end

signal_logger = tmr.create()
signal_logger:register(config.wifi_signal_log_interval, tmr.ALARM_AUTO, function()
    lcd.logprint(""..wifi.sta.getrssi().." dB")
end)

check_ip_ready_starter = tmr.create()
check_ip_ready_starter:register(300, tmr.ALARM_SEMI, function()
    broadcast_ip = wifi.sta.getbroadcast()
    if not(broadcast_ip) then
        lcd.logprint("ip not ready")
        check_ip_ready_starter:start()
    else
        check_ip_ready_starter:unregister()
        lcd.logprint("ip ready")
        m.ready = true
        --~ m.on_ready()
        v2_wifi_on_ready()
        signal_logger:start()
    end
end)


wifi_connected_cb = function(ssid, bssid, channel)
    lcd.logprint("wifi connected")
    gpio.write(_G.config.led, 1)
    check_ip_ready_starter:start()
end
m.init = function()
    gpio.mode(_G.config.led,          gpio.OUTPUT)
    gpio.write(_G.config.led, 0)
    wifi.setmode(wifi.STATION)
    wifi.setphymode(wifi.PHYMODE_B)
    ssid = {}
    ssid.ssid = "ugvmakin"
    ssid.pwd = "astaughfirullah"
    ssid.auto = false
    ssid.save = false
    ssid.connected_cb = wifi_connected_cb
    ssid.stadisconnected_cb = function(ssid,bssid,channel)
        lcd.logprint("disconnected")
        _G.config.stop_checking_button = true
    end
    ssid.disconnected_cb = ssid.stadisconnected_cb 
    lcd.logprint("connecting")
    wifi.sta.config(ssid)
    wifi.sta.connect(wifi_connected_cb)
end
return m
