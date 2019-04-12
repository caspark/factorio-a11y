-- seemingly undocumented factorio mod gui
local mod_gui = require("mod-gui") -- docs are in data/core/lualib/mod-gui.lua

-- factorio stdlib
local Event = require("__stdlib__/stdlib/event/event")
local Table = require("__stdlib__/stdlib/utils/table")

-- other libraries
local Json = require("logic/vendor/json")

-- our lua
local Refuel = require("logic/refuel")
local Mine = require("logic/mine")
local Run = require("logic/run")
local Selection = require("logic/selection")

-- ============== Global helpers ==============

Logger = require("__stdlib__/stdlib/misc/logger").new("A11y", "A11y_Debug", true, {log_ticks = true})

-- global helper function to quote a string in single quotes
function q(s)
    return "'" .. s .. "'"
end

-- global helper to turn a list of strings into a single string,
-- joined by commas & surrounded by quotes
function q_list(list_of_s)
    return (", "):join(Table.map(list_of_s, q))
end

-- ============== Console-based API ==============
--
-- The functions in this section are intended to be called from the console directly,
-- using syntax like (e.g.) `/sc __A11y__ grab(game.player, 'small-electric-pole')`.
--
-- It'd be nice to come up with a non-console based input for these, as using the
-- causes a flash of text due to all its scrollback being made visible. Maybe we can
-- create our own console-lite? Unfortunately hotkeys won't easily work here because
-- we need to receive actual text (e.g. the names of items).

a11y_api = {}

-- get an item from inventory by name
function a11y_api.grab(player, item_name)
    local ok, stack =
        pcall(
        function()
            return player.get_main_inventory().find_item_stack(item_name)
        end
    )
    if ok and stack then
        local stack_count = stack.count
        player.clean_cursor()
        if player.cursor_stack.transfer_stack(stack) then
            player.print("Grabbed " .. stack_count .. " of " .. q(item_name) .. "")
        else
            player.print("We have " .. stack_count .. " of " .. q(item_name) " but couldn't grab it :(")
        end
    else
        player.print("No " .. q(item_name) .. " found in inventory")
    end
end

-- begin crafting a given item for a given count
function a11y_api.craft_item(player, item_name, item_count)
    local count_available = player.get_craftable_count(item_name)
    if count_available == 0 then
        player.print("Missing ingredients for crafting any " .. q(item_name))
    elseif count_available < item_count then
        -- we can't craft them all, but craft as many as we can
        local count_crafting = player.begin_crafting {recipe = item_name, count = count_available}
        player.print("Crafting " .. count_crafting .. " (not " .. item_count .. ") of " .. q(item_name))
    else
        player.begin_crafting {recipe = item_name, count = item_count}
    end
end

-- begin crafting either the held or hovered item for a given count
function a11y_api.craft_selection(player, item_count)
    local item_name, _source = Selection.player_selection(player)
    if item_name then
        a11y_api.craft_item(player, item_name, item_count)
    else
        player.print("No idea what that is so can't craft it")
    end
end

-- print out how many items of a given type are in inventory and craftable
function a11y_api.count_item(player, item_name)
    local count_owned = player.get_item_count(item_name)
    local count_craftable = player.get_craftable_count(item_name)
    local msg = count_owned .. " of " .. q(item_name)
    msg = msg .. " in inventory (additional " .. count_craftable .. " craftable)"
    player.print(msg)
end

-- ============== Console replacement ==============
-- A replacement for the console to work around the flashing of console
-- scrollback. Relies on inputs ending with a newline.
-- Inputs should be a json array, with first element being the name of
-- the command and subsequent elements being the args.
-- For example:
--   ["grab", "copper-plate"]

local function get_a11y_command_textfield(player)
    local button_flow = mod_gui.get_button_flow(player)
    local flow = button_flow.a11y_flow
    if not flow then
        flow =
            button_flow.add {
            type = "flow",
            name = "a11y_flow",
            direction = "horizontal"
        }
    end
    if not flow.a11y_command_textfield then
        local text_field = flow.add {type = "text-box", name = "a11y_command_textfield"}
        text_field.visible = false
    end
    return flow.a11y_command_textfield
end

local function show_command_window(player)
    local text_field = get_a11y_command_textfield(player)
    text_field.visible = true
    text_field.text = "A11y JSON command goes here"
    text_field.focus()
    text_field.select_all()
end

local function hide_command_window(player)
    local text_field = get_a11y_command_textfield(player)
    text_field.visible = false
    text_field.text = "" -- maybe save a bit of memory if it was a big command
end

local function dispatch_command(player, command_and_args)
    local command = command_and_args[1]
    local args = command_and_args
    Logger.log("Dispatching command " .. q(command) .. " with args of: " .. serpent.block(args))

    args[1] = player -- all functions need player as their first arg so add it
    local ok, output_or_error =
        pcall(
        function()
            return a11y_api[command](table.unpack(args))
        end
    )
    if not ok then
        table.remove(args, 1) -- remove player from args because we added it
        local msg = "A11y command failed. Command was:\n"
        msg = msg .. q(command) .. " with/ args of " .. serpent.block(args)
        msg = msg .. "\nError was:\n" .. output_or_error
        player.print(msg)
    end
end

local function handle_json_command(player, json)
    local ok, command_or_error =
        pcall(
        function()
            return Json.decode(json)
        end
    )
    if ok and command_or_error then
        dispatch_command(player, command_or_error)
    else
        player.print("Failed to parse JSON command; json was:\n" .. json .. "\nand error was:\n" .. command_or_error)
    end
end

Event.register(
    defines.events.on_gui_text_changed,
    function(event)
        local element = event.element
        if element.name ~= "a11y_command_textfield" then
            return
        end

        if string.sub(element.text, -1) ~= "\n" then
            return
        end
        local command = element.text:sub(1, -2) -- remove trailing newline

        local player = game.players[event.player_index]
        hide_command_window(player)
        handle_json_command(player, command)
    end
)

-- ============== On Tick event ==============
-- (for efficiency and clarity of control flow, we register only one on-tick handler)

Event.register(
    defines.events.on_tick,
    function(_event)
        for _, player in pairs(game.players) do
            -- do any game state updates first to avoid UI being out of date
            Run.try_move_player_along_path(player)

            -- then render the UI
            Mine.render_ui(player)
            Refuel.render_ui(player)
            Run.render_ui(player)
        end
    end
)

-- ============== Hooked events ==============

Event.register(
    {
        "a11y-hook-player-walked-up",
        "a11y-hook-player-walked-right",
        "a11y-hook-player-walked-down",
        "a11y-hook-player-walked-left"
    },
    function(event)
        Run.stop_moving_player_along_path(game.players[event.player_index])
    end
)

-- ============== Selection tool handling ==============

local function handle_run_tool(player, area, _is_alt_selection)
    local selected_entities = player.surface.find_entities(area)
    if #selected_entities > 0 then
        local target = selected_entities[1]
        player.print("Running to selected " .. q(target.name))
        Run.run_to_target(player, target)
    elseif player.selected ~= nil then
        local target = player.selected
        player.print("Running to highlighted " .. q(target.name))
        Run.run_to_target(player, target)
    else
        local target = area.left_top
        player.print("Running to position " .. target.x .. "," .. target.y)
        Run.run_to_target(player, target)
    end
end

Event.register(
    {
        defines.events.on_player_selected_area,
        defines.events.on_player_alt_selected_area
    },
    function(e)
        if e.item ~= "runtool" then
            return
        end
        local player = game.players[e.player_index]
        local is_alt_selection = e.name == defines.events.on_player_alt_selected_area
        handle_run_tool(player, e.area, is_alt_selection)
    end
)

-- ============== Hotkey handling ==============

-- print out the name of the held or selected item
local function hotkey_explain_selection(player)
    local item_name, source = Selection.player_selection(player)
    if source == Selection.source.CURSOR_HELD then
        player.print("Holding " .. q(item_name) .. " in cursor")
    elseif source == Selection.source.CURSOR_GHOST then
        player.print("Holding ghost of " .. q(item_name) .. " in cursor")
    elseif source == Selection.source.HOVERED_GHOST then
        player.print("Hovering over ghost of " .. q(item_name))
    elseif source == Selection.source.HOVERED then
        player.print("Hovering over " .. q(item_name))
    else
        player.print("No idea what that is :(")
    end
end

local function hotkey_grab_runtool(player)
    if player.clean_cursor() then
        player.cursor_stack.set_stack({name = "runtool"})
    end
end

-- mine the resource or tree closest to the player instantly
-- (again, would be nice to do a regular mining action but doesn't seem possible)
local function hotkey_mine_closest_resource(player)
    local target = Mine.get_closest_reachable_resource(player)
    if not target then
        player.print("No resource in range to mine!")
        return
    end
    local target_name = target.prototype.name
    if player.mine_entity(target) then
        player.print("Mined closest resource " .. q(target_name))
    end
end

local function hotkey_mine_closest_building(player)
    local target = Mine.get_closest_reachable_building(player)
    if not target then
        player.print("No building in range to mine!")
        return
    end
    local target_name = target.prototype.name
    if player.mine_entity(target) then
        player.print("Mined closest building " .. q(target_name))
    end
end

-- mine the item under the cursor instantly
-- (would be nice to do a regular mining action but doesn't seem possible
-- without locking cursor into place and hold right click, which is very
-- annoying when using eye tracking!)
local function hotkey_mine_selection(player)
    local target = player.selected
    if not target then
        player.print("No cursor selection to mine!")
        return
    end
    local target_name = target.prototype.name
    if not player.can_reach_entity(target) then
        player.print("That " .. q(target_name) .. " is too far away to mine!")
        return
    end
    if player.mine_entity(target) then
        player.print("Mined selected " .. q(target_name))
    end
end

-- mine the tile which the player is standing on
local function hotkey_mine_tile_under_player(player)
    local to_mine = player.surface.get_tile(player.position)
    if to_mine then
        local to_mine_name = to_mine.prototype.name
        if player.mine_tile(to_mine) then
            player.print("Mined a " .. to_mine_name)
        end
    else
        player.print("Not standing on a tile!")
    end
end

local function hotkey_refuel_closest(player)
    local target = Refuel.get_closest_refuelable_entity(player)
    if target then
        local error, stack = Refuel.refuel_target(player, target, 20)
        if error ~= nil then
            player.print(error)
        else
            player.print("Refueled closest " .. q(target.name) .. " with " .. stack.count .. " " .. q(stack.name))
        end
    else
        player.print("Nothing in reach which can be refueled!")
    end
end

local function hotkey_refuel_everything(player)
    local targets = Refuel.get_all_reachable_refuelable_entities(player)
    local targets_count = #targets
    if targets_count > 0 then
        local refueled_count = 0
        local fuel_used = {}
        local last_failure = nil
        for _, target in pairs(targets) do
            local error, stack = Refuel.refuel_target(player, target, 20)
            if error == nil then
                if fuel_used[stack.name] == nil then
                    fuel_used[stack.name] = stack.count
                else
                    fuel_used[stack.name] = fuel_used[stack.name] + stack.count
                end
                refueled_count = refueled_count + 1
            else
                last_failure = error
            end
        end
        if refueled_count == 0 then
            player.print("Failed to refuel anything; last failure reason was:\n" .. last_failure)
        else
            local fuel_used_descs = {}
            for fuel_name, count in pairs(fuel_used) do
                table.insert(fuel_used_descs, count .. " " .. fuel_name)
            end
            local fuel_used_msg = (", "):join(fuel_used_descs)
            if refueled_count == targets_count then
                player.print("Refueled all " .. targets_count .. " entities in reach using " .. fuel_used_msg)
            else
                local msg = "Refueled " .. refueled_count .. " of " .. targets_count .. " entities using "
                msg = msg .. fuel_used_msg .. "; last failure reason was:\n" .. last_failure
                player.print(msg)
            end
        end
    else
        player.print("Nothing in reach which can be refueled!")
    end
end

local function hotkey_refuel_selection(player)
    local target = player.selected
    if target then
        local error, stack = Refuel.refuel_target(player, target, 20)
        if error ~= nil then
            player.print(error)
        else
            player.print("Refueled hovered " .. q(target.name) .. " with " .. stack.count .. " " .. q(stack.name))
        end
    else
        player.print("No cursor selection to refuel!")
    end
end

local function hotkey_command_window_show(player)
    show_command_window(player)
end

local function hotkey_command_window_hide(player)
    hide_command_window(player)
end

local hotkey_actions = {
    ["hotkey-command-window-show"] = hotkey_command_window_show,
    ["hotkey-command-window-hide"] = hotkey_command_window_hide,
    ["hotkey-explain-selection"] = hotkey_explain_selection,
    ["hotkey-get-runtool"] = hotkey_grab_runtool,
    ["hotkey-mine-closest-building"] = hotkey_mine_closest_building,
    ["hotkey-mine-closest-resouce"] = hotkey_mine_closest_resource,
    ["hotkey-mine-selection"] = hotkey_mine_selection,
    ["hotkey-mine-tile-under-player"] = hotkey_mine_tile_under_player,
    ["hotkey-refuel-closest"] = hotkey_refuel_closest,
    ["hotkey-refuel-everything"] = hotkey_refuel_everything,
    ["hotkey-refuel-selection"] = hotkey_refuel_selection
}
Event.register(
    Table.keys(hotkey_actions),
    function(event)
        hotkey_actions[event.input_name](game.players[event.player_index])
    end
)
