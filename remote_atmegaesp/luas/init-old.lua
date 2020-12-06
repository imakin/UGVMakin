-- remote nodemcu
function startup_remote()
    if file.open("init.lua") == nil then
        print("init.lua deleted or renamed")
    else
        print("Running remote")
        file.close("init.lua")
        remote = dofile("appremote_atmegaesp.lua")
        remote.init_remote()
    end
end

function startup_autonomous()
    if file.open("init.lua") == nil then
        print("init.lua deleted or renamed")
    else
        print("Running Autonomous debug")
        file.close("init.lua")
        dofile("app_mode_a.lua")
    end
end


tmr.delay(2000000)


--button init
bt_touch = 8
bt_right = 6
bt_left = 7
bt_forward = 5
bt_backward = 0
gpio.mode(bt_right,     gpio.INPUT, gpio.PULLUP)
gpio.mode(bt_left,      gpio.INPUT, gpio.PULLUP)
gpio.mode(bt_forward,   gpio.INPUT, gpio.PULLUP)
gpio.mode(bt_backward,  gpio.INPUT, gpio.PULLUP)
gpio.mode(bt_touch,     gpio.INPUT, gpio.PULLDOWN)


tmr.delay(10000)
print(gpio.read(bt_touch))
print(gpio.read(bt_forward))
--enter Autonomous debug mode if 2 axis buttons are pressed
mode_a = true

if (gpio.read(bt_touch)==1 or gpio.read(bt_right)==0 or gpio.read(bt_left)==0) then
    if (gpio.read(bt_touch)==1 or gpio.read(bt_forward)==0 or gpio.read(bt_backward)==0) then
        mode_a = false
        startup_autonomous()
    end
end
--need to check it as startup_autonomous has non blocking interval based loop
if (mode_a) then
    startup_remote()
end

