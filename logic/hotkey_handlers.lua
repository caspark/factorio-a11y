local Event = require("__stdlib__/stdlib/event/event")
local Table = require("__stdlib__/stdlib/utils/table")

local Refuel = require("__A11y__/logic/modules/refuel")
local Mine = require("__A11y__/logic/modules/mine")
local Run = require("__A11y__/logic/modules/run")
local Selection = require("__A11y__/logic/selection")
local CommandUI = require("__A11y__/logic/command_ui")

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

local hotkey_actions = {
    ["hotkey-command-window-hide"] = CommandUI.hide_command_window,
    ["hotkey-command-window-show"] = CommandUI.show_command_window,
    ["hotkey-explain-selection"] = hotkey_explain_selection,
    ["hotkey-get-runtool"] = Run.hotkey_grab_runtool,
    ["hotkey-mine-closest-building"] = hotkey_mine_closest_building,
    ["hotkey-mine-closest-resouce"] = hotkey_mine_closest_resource,
    ["hotkey-mine-selection"] = hotkey_mine_selection,
    ["hotkey-mine-tile-under-player"] = hotkey_mine_tile_under_player,
    ["hotkey-refuel-closest"] = hotkey_refuel_closest,
    ["hotkey-refuel-everything"] = hotkey_refuel_everything,
    ["hotkey-refuel-selection"] = hotkey_refuel_selection
}

local M = {}

function M.register_event_handlers()
    Event.register(
        Table.keys(hotkey_actions),
        function(event)
            hotkey_actions[event.input_name](game.players[event.player_index])
        end
    )
end

return M
