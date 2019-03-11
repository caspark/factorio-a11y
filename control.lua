local Area = require("__stdlib__/stdlib/area/area")
local Entity = require("__stdlib__/stdlib/entity/entity")
local Event = require("__stdlib__/stdlib/event/event")
local table = require("__stdlib__/stdlib/utils/table")
local Game = require("__stdlib__/stdlib/game")
local Player = require("__stdlib__/stdlib/event/player").register_events()
local Position = require("__stdlib__/stdlib/area/position")

-- helper to quote a string in single quotes
function q(s)
    return "'" .. s .. "'"
end

function render_reach_grid(player)
    local last_player_pos = Game.get_or_set_data("reach_grid", player.index, "last_player_pos", false, {})
    if table.deep_compare(player.position, last_player_pos) then
        -- bail out to avoid rerendering when position has not changed
        return
    else
        -- update position to avoid unnecessary work next time
        last_player_pos.x = player.position.x
        last_player_pos.y = player.position.y
    end

    local color_grid_background = {r = 0, g = 0, b = 0, a = 0.4}
    local max_dist = player.reach_distance

    local area = Area.adjust({player.position, player.position}, {max_dist, max_dist})

    -- get a reference to the grid table, remove any existing drawings, then save new drawings in it
    local ui_ids = Game.get_or_set_data("reach_grid", player.index, "ui_ids", false, {})
    for k, ui_id in pairs(ui_ids) do
        rendering.destroy(ui_id)
        ui_ids[k] = nil
    end

    -- draw the grid
    ui_ids[#ui_ids + 1] =
        rendering.draw_rectangle {
        color = color_grid_background,
        filled = true,
        left_top = {area.left_top.x, area.left_top.y},
        right_bottom = {area.right_bottom.x, area.right_bottom.y},
        surface = player.surface,
        draw_on_ground = true
    }

    -- render actual range for comparison
    ui_ids[#ui_ids + 1] =
        rendering.draw_circle(
        {
            color = defines.color.green,
            radius = max_dist,
            width = 2,
            filled = false,
            target = player.position,
            target_offset = {0, 0},
            surface = player.surface,
            players = {player.index},
            visible = true,
            draw_on_ground = true
        }
    )
end

-- it'd be nice to use on_player_changed_position, but that only fires when the player has
-- moved onto a discrete new tile
Event.register(
    defines.events.on_tick,
    function(event)
        for _, p in pairs(game.players) do
            render_reach_grid(p)
        end
    end
)

-- get an item from inventory by name
function grab(item_name)
    local ok, stack =
        pcall(
        function()
            return game.player.get_main_inventory().find_item_stack(item_name)
        end
    )
    if ok and stack then
        local stack_count = stack.count
        game.player.clean_cursor()
        if game.player.cursor_stack.transfer_stack(stack) then
            game.player.print("Grabbed " .. stack_count .. " of " .. q(item_name) .. "")
        else
            game.player.print("We have " .. stack_count .. " of " .. q(item_name) " but couldn't grab it :(")
        end
    else
        game.player.print("No " .. q(item_name) .. " found in inventory")
    end
end

-- being crafting a given item for a given count
function start_crafting(opts)
    setmetatable(opts, {__index = {count = 5}})
    local item_name = opts.item_name
    local count_asked = opts.count

    local count_available = game.player.get_craftable_count(item_name)
    if count_available == 0 then
        game.player.print("Missing ingredients for crafting any " .. q(item_name))
    elseif count_available < count_asked then
        -- we can't craft them all, but craft as many as we can
        local count_crafting = game.player.begin_crafting {recipe = item_name, count = count_available}
        game.player.print("Crafting " .. count_available .. " (not " .. count_asked .. ") of " .. q(item_name))
    else
        game.player.begin_crafting {recipe = item_name, count = count_asked}
    end
end

function what_is_this()
    if game.player.cursor_stack and game.player.cursor_stack.valid_for_read then
        game.player.print("That is " .. q(game.player.cursor_stack.name) .. " (cursor stack)")
    elseif game.player.selected then
        game.player.print("That is " .. q(game.player.selected.name) .. " (selected)")
    else
        game.player.print("No idea what that is :(")
    end
end

-- mine the item under the cursor instantly
-- (would be nice to do a regular mining action but doesn't seem possible
-- without locking cursor into place and hold right click, which is very
-- annoying when using eye tracking!)
function mine_selection()
    local target = game.player.selected
    if not target then
        game.player.print("No cursor selection to mine!")
        return
    end
    local target_name = target.prototype.name
    if not game.player.can_reach_entity(target) then
        game.player.print("That " .. q(target_name) .. " is too far away to mine!")
        return
    end
    if game.player.mine_entity(target) then
        game.player.print("Mined a " .. q(target_name))
    end
end

-- mine the tile which the player is standing on
function mine_tile_at_player()
    local to_mine = game.player.surface.get_tile(game.player.position)
    if to_mine then
        local to_mine_name = to_mine.prototype.name
        if game.player.mine_tile(to_mine) then
            game.player.print("Mined a " .. to_mine_name)
        end
    else
        game.player.print("Not standing on a tile!")
    end
end
