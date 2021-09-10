
function startup()
    if file.open("init.lua") == nil then
        print("init.lua deleted or renamed")
    else
        print("Running")
        file.close("init.lua")
        -- the actual application is stored in this file
        dofile("remote_test.lua")
    end
end

tmr.delay(2000000)
startup()

