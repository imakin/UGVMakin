
function startup()
    if file.open("init.lua") == nil then
        print("init.lua deleted or renamed")
    else
        print("Running")
        file.close("init.lua")
        -- the actual application is stored in 'application.lua'
        dofile("app.lua")
    end
end
--~ uart.on("data")
motorApwm = 4
motorBpwm = 5

gpio.mode(motorApwm, gpio.OUTPUT)
gpio.mode(motorBpwm, gpio.OUTPUT)
gpio.write(motorApwm, 0)
gpio.write(motorBpwm, 0)

tmr.delay(2000000)
startup()
