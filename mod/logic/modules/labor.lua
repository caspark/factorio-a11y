require('__stdlib__/stdlib/utils/defines/color')
local Area = require("__stdlib__/stdlib/area/area")
local Event = require("__stdlib__/stdlib/event/event")
local Game = require("__stdlib__/stdlib/game")
local Memoize = require("__stdlib__/stdlib/vendor/memoize")
local Position = require("__stdlib__/stdlib/area/position")
local Table = require("__stdlib__/stdlib/utils/table")
local Run = require("__A11y__/logic/modules/run")

-- if the player is engaged in labor, abort that
local function stop_laboring(player)
    Game.get_or_set_data("labor", player.index, "current_target", true, nil)
end

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

local function on_labor_target_reached(player)
    local current_target = Game.get_or_set_data("labor", player.index, "current_target", false, nil)

    -- TODO build the ghost that is the current target
    player.print('run completed ' .. serpent.block(current_target))
end

local M = {}

function M.labor(player)
    -- have an artificially lower build distance to make the player run around more
    -- otherwise laboring would be better than construction bots
    local max_build_distance = player.resource_reach_distance

    local target = get_closest_reachable_ghost(player)

    if target then
        Game.get_or_set_data("labor", player.index, "current_target", true, target)
        Run.run_to_target(player, target, max_build_distance)
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
    local current_target = Game.get_or_set_data("labor", player.index, "current_target", false, nil)

    -- get a reference to the grid table, remove any existing drawings, then save new drawings in it
    local ui_ids = Game.get_or_set_data("labor", player.index, "ui_ids", false, {})
    for k, ui_id in pairs(ui_ids) do
        rendering.destroy(ui_id)
        ui_ids[k] = nil
    end

    if closest_reachable_ghost then
        ui_ids[#ui_ids + 1] = rendering.draw_circle{
            color = defines.color.white,
            radius = 0.5,
            width = 2,
            filled = false,
            target = closest_reachable_ghost,
            surface = player.surface,
            time_to_live = 60 * 60,
            players = {player.index},
            draw_on_ground = true,
        }
    end

    if current_target then
        ui_ids[#ui_ids + 1] = rendering.draw_line{
            color = defines.color.white,
            width = 1,
            gap_length = 0.2,
            dash_length = 0.2,
            -- from should be the stationary thing so that the dashes don't appear to move on the line
            from = current_target,
            to = player.character,
            surface = player.surface,
            time_to_live = 60 * 60,
            players = {player.index},
            draw_on_ground = true,
        }
    end
end

function M.register_event_handlers()
    Event.register(Event.generate_event_name(Run.events.run_completed), function(event)
        local player = game.players[event.player_index]

        local current_target = Game.get_or_set_data("labor", player.index, "current_target", false,
                                                    nil)
        if current_target ~= nil and current_target == event.target_entity then
            on_labor_target_reached(player)
        end
    end)

    Event.register({
        "a11y-hook-player-walked-up", "a11y-hook-player-walked-right",
        "a11y-hook-player-walked-down", "a11y-hook-player-walked-left",
        Event.generate_event_name(Run.events.tool_used),
    }, function(event)
        stop_laboring(game.players[event.player_index])
    end)
end

return M
