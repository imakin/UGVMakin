
function startup()
    if file.open("init.lua") == nil then
        print("init.lua deleted or renamed")
    else
        print("Running")
        file.close("init.lua")
        -- the actual application is stored in 'application.lua'
        dofile("apprelay.lua")
    end
end
--~ uart.on("data")
gpio.mode(3, gpio.OUTPUT)
gpio.mode(4, gpio.OUTPUT)
gpio.write(3, 1)
gpio.write(4, 1)

tmr.delay(2000000)
startup()
