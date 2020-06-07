-- remote nodemcu
function startup()
    if file.open("init.lua") == nil then
        print("init.lua deleted or renamed")
    else
        print("Running")
        file.close("init.lua")
        dofile("appremote_atmegaesp.lua")
    end
end

tmr.delay(2000000)
startup()

