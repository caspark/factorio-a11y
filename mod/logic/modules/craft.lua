local Selector = require("__A11y__/logic/utils/selector")

local M = {}

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
    local item_name, _source = Selector.player_selection(player)
    if item_name then
        M.craft_item(player, item_name, item_count)
    else
        player.print("No idea what that is so can't craft it")
    end
end

return M
