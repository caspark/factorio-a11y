-- factorio stdlib
local Event = require("__stdlib__/stdlib/event/event")
local Table = require("__stdlib__/stdlib/utils/table")

-- our lua
local Inventory = require("__A11y__/logic/modules/inventory")
local Mine = require("__A11y__/logic/modules/mine")
local Refuel = require("__A11y__/logic/modules/refuel")
local Run = require("__A11y__/logic/modules/run")
local Command_UI = require("__A11y__/logic/command_ui")

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

-- ============== On Tick event ==============
-- For efficiency and clarity of control flow, we register only one on-tick handler.

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

-- ============== Event handlers ==============
-- Register all event handlers in one place to keep control flow clear.

Mine.register_event_handlers()
Refuel.register_event_handlers()
Run.register_event_handlers()
Command_UI.register_event_handlers()

-- Hotkeys
local hotkey_actions = {
    ["hotkey-command-window-hide"] = Command_UI.hide_command_window,
    ["hotkey-command-window-show"] = Command_UI.show_command_window,
    ["hotkey-explain-selection"] = Inventory.explain_selection,
    ["hotkey-get-runtool"] = Run.grab_runtool,
    ["hotkey-mine-closest-building"] = Mine.mine_closest_building,
    ["hotkey-mine-closest-resouce"] = Mine.mine_closest_resource,
    ["hotkey-mine-selection"] = Mine.mine_selection,
    ["hotkey-mine-tile-under-player"] = Mine.mine_tile_under_player,
    ["hotkey-refuel-closest"] = Refuel.refuel_closest,
    ["hotkey-refuel-everything"] = Refuel.refuel_everything,
    ["hotkey-refuel-selection"] = Refuel.refuel_selection
}
Event.register(
    Table.keys(hotkey_actions),
    function(event)
        hotkey_actions[event.input_name](game.players[event.player_index])
    end
)
