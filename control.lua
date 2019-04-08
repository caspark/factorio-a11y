local Event = require("__stdlib__/stdlib/event/event")
local Table = require("__stdlib__/stdlib/utils/table")
local String = require("__stdlib__/stdlib/utils/string")

local Refuel = require("logic/refuel")
local Mine = require("logic/mine")
local Run = require("logic/run")

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

-- get an item from inventory by name
function grab(player, item_name)
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
function start_crafting(player, opts)
    setmetatable(opts, {__index = {count = 5}})
    local item_name = opts.item_name
    local count_asked = opts.count

    local count_available = player.get_craftable_count(item_name)
    if count_available == 0 then
        player.print("Missing ingredients for crafting any " .. q(item_name))
    elseif count_available < count_asked then
        -- we can't craft them all, but craft as many as we can
        local count_crafting = player.begin_crafting {recipe = item_name, count = count_available}
        player.print("Crafting " .. count_available .. " (not " .. count_asked .. ") of " .. q(item_name))
    else
        player.begin_crafting {recipe = item_name, count = count_asked}
    end
end

-- ============== On Tick event ==============
-- (for efficiency and clarity of control flow, we register only one on-tick handler)

Event.register(
    defines.events.on_tick,
    function(event)
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

function handle_run_tool(player, area, is_alt_selection)
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
        target = area.left_top
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
function hotkey_explain_selection(player)
    if player.cursor_stack and player.cursor_stack.valid_for_read then
        player.print("That is " .. q(player.cursor_stack.name) .. " (cursor stack)")
    elseif player.selected then
        player.print("That is " .. q(player.selected.name) .. " (selected)")
    else
        player.print("No idea what that is :(")
    end
end

function hotkey_grab_runtool(player)
    if player.clean_cursor() then
        player.cursor_stack.set_stack({name = "runtool"})
    end
end

-- mine the resource or tree closest to the player instantly
-- (again, would be nice to do a regular mining action but doesn't seem possible)
function hotkey_mine_closest_resource(player)
    local target = Mine.get_closest_reachable_resource(player)
    if not target then
        player.print("No resource in range to mine!")
        return
    end
    local target_name = target.prototype.name
    if player.mine_entity(target) then
        player.print("Mined closest " .. q(target_name))
    end
end

-- mine the item under the cursor instantly
-- (would be nice to do a regular mining action but doesn't seem possible
-- without locking cursor into place and hold right click, which is very
-- annoying when using eye tracking!)
function hotkey_mine_selection(player)
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
function hotkey_mine_tile_under_player(player)
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

function hotkey_refuel_closest(player)
    local target = Refuel.get_closest_refuelable_entity(player)
    if target then
        Refuel.refuel_target(player, target)
    else
        player.print("Nothing in reach which can be refueled!")
    end
end

function hotkey_refuel_selection(player)
    local target = player.selected
    if target then
        Refuel.refuel_target(player, target)
    else
        player.print("No cursor selection to refuel!")
    end
end

local hotkey_actions = {
    ["hotkey-explain-selection"] = hotkey_explain_selection,
    ["hotkey-get-runtool"] = hotkey_grab_runtool,
    ["hotkey-mine-closest-resouce"] = hotkey_mine_closest_resource,
    ["hotkey-mine-selection"] = hotkey_mine_selection,
    ["hotkey-mine-tile-under-player"] = hotkey_mine_tile_under_player,
    ["hotkey-refuel-closest"] = hotkey_refuel_closest,
    ["hotkey-refuel-selection"] = hotkey_refuel_selection
}
Event.register(
    Table.keys(hotkey_actions),
    function(event)
        hotkey_actions[event.input_name](game.players[event.player_index])
    end
)
