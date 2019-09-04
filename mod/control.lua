-- factorio stdlib
local Event = require("__stdlib__/stdlib/event/event")
local Table = require("__stdlib__/stdlib/utils/table")

-- our lua
local Commands = require("__A11y__/logic/modules/commands")
local Craft = require("__A11y__/logic/modules/craft")
local Dump = require("__A11y__/logic/modules/dump")
local Inventory = require("__A11y__/logic/modules/inventory")
local Mine = require("__A11y__/logic/modules/mine")
local Refuel = require("__A11y__/logic/modules/refuel")
local Run = require("__A11y__/logic/modules/run")

-- ============== Global helpers ==============

Logger = require("__stdlib__/stdlib/misc/logger").new("A11y_Debug", true, {log_ticks = true})

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

Event.register(defines.events.on_tick, function(_event)
    for _, player in pairs(game.players) do
        -- do any game state updates first to avoid UI being out of date
        Run.try_move_player_along_path(player)

        -- then render the UI
        Mine.render_ui(player)
        Refuel.render_ui(player)
        Run.render_ui(player)
    end
end)

-- ============== Event handlers ==============
-- Register all event handlers in one place to keep control flow clear.

Inventory.register_event_handlers()
Mine.register_event_handlers()
Refuel.register_event_handlers()
Run.register_event_handlers()
Commands.register_event_handlers()

-- Hotkeys
-- These could be registered in each module directly but explicitly listing them here
-- serves two purposes:
-- 1. it matches the prototype definition more nicely
-- 2. it makes it easy to ensure that each hotkey is properly documented in the readme
local hotkey_actions = {
    ["hotkey-command-window-hide"] = Commands.hide_command_window,
    ["hotkey-command-window-show"] = Commands.show_command_window,
    ["hotkey-explain-selection"] = Inventory.explain_selection,
    ["hotkey-get-runtool"] = Run.grab_runtool,
    ["hotkey-mine-closest-building"] = Mine.mine_closest_building,
    ["hotkey-mine-closest-resouce"] = Mine.mine_closest_resource,
    ["hotkey-mine-selection"] = Mine.mine_selection,
    ["hotkey-mine-tile-under-player"] = Mine.mine_tile_under_player,
    ["hotkey-refuel-closest"] = Refuel.refuel_closest,
    ["hotkey-refuel-everything"] = Refuel.refuel_everything,
    ["hotkey-refuel-selection"] = Refuel.refuel_selection,
}
Event.register(Table.keys(hotkey_actions), function(event)
    hotkey_actions[event.input_name](game.players[event.player_index])
end)

-- ============== Command-based input ==============
-- A11y provides functions intended to be invoked directly by the player.
-- Providing support for functions which take inputs means that we can support far more
-- flexible forms of input than if we were just using hotkeys, because we can take
-- arguments directly from the player as well.
--
-- There are two means to invoke a command:
--
-- The first is using the console directly,
-- using syntax like (e.g.) `/sc __A11y__ a11y_api.grab(game.player, 'small-electric-pole')`.
-- This is mainly useful for debugging; it's annoying to use for actual gameplay because
-- the commands are longer (causing higher latency due to more text having to be typed)
-- and the console scrollback flashes visible while text is being typed, which is
-- distracting.
--
-- The second is using the UI provided by the Commands module, using JSON array syntax
-- like e.g. `["grab", "small-electric-pole"]`. This is the mechanism intended to be used
-- during gameplay.

a11y_api = {
    count_item = Inventory.count_item,
    grab = Inventory.grab,
    vacuum = Inventory.vacuum,
    craft_item = Craft.craft_item,
    craft_selection = Craft.craft_selection,
    dump_data = Dump.dump_data,
}
Commands.register_commands(a11y_api)
