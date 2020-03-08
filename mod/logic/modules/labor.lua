require("__stdlib__/stdlib/utils/defines/color")
local Event = require("__stdlib__/stdlib/event/event")
local Is = require("__stdlib__/stdlib/utils/is")
local Game = require("__stdlib__/stdlib/game")
local Memoize = require("__stdlib__/stdlib/vendor/memoize")
local Position = require("__stdlib__/stdlib/area/position")
local ProductionScore = require("__A11y__/logic/vendor/production_score")
local Run = require("__A11y__/logic/modules/run")
local Sizer = require("__A11y__/logic/utils/sizer")

local calc_production_costs_of_items = Memoize(ProductionScore.generate_price_list)

-- if the player is engaged in labor, abort that
local function clear_all_tasks(player)
    Game.get_or_set_data("labor", player.index, "task_queue", true, nil)
    Game.get_or_set_data("labor", player.index, "task_pool", true, nil)
end

-- Attempt to insert an item_stack or array of item_stacks into the entity. Spill to the ground at
-- the entity/player anything that doesn't get inserted
-- @param entity: the entity or player object
-- @param item_stacks: a SimpleItemStack or array of SimpleItemStacks to insert
-- @return bool : there was some items inserted or spilled
-- Sourced from https://github.com/Nexela/Nanobots/blob/master/scripts/nanobots.lua (MIT license)
local function insert_or_spill_items(entity, item_stacks)
    local new_stacks = {}
    if item_stacks then
        if item_stacks[1] and item_stacks[1].name then
            new_stacks = item_stacks
        elseif item_stacks and item_stacks.name then
            new_stacks = {item_stacks}
        end
        for _, stack in pairs(new_stacks) do
            local name, count, health = stack.name, stack.count, stack.health or 1
            if game.item_prototypes[name] and not game.item_prototypes[name].has_flag('hidden') then
                local inserted = entity.insert({name = name, count = count, health = health})
                if inserted ~= count then
                    entity.surface.spill_item_stack(entity.position, {
                        name = name,
                        count = count - inserted,
                        health = health,
                    }, true)
                end
            end
        end
        return new_stacks[1] and new_stacks[1].name and true
    end
end

local function set_add_position(set, position)
    if set[position.x] == nil then set[position.x] = {} end
    set[position.x][position.y] = true
end

local function set_contains_position(set, position)
    return set[position.x] ~= nil and set[position.x][position.y]
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
    local ghost_entities = player.surface.find_entities_filtered {
        position = player.position,
        radius = player.reach_distance,
        name = "entity-ghost",
        force = player.force,
    }

    local has_available_items = Memoize(function(ghost_prototype)
        return calc_cheapest_available_item_for_ghost(player, ghost_prototype) ~= nil
    end)

    local available_ghosts = {}
    local unavailable_ghosts = {}
    if ghost_entities then
        for _, ghost_entity in pairs(ghost_entities) do
            if has_available_items(ghost_entity.ghost_prototype) then
                table.insert(available_ghosts, ghost_entity)
            else
                table.insert(unavailable_ghosts, ghost_entity)
            end
        end
    end

    return available_ghosts, unavailable_ghosts
end

local function find_reachable_deconstructs(player)
    local potential_deconstructs = player.surface.find_entities_filtered {
        position = player.position,
        radius = player.reach_distance,
    }

    local results = {}
    if potential_deconstructs then
        for _, potential_deconstruct in pairs(potential_deconstructs) do
            if potential_deconstruct.to_be_deconstructed(player.force) then
                table.insert(results, potential_deconstruct)
            end
        end
    end

    return results
end

local function build_distance(player, entity_name)
    -- have an artificially lower build distance to make the player run around more
    -- otherwise laboring would be way better than construction bots
    local max_build_distance = player.resource_reach_distance / 2

    local width, height = Sizer.calc_entity_width_and_height(entity_name)
    local offset = math.max(width, height)

    return max_build_distance + offset
end

local function calc_labour_delay(_player, entity_name)
    -- we want to scale the labour cost based on the production cost
    -- see also M.test_labor_delays() for faster iteration on this

    local prod_cost = calc_production_costs_of_items()[entity_name]
    if prod_cost == nil then
        prod_cost = 9999999 -- arbitrary really high value
    end

    local min_cost = 150
    local max_cost = 1000
    local min_delay = 30
    local max_delay = 60 * 45

    prod_cost = math.min(max_cost, prod_cost)
    prod_cost = math.max(min_cost, prod_cost)

    return math.floor(min_delay + (prod_cost - min_cost) / (max_cost - min_cost)
                          * (max_delay - min_delay))
end

-- Looks for tasks to do near the player and combines them with the given old task pool for the given
-- player; returns the sorted task pool.
local function build_new_task_pool(player, old_task_pool)
    -- make a rudimentary set of positions we've seen to avoid duplicating entities in the target list
    -- (not doing this makes it easy for the list of targets to explode to thousands of items, which
    -- slows the game to a crawl)
    local seen_positions = {}

    -- find things for the player to labor over
    -- ghosts should be built
    local new_ghosts = find_reachable_ghosts(player)
    for _, entity in pairs(new_ghosts) do set_add_position(seen_positions, entity.position) end
    -- entities marked for deconstruction should be deconstructed
    local new_deconstructs = find_reachable_deconstructs(player)
    for _, entity in pairs(new_deconstructs) do set_add_position(seen_positions, entity.position) end

    -- accumulate new things into a single unordered task pool
    -- our task queue is a list of objects, each of which has a single key which determines what
    -- type of task it is.
    local task_pool = {}
    for _, entity in pairs(new_ghosts) do table.insert(task_pool, {do_build_ghost = entity}) end
    for _, entity in pairs(new_deconstructs) do
        table.insert(task_pool, {do_deconstruct_entity = entity})
    end

    -- check whether existing tasks are still valid, and add them in to the new pool if they are
    local has_available_items = Memoize(function(ghost_prototype)
        return calc_cheapest_available_item_for_ghost(player, ghost_prototype) ~= nil
    end)
    for _, task in pairs(old_task_pool) do
        -- ghosts may no longer be buildable if we've run out of items
        if Is.Object(task.do_build_ghost) and task.do_build_ghost.valid
            and not set_contains_position(seen_positions, task.do_build_ghost.position)
            and has_available_items(task.do_build_ghost.ghost_prototype) then
            table.insert(task_pool, task)
        end
        -- entities to deconstruct may have had the deconstruct-me flag removed
        if Is.Object(task.do_deconstruct_entity) and task.do_deconstruct_entity.valid
            and not set_contains_position(seen_positions, task.do_deconstruct_entity.position)
            and task.do_deconstruct_entity.to_be_deconstructed(player.force) then
            table.insert(task_pool, task)
        end
    end

    -- sort all tasks to find which one we want to do first
    -- basically any task involving building or deconstructing should be prioritized according to
    -- how close it is, while any other task should happen before building or deconstructing.
    local dist = Memoize(function(task)
        if Is.Object(task.do_build_ghost) then
            local entity = task.do_build_ghost
            return Position.distance_squared(player.position, entity.position)
        elseif Is.Object(task.do_deconstruct_entity) then
            local entity = task.do_deconstruct_entity
            return Position.distance_squared(player.position, entity.position)
        else
            return 0
        end
    end)
    table.sort(task_pool, function(a, b) return dist(a) < dist(b) end)

    return task_pool
end

-- Given a task, return a list of all tasks that need to be completed to get that task done
-- (including the original task). Useful for tasks that require prerequisites to be completed first
-- (like running to the location of a ghost to build something over before doing the actual build).
local function make_task_queue(player, task)
    local task_queue = {}
    table.insert(task_queue, task)

    local entity
    local entity_name
    if Is.Object(task.do_build_ghost) then
        entity = task.do_build_ghost
        entity_name = entity.ghost_name
    elseif Is.Object(task.do_deconstruct_entity) then
        entity = task.do_deconstruct_entity
        entity_name = entity.name
    else
        entity = nil
        entity_name = nil
    end
    if entity then
        -- need to run to target entity first
        local run_task = {
            do_run_target = entity,
            do_run_target_distance = build_distance(player, entity_name),
        }
        table.insert(task_queue, 1, run_task)
    end

    -- insert a delay before building ghosts
    if Is.Object(task.do_build_ghost) then
        local wait_task = {
            do_wait_time = calc_labour_delay(player, entity_name),
            do_wait_for = task.do_build_ghost,
        }
        table.insert(task_queue, 1, wait_task)
    end

    return task_queue
end

local function process_task_wait(_player, task)
    if not Is.Number(task.do_wait_progress) then
        task.do_wait_progress = 0
        return {task}
    elseif task.do_wait_progress < task.do_wait_time then
        task.do_wait_progress = task.do_wait_progress + 1
        return {task}
    end
    -- if we get here then we're done with the waiting!
end

local function process_task_build_ghost(player, task)
    -- clean the cursor so we don't have to worry about accounting for items in the cursor stack
    -- (also thematically it doesn't make sense that the character can be doing other things while
    -- building ghosts)
    player.clean_cursor()

    local ghost_entity = task.do_build_ghost
    local ghost_prototype = ghost_entity.ghost_prototype
    local items_to_use =
        calc_cheapest_available_item_for_ghost(player, ghost_entity.ghost_prototype)
    if items_to_use == nil then
        local possibilities = {}
        for _, possible_stack in pairs(ghost_prototype.items_to_place_this) do
            table.insert(possibilities, possible_stack.count .. " " .. q(possible_stack.name))
        end
        player.print("Can't build " .. q(ghost_entity.ghost_name) .. " - need "
                         .. (" or "):join(possibilities))
    else
        local collisions = ghost_entity.revive()
        if collisions == nil or #collisions > 0 then
            -- we got a collision, probably with ourselves, so we need to run out of the way
            local target_pos = player.surface
                                   .find_non_colliding_position(ghost_entity.ghost_name, -- prototype name
                                                                player.position, -- center
            100, -- arbitrary "fairly big" radius
            2, -- precision for search (step size)
            true -- force_to_tile_center
            )

            if target_pos == nil then
                player.print("Laboring dropping task: no nearby empty tile to build from")
            else
                local run_task = {do_run_target = target_pos, do_run_target_distance = 0}
                return {run_task, task}
            end
        else
            local removed_count = player.character.get_main_inventory().remove(items_to_use)
            Logger.log("Labor: removed " .. removed_count .. " of " .. q(items_to_use.name))
            -- we successfully revived the entity, i.e. built the thing we were trying to build
        end
    end
end

local function process_task_deconstruct(player, task)
    local entity = task.do_deconstruct_entity

    if entity and entity.valid and entity.to_be_deconstructed(player.force) then
        if entity.type == "item-entity" then
            local item_stacks = {}
            item_stacks[#item_stacks + 1] = {
                name = entity.stack.name,
                count = entity.stack.count,
                health = entity.stack.health,
                durability = entity.stack.durability,
            }
            if #item_stacks > 0 then insert_or_spill_items(player, item_stacks) end
            entity.destroy()
        elseif entity.name == "item-on-ground" then
            insert_or_spill_items(entity.stack)
        elseif entity.name == "deconstructible-tile-proxy" then
            local tile = entity.surface.get_tile(entity.position)
            if tile then player.mine_tile(tile) end
        elseif entity.valid then
            if not player.mine_entity(entity) then
                player.print("Failed to deconstruct " .. q(entity.name)
                                 .. " (is your inventory full?)")
                return {"ABORT_LABOR"}
            end
        end
    end
end

-- Process a single task. Returns one or more tasks that still need to be completed (can return just
-- the same input task if it's not done yet), or an array containing the string "ABORT_LABOR" if the
-- laboring cannot continue.
local function process_task(player, task)
    if Is.Object(task.do_run_target) then
        Run.run_to_target(player, task.do_run_target, task.do_run_target_distance)
        return {{do_arrival = true}}
    elseif task.do_arrival then
        if task.do_arrival_completed then
            -- we're done!
            return
        else
            -- nothing we can do to progress here - we need to wait for the run to complete
            return {task}
        end
    elseif Is.Number(task.do_wait_time) then
        return process_task_wait(player, task)
    elseif Is.Object(task.do_build_ghost) then
        return process_task_build_ghost(player, task)
    elseif Is.Object(task.do_deconstruct_entity) then
        return process_task_deconstruct(player, task)
    else
        player.print("A11y Error: unknown labor task! " .. serpent.block(task))
        return {"ABORT_LABOR"}
    end
end

local M = {}

function M.test_labor_delays(player)
    local entity_names = {
        "rocket-silo", "nuclear-reactor", "centrifuge", "oil-refinery", "lab", "gun-turret",
        "express-transport-belt", "splitter", "inserter", "transport-belt",
    }
    for _, entity_name in pairs(entity_names) do
        local prod_cost = calc_production_costs_of_items()[entity_name]
        local delay = calc_labour_delay(player, entity_name)
        player.print(entity_name .. " costs " .. prod_cost .. " and delays "
                         .. string.format("%.2f", delay / 60) .. " secs")
    end
end

-- Attempt to process any tasks in the given player's queue. Expected to be called once per tick.
function M.try_process_task_queue(player)
    local task_queue = Game.get_or_set_data("labor", player.index, "task_queue", false, nil)
    if task_queue == nil then return end

    local task = table.remove(task_queue, 1)
    if task == nil then
        clear_all_tasks(player)
        return
    end

    Logger.log("Labor: processing task " .. serpent.block(task))
    local new_tasks = process_task(player, task)
    local abort_labor = false
    if new_tasks ~= nil then
        for _i, new_task in ipairs(new_tasks) do
            if new_task == "ABORT_LABOR" then
                abort_labor = true
                break
            else
                table.insert(task_queue, 1, new_task)
            end
        end
    end
    Game.get_or_set_data("labor", player.index, "task_queue", true, task_queue)

    if not abort_labor and #task_queue == 0 then
        -- time to search for new tasks to complete!
        M.labor(player)
    end
    -- subsequent tasks in the queue will be processed next tick.
end

-- Add new tasks to the task pool and set up the task queue to begin execution on the most promising
-- task (which will actually happen when try_process_task_queue is called next tick).
function M.labor(player)
    local old_task_pool = Game.get_or_set_data("labor", player.index, "task_pool", false, {})
    local task_pool = build_new_task_pool(player, old_task_pool)
    Game.get_or_set_data("labor", player.index, "task_pool", true, task_pool)

    if task_pool[1] then
        local task = task_pool[1]
        table.remove(task_pool, 1)
        Game.get_or_set_data("labor", player.index, "task_pool", true, task_pool)

        local task_queue = make_task_queue(player, task)
        Game.get_or_set_data("labor", player.index, "task_queue", true, task_queue)
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
    -- TODO update UI rendering to use the task_queue and task_pool
    local current_targets = Game.get_or_set_data("labor", player.index, "current_targets", false,
                                                 nil)

    -- get a reference to the grid table, remove any existing drawings, then save new drawings in it
    local ui_ids = Game.get_or_set_data("labor", player.index, "ui_ids", false, {})
    for k, ui_id in pairs(ui_ids) do
        rendering.destroy(ui_id)
        ui_ids[k] = nil
    end

    for i, ghost in pairs(available_ghosts) do
        ui_ids[#ui_ids + 1] = rendering.draw_circle {
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
        ui_ids[#ui_ids + 1] = rendering.draw_circle {
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
            if Is.Number(current_target) and current_target < 0 then
                -- it's a delay, so visualize it over the real current target
                local real_current_target = current_targets[i + 1]
                local delay_size = calc_labour_delay(player, real_current_target.ghost_name)
                local delay_remaining = -current_target
                ui_ids[#ui_ids + 1] = rendering.draw_arc {
                    color = defines.color.white,
                    max_radius = 0.5,
                    min_radius = 0,
                    start_angle = -math.pi / 2,
                    angle = 2 * math.pi - (2 * math.pi * delay_remaining / delay_size),
                    target = real_current_target,
                    surface = player.surface,
                    time_to_live = 60 * 60,
                    players = {player.index},
                    draw_on_ground = true,
                }
                -- now we need the UI to update even if the player isn't moving
                Game.get_or_set_data("labor", player.index, "force_rerender", true, true)
            elseif Is.Object(current_target) and current_target.valid then
                if not seen_first_entity then
                    seen_first_entity = true
                    ui_ids[#ui_ids + 1] = rendering.draw_line {
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

                ui_ids[#ui_ids + 1] = rendering.draw_circle {
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

        local task_queue = Game.get_or_set_data("labor", player.index, "task_queue", false, nil)
        if task_queue == nil then return end

        local task = task_queue[1]
        if task == nil then clear_all_tasks(player) end

        if task.do_arrival then
            task.do_arrival_completed = true
        else
            clear_all_tasks(player)
        end
        Game.get_or_set_data("labor", player.index, "task_queue", true, task_queue)
    end)

    Event.register({
        "a11y-hook-player-walked-up", "a11y-hook-player-walked-right",
        "a11y-hook-player-walked-down", "a11y-hook-player-walked-left",
        Event.generate_event_name(Run.events.tool_used),
    }, function(event) clear_all_tasks(game.players[event.player_index]) end)
end

return M
