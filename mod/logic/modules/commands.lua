-- This module provides a replacement for the console to work around the flashing of console
-- scrollback.
-- Inputs should be a json array, with first element being the name of
-- the command and subsequent elements being the args.
-- For example:
--   ["grab", "copper-plate"]
-- Relies on inputs ending with a newline.

-- seemingly undocumented factorio mod gui
local mod_gui = require("mod-gui") -- docs are in data/core/lualib/mod-gui.lua

local Event = require("__stdlib__/stdlib/event/event")

local Json = require("__A11y__/logic/vendor/json")

local command_api = {}

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

local function dispatch_command(player, command_and_args)
    local command = command_and_args[1]
    local args = command_and_args
    if not command then
        player.print("Invalid A11y command:\n" .. serpent.block(command_and_args))
        return
    end

    Logger.log("Dispatching command " .. q(command) .. " with args of: " .. serpent.block(args))

    args[1] = player -- all functions need player as their first arg so add it
    local ok, output_or_error =
        pcall(
        function()
            return command_api[command](table.unpack(args))
        end
    )
    if not ok then
        table.remove(args, 1) -- remove player from args because we added it
        local msg = "A11y command failed. Command was:\n"
        msg = msg .. q(command) .. " with args of " .. serpent.block(args)
        msg = msg .. "\nError was:\n" .. output_or_error
        player.print(msg)
    end
end

local function parse_json_command(player, json)
    local ok, command_or_error =
        pcall(
        function()
            return Json.decode(json)
        end
    )
    if ok and command_or_error then
        return command_or_error -- return the parsed command
    else
        player.print("Failed to parse JSON command; json was:\n" .. json .. "\nand error was:\n" .. command_or_error)
    end
end

local M = {}

function M.show_command_window(player)
    local text_field = get_a11y_command_textfield(player)
    text_field.visible = true
    text_field.text = "A11y JSON command goes here"
    text_field.focus()
    text_field.select_all()
end

function M.hide_command_window(player)
    local text_field = get_a11y_command_textfield(player)
    text_field.visible = false
    text_field.text = "" -- maybe save a bit of memory if it was a big command
end

function M.register_commands(commands)
    for command, func in pairs(commands) do
        command_api[command] = func
    end
end

function M.register_event_handlers()
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
            local json_command = element.text:sub(1, -2) -- remove trailing newline

            local player = game.players[event.player_index]
            M.hide_command_window(player)
            parsed_command = parse_json_command(player, json_command)
            if parsed_command ~= nil then
                dispatch_command(player, parsed_command)
            end
        end
    )
end

return M
