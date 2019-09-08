require('__stdlib__/stdlib/utils/defines/color')
local Area = require("__stdlib__/stdlib/area/area")
local Event = require("__stdlib__/stdlib/event/event")
local Game = require("__stdlib__/stdlib/game")
local Memoize = require("__stdlib__/stdlib/vendor/memoize")
local Position = require("__stdlib__/stdlib/area/position")
local Table = require("__stdlib__/stdlib/utils/table")

local function get_closest_reachable_ghost(player)
    local ghost_entities = player.surface.find_entities_filtered{
        position = player.position,
        radius = player.reach_distance,
        name = 'entity-ghost',
        force = player.force,
    }

    local closest_ghost = nil
    local closest_dist = math.huge
    if ghost_entities then
        for _, res in pairs(ghost_entities) do
            local d = Position.distance_squared(player.position, res.position)
            if d < closest_dist then
                closest_dist = d
                closest_ghost = res
            end
        end
    end
    return closest_ghost
end

local M = {}

function M.labor(player)
    Game.get_or_set_data("labor", player.index, "guide_ui_handles", false, nil)

    local target = get_closest_reachable_ghost(player)

    if target then
        player.print("selected target of " .. serpent.block(target))
    end
end

function M.render_ui(player)
    local ui_last_player_pos = Game.get_or_set_data("labor", player.index, "last_player_pos", false,
                                                    {x = nil, y = nil})
    local ui_force_rerender = Game.get_or_set_data("labor", player.index, "force_rerender", false,
                                                   false)
    if player.position.x == ui_last_player_pos.x and player.position.y == ui_last_player_pos.y
        and not ui_force_rerender then
        -- bail out to avoid rerendering when position has not changed
        return
    else
        -- update position to avoid unnecessary work next time
        ui_last_player_pos.x = player.position.x
        ui_last_player_pos.y = player.position.y
        -- and flush rerender flag
        Game.get_or_set_data("labor", player.index, "force_rerender", true, false)
    end

    local closest_reachable_ghost = get_closest_reachable_ghost(player)

    -- get a reference to the grid table, remove any existing drawings, then save new drawings in it
    local ui_ids = Game.get_or_set_data("labor", player.index, "ui_ids", false, {})
    for k, ui_id in pairs(ui_ids) do
        rendering.destroy(ui_id)
        ui_ids[k] = nil
    end

    if closest_reachable_ghost then
        ui_ids[#ui_ids + 1] = rendering.draw_circle(
                                  {
                color = defines.color.white,
                radius = 0.5,
                width = 2,
                filled = false,
                target = closest_reachable_ghost,
                surface = player.surface,
                time_to_live = 60 * 60,
                players = {player.index},
                draw_on_ground = true,
            })
    end
end

function M.register_event_handlers()

end

return M