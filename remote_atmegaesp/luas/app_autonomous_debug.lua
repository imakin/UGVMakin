
DEBUG = true -- i meant verbose
function log(text)
    if (DEBUG) then
        print(text)
    end
end

print("Autonomous debug mode")
lcd = dofile('lcd.lua')
led = 2
gpio.mode(led, gpio.OUTPUT)
loopers = {}
_G.udpsocket = nil
_G.CharMenu  = dofile('CharMenu.lua')
-- blink non blocking, but using pin 2
--param  n: how long blinking in seconds
function blink(n)
    blink_length = 250
    enough = n*4 -- n * 1000/blink_length
    loopers.blink = tmr.create()
    loopers.blink:register(blink_length, tmr.ALARM_SEMI, function(tmr_object)
        if (gpio.read(led)==1) then
            gpio.write(led,0)
        else 
            gpio.write(led,1)
        end
        if (enough>0) then
            enough = enough - 1
            loopers.blink:start()
        end
    end)
    loopers.blink:start()
end


loopers.rssi = tmr.create()
loopers.rssi:register(500, tmr.ALARM_AUTO, function()
    --~ lcd.cls()
    --~ lcd.lcdprint("rssi: ",1,0)
    --~ lcd.lcdprint(tostring(wifi.sta.getrssi()))
    CharMenu.display("rssi: "..tostring(wifi.sta.getrssi()),1,0)
end)

function wifi_connected_cb()
    lcd.cls()
    lcd.lcdprint("connected!",1,0)
    
    _G.udpsocket = net.createUDPSocket()
    _G.udpsocket:on("receive", function(s,d,p,i)
    end)
    --~ loopers.rssi:start()
end

function wifi_disconnected_cb(ssid,bssid,channel)
    print("disconnected")
    lcd.cls()
    lcd.lcdprint("disconnected!",1,0)
    loopers.rssi:stop()
end

function remote_control_start()
    loopers.rssi:start()
    remote = dofile("appremote_atmegaesp.lua")
    remote.run_remote()
end

function main()
    --~ lcd.cls()
    wifi.setmode(wifi.STATION)
    wifi.setphymode(wifi.PHYMODE_B)
    ssid = {}
    ssid.ssid = "ugvmakin"
    ssid.pwd = "astaughfirullah"
    ssid.auto = false
    ssid.save = false
    ssid.stadisconnected_cb = wifi_disconnected_cb
    wifi.sta.config(ssid)
    log(node.heap())
    menu_autonomous_driving = CharMenu.new_menu(CharMenu.menu_root, 'Autonomous Drive', nil)
    log(node.heap())
    CharMenu.new_menu(CharMenu.menu_root, 'R/C', remote_control_start, nil)
    log(node.heap())
    CharMenu.new_menu(CharMenu.menu_root, 'Menu lainnya', nil)
    log(node.heap())
    CharMenu.new_menu(menu_autonomous_driving, 'start', nil, function()
        --~ _G.udpsocket.send(5001, "192.168.4.2", "drive_on")
        _G.udpsocket:send(5001, "192.168.4.3", "drive_on")
    end)
    log(node.heap())
    CharMenu.new_menu(menu_autonomous_driving, 'stop', nil, function()
        --~ _G.udpsocket.send(5001, "192.168.4.2", "drive_off")
        _G.udpsocket:send(5001, "192.168.4.3", "drive_off")
    end)
    log(node.heap())
    
    CharMenu.start()
    log(node.heap())
    
    --~ lcd.cls()
    --~ lcd.lcdprint("connecting...", 1,0)
    
    wifi.sta.connect(wifi_connected_cb)
end

--startup blink
blink(5)
main()

