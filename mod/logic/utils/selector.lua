local M = {}

M.source = {
    CURSOR_HELD = "cursor_held",
    CURSOR_GHOST = "cursor_ghost",
    HOVERED_GHOST = "hovered_ghost",
    HOVERED = "hovered",
}

-- Do the best you can to figure out what item the player is indicating.
-- Returns a 2-tuple:
-- 1. Prototype name of the selected item (or nil if none)
-- 2. Source of the selection.
--    * "held" if selected item is an item stack held in the cursor
--    * "ghost" if selected item is a ghost in the cursor
--    * "hovered" if selected item is a real entity hovered on the surface
function M.player_selection(player)
    if player.cursor_stack and player.cursor_stack.valid_for_read then
        return player.cursor_stack.name, M.source.CURSOR_HELD
    elseif player.cursor_ghost then
        return player.cursor_ghost.name, M.source.CURSOR_GHOST
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

return M
