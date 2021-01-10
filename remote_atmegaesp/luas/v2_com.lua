-- for communication, singleton
-- must offer method:
-- get() the communication object, singleton
-- send
m = {}
m.ack_info = ""
_G.ack_info = ""
ready = false
m.init = function()
    if _G.com_net==nil then
        lcd.logprint("UDP make new")
        _G.com_net = net.createUDPSocket()
        _G.com_net:on("receive", function(s,d,p,i)
            m.ack_info = d
            _G.ack_info = d
            if d:match("ack")=="ack" then
                ready = true
                gpio.write(config.led, 0)
                lcd.logprint("carACK"..d)
            end
            print(d)
        end)
        com_net:send(config.car_net_port, config.broadcast_ip, "test")
    end
end
m.send = function(data)
    if (ready) then
        if DEBUG then
            lcd.logprint("s:"..data)
        end
        com_net:send(config.car_net_port, config.broadcast_ip, data)
    end
end
return m
