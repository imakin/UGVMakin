CharMenu = {}
CharMenu.BUTTON_NEXT = 0
CharMenu.BUTTON_PREV = 1
CharMenu.BUTTON_ENTER = 2
CharMenu.BUTTON_BACK = 3
bt_right = 6 --(scroll right for next menu sibling)
bt_left = 7 --(scroll left for previous menu sibling)
bt_enter = 5 --(enter submenu or execute action)
bt_back = 0 --(back to parent menu or exit action)
CharMenu.lcd = nil
-- this will be called when framework loaded (by dofile('CharMenu.lua') )
-- this initialize buttons and displays
-- overwrite function if needed
CharMenu.init = function()
    CharMenu.lcd = dofile('lcd.lua')
    gpio.mode(bt_right,     gpio.INPUT, gpio.PULLUP)
    gpio.mode(bt_left,      gpio.INPUT, gpio.PULLUP)
    gpio.mode(bt_enter,   gpio.INPUT, gpio.PULLUP)
    gpio.mode(bt_back,  gpio.INPUT, gpio.PULLUP)
end

-- check_button function can be overwritten following your electronics condition (change pin, etc)
-- CharMenu Framework will call this function for checking button:
--  check_button(CharMenu.BUTTON_NEXT)
--  check_button(CharMenu.BUTTON_PREV)
--  check_button(CharMenu.BUTTON_ENTER)
--  check_button(CharMenu.BUTTON_BACK)
-- this is the default check button which use pin 
--~ bt_right = 6 (scroll right for next menu sibling)
--~ bt_left = 7 (scroll left for previous menu sibling)
--~ bt_enter = 5 (enter submenu or execute action)
--~ bt_back = 0 (back to parent menu or exit action)
CharMenu.check_button = function(which_button)
    local target_check = nil
    if (which_button==CharMenu.BUTTON_NEXT) then
        target_check = bt_right
    else
    if (which_button==CharMenu.BUTTON_PREV) then
        target_check = bt_left
    else
    if (which_button==CharMenu.BUTTON_ENTER) then
        target_check = bt_enter
    else
    if (which_button==CharMenu.BUTTON_BACK) then
        target_check = bt_back
    end end end end --nodemcu LUA doesn't support elseif nor if without end block
    
    if (gpio.read(target_check)==0) then
        return true
    end
    return false
end

-- this menu will be called when CharMenu Framework displaying menus.
-- can be overwritten to follow your condition
-- by default it will use lcd.lua
-- @param text: text to display, 16 charracter max
-- @param row: starts from 1, i.e value can be 1 or 2
-- @param column: start from 0
CharMenu.display = function(text, row, column)
    CharMenu.lcd.lcdprint(text, row, column)
end
-- this menu will be called when CharMenu Framework is going to clear display screen
-- can be overwritten to follow your condition
CharMenu.display_clear = function()
    CharMenu.lcd.cls()
end

-- create new menu, subsequently added to last index of parent's children
-- @param parent: add this new menu to parent, except if parent is nil
-- @param text: the text to display on LCD
-- @param action: the action to execute when this menu is selected
-- @param hover_action: the action to execute when menu cursor reach this (before this menu selected)
CharMenu.new_menu = function(parent, text, action, hover_action)
    menu = {}
    menu.text = text
    menu.next_sibling = menu
    menu.prev_sibling = menu
    menu.index_on_parent = 1
    menu.children = {}
    menu.action = action
    menu.hover_action = hover_action
    menu.parent = parent
    if (parent ~= nil) then
        local index_prev_sibling = #menu.parent.children
        menu.index_on_parent = #menu.parent.children + 1 -- fetch this menu position and save it, and (if length is 0) index starts from 1
        menu.parent.children[menu.index_on_parent] = menu
        if (index_prev_sibling ~= 0) then --attach prev/next of this menu and the previous sibling
            menu.prev_sibling = menu.parent.children[index_prev_sibling]
            menu.parent.children[index_prev_sibling].next_sibling = menu --overwrite next_sibling of previous menu to point to this menu
            menu.next_sibling = menu.parent.children[1] --point this menu next_sibling into the first sibling so that menu has infinite rotation
        end
    end
    return menu
end

CharMenu.menu_root = CharMenu.new_menu(nil, "/", nil)
CharMenu.looper = tmr.create()
--start the framework, must be called manually, but sub menu of menu_root must be registered first
CharMenu.start = function()
    CharMenu.current_menu = CharMenu.menu_root.children[1]
    CharMenu.current_menu_text = ""
    CharMenu.looper:register(100, tmr.ALARM_AUTO, function()
        pressed = false
        if (pressed==false and CharMenu.check_button(CharMenu.BUTTON_NEXT)) then
            CharMenu.current_menu = CharMenu.current_menu.next_sibling
            if (CharMenu.current_menu.hover_action ~= nil) then
                CharMenu.current_menu.hover_action()
            end
            pressed = true
        end
        if (pressed==false and CharMenu.check_button(CharMenu.BUTTON_PREV)) then
            CharMenu.current_menu = CharMenu.current_menu.prev_sibling
            if (CharMenu.current_menu.hover_action ~= nil) then
                CharMenu.current_menu.hover_action()
            end
            pressed = true
        end
        if (pressed==false and CharMenu.check_button(CharMenu.BUTTON_ENTER)) then
            if (CharMenu.current_menu.action ~= nil) then
                CharMenu.current_menu.action()
            end
            if (#CharMenu.current_menu.children > 0) then --submenu exist
                CharMenu.current_menu = CharMenu.current_menu.children[1] --enter submenu
            end
            pressed = true
        end
        if (pressed==false and CharMenu.check_button(CharMenu.BUTTON_BACK)) then
            if (CharMenu.current_menu.parent ~= nil) then
                CharMenu.current_menu = CharMenu.current_menu.parent
                if (CharMenu.current_menu.action ~= nil) then
                    CharMenu.current_menu.action()
                end
            end
            pressed = true
        end
        --~ if (pressed==false) then
        if (CharMenu.current_menu_text ~= CharMenu.current_menu.text) then
            CharMenu.current_menu_text = CharMenu.current_menu.text
            CharMenu.display_clear()
            CharMenu.display(CharMenu.current_menu.text, 1, 0)
            siblings_total = 1
            if (CharMenu.current_menu.parent ~= nil) then
                siblings_total = #CharMenu.current_menu.parent.children
            end
            position = ""..CharMenu.current_menu.index_on_parent.." / "..siblings_total
            CharMenu.display(position, 2, 0)
        end
        --~ end
    end)
    CharMenu.looper:start()
end
print("charmenu running")
CharMenu.init()
CharMenu.lcd.cls()
CharMenu.lcd.lcdprint('Bismillah',1,0)
return CharMenu
