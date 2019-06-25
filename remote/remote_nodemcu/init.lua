-- remote nodemcu
function startup()
    if file.open("init.lua") == nil then
        print("init.lua deleted or renamed")
    else
        print("Running")
        file.close("init.lua")
        -- the actual application is stored in 'application.lua'
        dofile("appremote.lua")
    end
end
--~ uart.on("data")
tmr.delay(2000000)
startup()
