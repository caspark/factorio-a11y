local Game = require("__stdlib__/stdlib/game")

local M = {}

-- M.source.CURSOR_HELD if item was an item stack held in the cursor
-- M.source.CURSOR_GHOST if item was a ghost in the cursor
-- M.source.HOVERED_GHOST if item was a ghost hovered on the surface
-- M.source.HOVERED if item was a real entity hovered on the surface
M.source = {
    CURSOR_HELD = "cursor_held",
    CURSOR_GHOST = "cursor_ghost",
    HOVERED_GHOST = "hovered_ghost",
    HOVERED = "hovered",
}

-- Indicates the item held in the player's cursor.
-- Returns a 2-tuple:
-- 1. Prototype name of the selected item (or nil if none)
-- 2. Source of the selection, as one of the values in `M.source`
function M.player_held(player)
    if player.cursor_stack and player.cursor_stack.valid_for_read then
        return player.cursor_stack.name, M.source.CURSOR_HELD
    elseif player.cursor_ghost then
        return player.cursor_ghost.name, M.source.CURSOR_GHOST
    else
        return nil, nil
    end
end

-- Do the best you can to figure out what item the player is indicating.
-- Returns a 2-tuple:
-- 1. Prototype name of the selected item (or nil if none)
-- 2. Source of the selection, as one of the values in `M.source`
function M.player_selection(player)
    local held_item, held_source = M.player_held(player)
    if held_item then
        return held_item, held_source
    elseif player.selected then
        if player.selected.name == "entity-ghost" then
            return player.selected.ghost_name, M.source.HOVERED_GHOST
        else
            return player.selected.name, M.source.HOVERED
        end
    else
        return nil, nil
    end
end

-- Store the currently held item for later restoring (if there is one), then clean the cursor.
-- Returns the result of cleaning the cursor.
function M.save_held_item(player)
    local held_item_name, held_source = M.player_held(player)
    Game.get_or_set_data("selector", player.index, "held_item", true,
                         {item_name = held_item_name, source = held_source})
    return player.clean_cursor()
end

-- Restore the held item into the cursor (assuming it was previously saved with `save_held_item`).
-- If no item was previously saved, do nothing.
-- If a previously held item can now no longer be held (e.g. logistics robots have taken the
-- final stack from inventory), then the ghost of the item will be held instead.
function M.restore_held_item(player)
    local held = Game.get_or_set_data("selector", player.index, "held_item", true, nil)
    if held ~= nil then
        -- first empty out the cursor, since it may be holding something already
        player.clean_cursor()
        if held.source == M.source.CURSOR_HELD then
            local ok, stack = pcall(function()
                return player.get_main_inventory().find_item_stack(held.item_name)
            end)
            if ok and stack then
                -- then try to pick up what we were holding before, but if it doesn't work then don't worry about it
                player.cursor_stack.transfer_stack(stack)
            else
                player.cursor_ghost = held.item_name
            end
        elseif held.source == M.source.CURSOR_GHOST then
            player.cursor_ghost = held.item_name
        end
    end
end

return M
