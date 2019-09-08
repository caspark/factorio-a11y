require('__stdlib__/stdlib/utils/defines/color')
local production_score = require('production-score') -- vanilla module, used for production_score.generate_price_list()
local Area = require("__stdlib__/stdlib/area/area")
local Event = require("__stdlib__/stdlib/event/event")
local Game = require("__stdlib__/stdlib/game")
local Memoize = require("__stdlib__/stdlib/vendor/memoize")
local Position = require("__stdlib__/stdlib/area/position")
local Table = require("__stdlib__/stdlib/utils/table")
local Run = require("__A11y__/logic/modules/run")

local calc_production_costs_of_items = Memoize(production_score.generate_price_list)

-- if the player is engaged in labor, abort that
local function stop_laboring(player)
    Game.get_or_set_data("labor", player.index, "current_targets", true, nil)
end

local function pop_current_target(player)
    local current_targets = Game.get_or_set_data("labor", player.index, "current_targets", false,
                                                 nil)
    table.remove(current_targets, 1)
    Game.get_or_set_data("labor", player.index, "current_targets", true, current_targets)
end

local function calc_cheapest_available_item_for_ghost(player, ghost_prototype)
    local possibilities = {}
    for _, possible_stack in pairs(ghost_prototype.items_to_place_this) do
        -- TODO this refuses to build when player has that item in their cursor stack but not in inventory
        local item_count = player.character.get_main_inventory().get_item_count(possible_stack.name)
        if item_count >= possible_stack.count then
            table.insert(possibilities, possible_stack)
        end
    end

    table.sort(possibilities, function(item_a, item_b)
        local item_a_score = calc_production_costs_of_items()[item_a] or 0
        local item_b_score = calc_production_costs_of_items()[item_b] or 0
        return item_a_score < item_b_score
    end)

    return possibilities[1]
end

local function find_reachable_ghosts(player)
    local ghost_entities = player.surface.find_entities_filtered{
        position = player.position,
        radius = player.reach_distance,
        name = 'entity-ghost',
        force = player.force,
    }

    local results = {}
    if ghost_entities then
        for _, ghost_entity in pairs(ghost_entities) do
            table.insert(results, {
                ghost_entity = ghost_entity,
                dist = Position.distance_squared(player.position, ghost_entity.position),
            })
        end
    end
    table.sort(results, function(a, b)
        return a.dist < b.dist
    end)

    local available_ghosts = {}
    local unavailable_ghosts = {}
    local has_available_items = Memoize(function(ghost_prototype)
        return calc_cheapest_available_item_for_ghost(player, ghost_prototype) ~= nil
    end)
    for _, result in pairs(results) do
        if has_available_items(result.ghost_entity.ghost_prototype) then
            table.insert(available_ghosts, result.ghost_entity)
        else
            table.insert(unavailable_ghosts, result.ghost_entity)
        end
    end

    return available_ghosts, unavailable_ghosts
end

local M = {}

local function on_labor_target_reached(player)
    local current_targets = Game.get_or_set_data("labor", player.index, "current_targets", false,
                                                 nil)
    local current_target = current_targets[1]
    Game.get_or_set_data("labor", player.index, "current_targets", true, current_targets)

    local ghost_prototype = current_target.ghost_prototype
    local items_to_use = calc_cheapest_available_item_for_ghost(player,
                                                                current_target.ghost_prototype)
    if items_to_use == nil then
        local possibilities = {}
        for _, possible_stack in pairs(ghost_prototype.items_to_place_this) do
            table.insert(possibilities, possible_stack.count .. ' ' .. q(possible_stack.name))
        end
        player.print('Can\'t build ' .. q(current_target.ghost_name) .. ' - need '
                         .. (' or '):join(possibilities))
    else
        local collisions = current_target.revive()
        -- TODO need to handle collisions with player here (run to a free point further away - test with chemistry and rocket silo buildings)
        if collisions == nil or #collisions > 0 then
            player.print('Failed to build ghost due to colliding entities: '
                             .. serpent.block(collisions))
            stop_laboring(player) -- abort entirely
        else
            local removed_count = player.character.get_main_inventory().remove(items_to_use)
            Logger.log('Labor: removed ' .. removed_count .. ' of ' .. q(items_to_use.name))
            -- we successfully revived the entity, i.e. built the thing we were trying to build
            pop_current_target(player) -- done with the current thing
            M.labor(player) -- find the next thing to labor
        end
    end
end

function M.labor(player)
    -- have an artificially lower build distance to make the player run around more
    -- otherwise laboring would be better than construction bots
    local max_build_distance = player.resource_reach_distance

    local new_targets = find_reachable_ghosts(player)

    local existing_targets = Game.get_or_set_data("labor", player.index, "current_targets", false,
                                                  {})

    local has_available_items = Memoize(function(ghost_prototype)
        return calc_cheapest_available_item_for_ghost(player, ghost_prototype) ~= nil
    end)
    for _, target in pairs(existing_targets) do
        if target.valid and has_available_items(target.ghost_prototype) then
            table.insert(new_targets, target)
        end
    end
    local dist = Memoize(function(entity)
        return Position.distance_squared(player.position, entity.position)
    end)
    table.sort(new_targets, function(a, b)
        return dist(a) < dist(b)
    end)
    Game.get_or_set_data("labor", player.index, "current_targets", true, new_targets)

    local first_target = new_targets[1]
    if first_target then
        -- TODO factor in size of the building in the max build distance (should be able to calc an oval)
        Run.run_to_target(player, new_targets[1], max_build_distance)
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

    local available_ghosts, unavailable_ghosts = find_reachable_ghosts(player)
    local current_targets = Game.get_or_set_data("labor", player.index, "current_targets", false,
                                                 nil)

    -- get a reference to the grid table, remove any existing drawings, then save new drawings in it
    local ui_ids = Game.get_or_set_data("labor", player.index, "ui_ids", false, {})
    for k, ui_id in pairs(ui_ids) do
        rendering.destroy(ui_id)
        ui_ids[k] = nil
    end

    for i, ghost in pairs(available_ghosts) do
        ui_ids[#ui_ids + 1] = rendering.draw_circle{
            color = i == 1 and defines.color.white or defines.color.grey,
            radius = 0.5,
            width = 2,
            filled = false,
            target = ghost,
            surface = player.surface,
            time_to_live = 60 * 60,
            players = {player.index},
            draw_on_ground = true,
        }
    end
    for _, ghost in pairs(unavailable_ghosts) do
        ui_ids[#ui_ids + 1] = rendering.draw_circle{
            color = defines.color.brown,
            radius = 0.5,
            width = 2,
            filled = false,
            target = ghost,
            surface = player.surface,
            time_to_live = 60 * 60,
            players = {player.index},
            draw_on_ground = true,
        }
    end

    if current_targets then
        for i, current_target in pairs(current_targets) do
            if current_target.valid then
                if i == 1 then
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

                ui_ids[#ui_ids + 1] = rendering.draw_circle{
                    color = defines.color.white,
                    radius = 0.5,
                    width = 2,
                    filled = false,
                    target = current_target,
                    surface = player.surface,
                    time_to_live = 60 * 60,
                    players = {player.index},
                    draw_on_ground = true,
                }
            end
        end
    end

end

function M.register_event_handlers()
    Event.register(Event.generate_event_name(Run.events.run_completed), function(event)
        local player = game.players[event.player_index]

        local current_targets = Game.get_or_set_data("labor", player.index, "current_targets",
                                                     false, nil)
        if current_targets ~= nil then
            if not current_targets[1].valid then
                stop_laboring(player)
            elseif current_targets[1] == event.target_entity then
                on_labor_target_reached(player)
            end
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
