-- Accessibility functions to deal with managing inventories (primarily the player's).

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

-- print out how many items of a given type are in inventory and craftable
function M.count_item(player, item_name)
    local count_owned = player.get_item_count(item_name)
    local count_craftable = player.get_craftable_count(item_name)
    local msg = count_owned .. " of " .. q(item_name)
    msg = msg .. " in inventory (additional " .. count_craftable .. " craftable)"
    player.print(msg)
end

return M
