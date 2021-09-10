lcd = dofile('lcd.lua')

looper = tmr.create()
looper:register(500, tmr.ALARM_AUTO, function()
    lcd.cls()
    lcd.lcdprint("rssi: ",1,0)
    lcd.lcdprint(tostring(wifi.sta.getrssi()))
end)

function wifi_connected_cb()
    lcd.cls()
    lcd.lcdprint("connected!",1,0)
    looper:start()
end

function wifi_disconnected_cb(ssid,bssid,channel)
    print("disconnected")
    lcd.cls()
    lcd.lcdprint("disconnected!",1,0)
    looper:stop()
end

function main()
    lcd.cls()
    wifi.setmode(wifi.STATION)
    wifi.setphymode(wifi.PHYMODE_B)
    ssid = {}
    ssid.ssid = "ugvmakin"
    ssid.pwd = "astaughfirullah"
    ssid.auto = false
    ssid.save = false
    ssid.stadisconnected_cb = wifi_disconnected_cb
    wifi.sta.config(ssid)
    
    lcd.cls()
    lcd.lcdprint("connecting...", 1,0)
    
    wifi.sta.connect(wifi_connected_cb)
end

main()
