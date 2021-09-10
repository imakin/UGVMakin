if file.open("DEBUG.lua")==nil then
    _G.DEBUG = false
else
    _G.DEBUG = true
end
-- remote nodemcu
function startup_remote()
    if file.open("init.lua") == nil then
        print("init.lua deleted or renamed")
    else
        print("Running remote")
        file.close("init.lua")
        remote = dofile("v2_app.lua")
    end
end

tmr.delay(10000)
startup_remote()

