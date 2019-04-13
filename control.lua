-- factorio stdlib
local Event = require("__stdlib__/stdlib/event/event")
local Table = require("__stdlib__/stdlib/utils/table")

-- our lua
local Mine = require("__A11y__/logic/modules/mine")
local Refuel = require("__A11y__/logic/modules/refuel")
local Run = require("__A11y__/logic/modules/run")
local Command_UI = require("__A11y__/logic/command_ui")
local Hotkey_Handlers = require("__A11y__/logic/hotkey_handlers")

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

-- ============== Event handlers ==============
-- Register all event handlers in one place to keep control flow clear.

Mine.register_event_handlers()
Refuel.register_event_handlers()
Run.register_event_handlers()
Command_UI.register_event_handlers()
Hotkey_Handlers.register_event_handlers()
