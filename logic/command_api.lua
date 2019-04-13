-- This module provides functions intended to be invoked directly by the player.
-- Providing support for functions which take inputs means that we can support far more
-- flexible forms of input than if we were just using hotkeys, because we can take
-- arguments directly from the player as well.
--
-- There are two means to do so. The first is using the console directly,
-- using syntax like (e.g.) `/sc __A11y__ grab(game.player, 'small-electric-pole')`.
--
-- The second is using the UI provided in `__A11y__/logic/command_ui.lua`, e.g.
-- `["grab", "small-electric-pole"]`.

local Selection = require("__A11y__/logic/selection")

local M = {}

-- get an item from inventory by name
function M.grab(player, item_name)
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
function M.craft_item(player, item_name, item_count)
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
function M.craft_selection(player, item_count)
    local item_name, _source = Selection.player_selection(player)
    if item_name then
        M.craft_item(player, item_name, item_count)
    else
        player.print("No idea what that is so can't craft it")
    end
end

-- print out how many items of a given type are in inventory and craftable
function M.count_item(player, item_name)
    local count_owned = player.get_item_count(item_name)
    local count_craftable = player.get_craftable_count(item_name)
    local msg = count_owned .. " of " .. q(item_name)
    msg = msg .. " in inventory (additional " .. count_craftable .. " craftable)"
    player.print(msg)
end

return M
