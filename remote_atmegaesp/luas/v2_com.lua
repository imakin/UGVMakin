-- for communication, singleton
-- must offer method:
-- get() the communication object, singleton
-- send
m = {}
ready = false
m.init = function()
    if _G.com_net==nil then
        lcd.logprint("UDP make new")
        _G.com_net = net.createUDPSocket()
        _G.com_net:on("receive", function(s,d,p,i)
            if d=="ack" then
                ready = true
                gpio.write(config.led, 0)
                lcd.logprint("car ACK")
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
