require('__stdlib__/stdlib/utils/defines/color')
local production_score = require('production-score') -- vanilla module, used for production_score.generate_price_list()
local Area = require("__stdlib__/stdlib/area/area")
local Event = require("__stdlib__/stdlib/event/event")
local Is = require('__stdlib__/stdlib/utils/is')
local Game = require("__stdlib__/stdlib/game")
local Memoize = require("__stdlib__/stdlib/vendor/memoize")
local Position = require("__stdlib__/stdlib/area/position")
local Table = require("__stdlib__/stdlib/utils/table")
local Run = require("__A11y__/logic/modules/run")
local Sizer = require("__A11y__/logic/utils/sizer")

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

local function build_distance(player, entity_name)
    -- have an artificially lower build distance to make the player run around more
    -- otherwise laboring would be way better than construction bots
    local max_build_distance = player.resource_reach_distance / 2

    local width, height = Sizer.calc_entity_width_and_height(entity_name)
    local offset = math.max(width, height)

    return max_build_distance + offset
end

local function calc_labour_delay(player, entity_name)
    -- we want to scale the labour cost based on the production cost
    -- rocket silo is ~ 226,000 production cost
    -- nuclear reactor ~ 71,000
    -- centrifuge ~ 12671
    -- oil refinery ~ 1,200
    -- lab ~ 230
    -- inserter ~ 40
    -- transport belt ~ 10

    local prod_cost = calc_production_costs_of_items()[entity_name]
    if prod_cost == nil then
        prod_cost = 9999999 -- arbitrary really high value
    end

    local min_cost = 10
    local max_cost = 100000
    local min_delay = 0
    local max_delay = 60 * 60

    prod_cost = math.min(max_cost, prod_cost)

    return math.floor(min_delay + prod_cost * (min_cost / max_cost) * (max_delay - min_delay))
end

local M = {}

function M.test_labor_delays(player)
    local entity_names = {
        'rocket-silo', 'nuclear-reactor', 'centrifuge', 'oil-refinery', 'lab', 'inserter',
        'transport-belt',
    }
    for _, entity_name in pairs(entity_names) do
        local prod_cost = calc_production_costs_of_items()[entity_name]
        local delay = calc_labour_delay(player, entity_name)
        player.print(entity_name .. ' costs ' .. prod_cost .. ' and delays '
                         .. string.format("%.2f", delay / 60) .. ' secs')
    end
end

local function continue_laboring(player)
    local current_targets = Game.get_or_set_data("labor", player.index, "current_targets", false,
                                                 nil)
    if current_targets == nil then
        return
    end

    -- check to see if we're waiting for a delay to expire
    if current_targets[1] ~= nil and Is.Number(current_targets[1]) then
        -- player.print(game.tick .. ' target = ' .. serpent.block(current_targets[1]))

        if current_targets[1] > 0 then
            -- a positive delay means we can't start counting down the delay yet
            -- (typically the delay is switched to negative when a run completes, to signify
            -- we can start counting the seconds of the delay)
            return
        elseif current_targets[1] < 0 then
            -- treat this target as a delay for that many ticks, assuming this function is called once per tick
            current_targets[1] = current_targets[1] + 1
            Game.get_or_set_data("labor", player.index, "current_targets", true, current_targets)
            return
        else
            -- done with the delay, move one
            pop_current_target(player)
        end
    end

    local current_target = current_targets[1]
    if current_target == nil then
        stop_laboring(player) -- we've reached the end of the labor queue
        return
    end

    player.clean_cursor() -- clean cursor so we don't have to worry about items in the cursor stack

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
        if collisions == nil or #collisions > 0 then
            -- we got a collision, probably with ourselves, so we need to run out of the way
            local target_pos = player.surface
                                   .find_non_colliding_position(current_target.ghost_name, -- prototype name
                                                                player.position, -- center
                100, -- arbitrary "fairly big" radius
                1, -- precision for search (step size)
                true -- force_to_tile_center
                )
            if target_pos == nil then
                player.print('Laboring stopped: no nearby empty tile to build from')
                stop_laboring(player)
            else
                Run.run_to_target(player, target_pos, 0)
            end
        else
            local removed_count = player.character.get_main_inventory().remove(items_to_use)
            Logger.log('Labor: removed ' .. removed_count .. ' of ' .. q(items_to_use.name))
            -- we successfully revived the entity, i.e. built the thing we were trying to build
            pop_current_target(player) -- done with the current thing
            M.labor(player) -- find the next thing to labor
        end
    end
end

local function set_add_position(set, position)
    if set[position.x] == nil then
        set[position.x] = {}
    end
    set[position.x][position.y] = true
end

local function set_contains_position(set, position)
    return set[position.x] ~= nil and set[position.x][position.y]
end

function M.labor(player)
    -- clean the cursor so we don't have to worry about accounting for items in the cursor stack
    -- (also thematically it doesn't make sense that the character can be doing other things while
    -- laboring)
    player.clean_cursor()

    local new_targets = find_reachable_ghosts(player)

    -- make a rudimentary set of positions we've seen to avoid duplicating entities in the target list
    -- (not doing this makes it easy for the list of targets to explode to thousands of items, which
    -- slows the game to a crawl)
    local seen_positions = {}
    for _, target in pairs(new_targets) do
        set_add_position(seen_positions, target.position)
    end

    local existing_targets = Game.get_or_set_data("labor", player.index, "current_targets", false,
                                                  {})

    local has_available_items = Memoize(function(ghost_prototype)
        return calc_cheapest_available_item_for_ghost(player, ghost_prototype) ~= nil
    end)
    for _, target in pairs(existing_targets) do
        if Is.Object(target) and target.valid
            and not set_contains_position(seen_positions, target.position)
            and has_available_items(target.ghost_prototype) then
            table.insert(new_targets, target)
        end
    end
    local dist = Memoize(function(entity)
        return Position.distance_squared(player.position, entity.position)
    end)
    table.sort(new_targets, function(a, b)
        return dist(a) < dist(b)
    end)
    local first_target = new_targets[1]

    if first_target then
        -- insert a delay before we deal with the first target
        table.insert(new_targets, 1, calc_labour_delay(player, first_target.ghost_name))

        Game.get_or_set_data("labor", player.index, "current_targets", true, new_targets)

        Run.run_to_target(player, first_target, build_distance(player, first_target.ghost_name))
    else
        Game.get_or_set_data("labor", player.index, "current_targets", true, new_targets)
    end
end

function M.try_continue_laboring(player)
    continue_laboring(player)
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
        local seen_first_entity = false
        for i, current_target in pairs(current_targets) do
            if Is.Object(current_target) and current_target.valid then
                if not seen_first_entity then
                    seen_first_entity = true
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
            if Is.Object(current_targets[1]) and not current_targets[1].valid then
                stop_laboring(player)
            else
                if Is.Number(current_targets[1]) and current_targets[1] > 0 then
                    -- signify that we can start dealing with the delay
                    current_targets[1] = -current_targets[1]
                end
                continue_laboring(player)
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
