local Area = require("__stdlib__/stdlib/area/area")
local Event = require("__stdlib__/stdlib/event/event")
local Game = require("__stdlib__/stdlib/game")
local Memoize = require("__stdlib__/stdlib/vendor/memoize")
local Position = require("__stdlib__/stdlib/area/position")
local Table = require("__stdlib__/stdlib/utils/table")
local Text = require("__A11y__/logic/utils/text")

-- Return a map of: name of prototype that takes fuel -> list of fuel categories accepted.
local get_burners_to_fuel_categories = Memoize(function()
    local entities = {}
    for name, prototype in pairs(game.entity_prototypes) do
        if prototype.burner_prototype then
            local accepted_fuel_categories = {}
            for fuel_category, accepted in pairs(prototype.burner_prototype.fuel_categories) do
                if accepted then
                    table.insert(accepted_fuel_categories, fuel_category)
                end
            end
            entities[name] = accepted_fuel_categories
        end
    end
    return entities
end)

-- Return a map of: fuel category -> list of fuel names in this type.
-- Each list of fuel names is sorted from best fuel to worst fuel.
local get_fuel_categories_to_fuel_names = Memoize(function()
    local categories = {}

    local all_item_prototypes = game.item_prototypes
    for name, prototype in pairs(all_item_prototypes) do
        if prototype.fuel_category then
            if categories[prototype.fuel_category] ~= nil then
                local list_of_fuels = categories[prototype.fuel_category]
                table.insert(list_of_fuels, name)
            else
                categories[prototype.fuel_category] = {name}
            end
        end
    end

    for _, list_of_fuels in pairs(categories) do
        table.sort(list_of_fuels, function(fuel_name_a, fuel_name_b)
            return all_item_prototypes[fuel_name_a].fuel_value
                       > all_item_prototypes[fuel_name_b].fuel_value
        end)
    end

    return categories
end)

-- Return a map of: name of fuel burning prototype -> list of fuel item names this prototype accepts
-- Each list of fuel names is sorted from best fuel to worst fuel.
local get_burners_to_fuel_names = Memoize(function()
    local burners = {}

    local fuel_categories_to_fuel_names = get_fuel_categories_to_fuel_names()
    local all_item_prototypes = game.item_prototypes

    local b_to_f = get_burners_to_fuel_categories()

    for burner_name, fuel_categories in pairs(b_to_f) do
        local list_of_fuels = {}
        for _, fuel_category in pairs(fuel_categories) do
            for _, fuel_name in pairs(fuel_categories_to_fuel_names[fuel_category]) do
                table.insert(list_of_fuels, fuel_name)
            end
        end

        table.sort(list_of_fuels, function(fuel_name_a, fuel_name_b)
            return all_item_prototypes[fuel_name_a].fuel_value
                       > all_item_prototypes[fuel_name_b].fuel_value
        end)

        burners[burner_name] = list_of_fuels
    end

    return burners
end)

local function request_ui_rerender(player)
    Game.get_or_set_data("refuel", player.index, "force_rerender", true, true)
end

local function get_all_reachable_refuelable_entities(player)
    local reach_area = Area.adjust({player.position, player.position},
                                   {player.reach_distance, player.reach_distance})
    local fuelable_things = Table.keys(get_burners_to_fuel_categories())
    local all_fuelable = player.surface.find_entities_filtered{
        area = reach_area,
        name = fuelable_things,
    }

    local results = {}
    if all_fuelable then
        for _, fuelable in pairs(all_fuelable) do
            if player.can_reach_entity(fuelable) then
                table.insert(results, fuelable)
            end
        end
    end
    return results
end

local function get_closest_refuelable_entity(player)
    local reachable_fuelables = get_all_reachable_refuelable_entities(player)

    local closest_fuelable = nil
    local closest_dist = math.huge
    for _, fuelable in pairs(reachable_fuelables) do
        local dist = Position.distance_squared(player.position, fuelable.position)
        if dist < closest_dist then
            closest_dist = dist
            closest_fuelable = fuelable
        end
    end
    return closest_fuelable
end

-- Refuel `target` using up to `refuel_count` fuel from the inventory of `player`.
-- Better fuel will be used first.
-- Returns 2 values:
-- 1. error message if refueling failed or `nil` if it succeeded
-- 2. `SimpleItemStack` containing the fuel name and count refueled with
local function refuel_entity(player, target, refuel_count)
    local target_fuel_inventory = target.get_inventory(defines.inventory.fuel)
    if not target_fuel_inventory then
        return q(target.name) .. " does not take fuel!"
    end

    local fuel_names = get_burners_to_fuel_names()[target.name]
    if not fuel_names then
        return q(target.name) .. " can't be refueled - no fuel exists for it in the game!"
    end
    Logger.log("Acceptable fuel for " .. q(target.name) .. ": " .. q_list(fuel_names))

    for _, fuel_name in pairs(fuel_names) do
        local fuel_owned_count = player.get_item_count(fuel_name)
        if fuel_owned_count > 0 then
            if refuel_count > fuel_owned_count then
                refuel_count = fuel_owned_count
            end
            Logger.log("Will try to load " .. q(target.name) .. " with " .. refuel_count .. " of "
                           .. q(fuel_name))

            local fuel_loaded_count = target_fuel_inventory.insert(
                                          {name = fuel_name, count = refuel_count})
            if fuel_loaded_count > 0 then
                local used_fuel = {name = fuel_name, count = fuel_loaded_count}
                local removed_count = player.get_main_inventory().remove(used_fuel)
                if removed_count ~= fuel_loaded_count then
                    -- despite our earlier checks, we've added more fuel to the target than we had
                    -- in our inventory, so we've made fuel out of nothing.
                    -- welp, if this happens there's not much to do other than log it and move on.
                    local msg = "WARNING: added " .. fuel_loaded_count .. " " .. q(fuel_name)
                    msg = msg .. " fuel to " .. q(target.name) .. " but could only remove "
                    msg = msg .. removed_count .. " from player inventory"
                    Logger.log(msg)
                end

                Text.spawn_floating_item_delta(player, target, used_fuel.name, -removed_count)

                ---- now we're all done!
                return nil, used_fuel
            else
                -- We failed to load in what we tried to load, despite the target accepting this fuel.
                -- This can happen when e.g. there's coal in the target with no empty slots in its
                -- inventory, but we ran out of coal so we tried to load it with wood; this fails
                -- since there's no empty item slot for the wood to fit.
                -- This isn't a problem because we'll eventually get to the fuel type that the
                -- target is currently burning
                Logger.log("Failed to load " .. q(target.name) .. " with any " .. q(fuel_name))
            end
        end
    end

    -- If we got here, then we don't have valid fuel for the target.
    -- The cause is one of:
    -- * the target is burning fuel which we don't have
    -- * the target is full of fuel and has no more space
    -- * we flat out need to collect some fuel of that fuel category
    -- Try to give the player a helpful error message in each case.
    local fuels_in_use = {}
    local has_fuels_in_use = false
    local player_has_all_fuels = true
    for fuel_name, _ in pairs(target_fuel_inventory.get_contents()) do
        table.insert(fuels_in_use, fuel_name)
        has_fuels_in_use = true
        if player.get_item_count(fuel_name) == 0 then
            player_has_all_fuels = false
        end
    end
    local msg = "Can't refuel " .. q(target.name) .. " - "
    if has_fuels_in_use then
        if player_has_all_fuels then
            return msg .. "it is fully refueled already!"
        else
            return msg .. "it's burning " .. q_list(fuels_in_use) .. " and you have none"
        end
    else
        return msg .. "don't have any " .. q_list(fuel_names) .. " fuel"
    end
end

local M = {}

function M.refuel_closest(player)
    local target = get_closest_refuelable_entity(player)
    if target then
        local error, stack = refuel_entity(player, target, 20)
        if error ~= nil then
            player.print(error)
        else
            player.print("Refueled closest " .. q(target.name) .. " with " .. stack.count .. " "
                             .. q(stack.name))
        end
    else
        player.print("Nothing in reach which can be refueled!")
    end
end

function M.refuel_selection(player)
    local target = player.selected
    if target then
        local error, stack = refuel_entity(player, target, 20)
        if error ~= nil then
            player.print(error)
        else
            player.print("Refueled hovered " .. q(target.name) .. " with " .. stack.count .. " "
                             .. q(stack.name))
        end
    else
        player.print("No cursor selection to refuel!")
    end
end

function M.refuel_everything(player)
    local targets = get_all_reachable_refuelable_entities(player)
    local targets_count = #targets
    if targets_count > 0 then
        local refueled_count = 0
        local fuel_used = {}
        local last_failure = nil
        for _, target in pairs(targets) do
            local error, stack = refuel_entity(player, target, 20)
            if error == nil then
                if fuel_used[stack.name] == nil then
                    fuel_used[stack.name] = stack.count
                else
                    fuel_used[stack.name] = fuel_used[stack.name] + stack.count
                end
                refueled_count = refueled_count + 1
            else
                last_failure = error
            end
        end
        if refueled_count == 0 then
            player.print("Failed to refuel anything; last failure reason was:\n" .. last_failure)
        else
            local fuel_used_descs = {}
            for fuel_name, count in pairs(fuel_used) do
                table.insert(fuel_used_descs, count .. " " .. fuel_name)
            end
            local fuel_used_msg = (", "):join(fuel_used_descs)
            if refueled_count == targets_count then
                player.print("Refueled all " .. targets_count .. " entities in reach using "
                                 .. fuel_used_msg)
            else
                local msg = "Refueled " .. refueled_count .. " of " .. targets_count
                                .. " entities using "
                msg = msg .. fuel_used_msg .. "; last failure reason was:\n" .. last_failure
                player.print(msg)
            end
        end
    else
        player.print("Nothing in reach which can be refueled!")
    end
end

function M.render_ui(player)
    local ui_last_player_pos = Game.get_or_set_data("refuel", player.index, "last_player_pos",
                                                    false, {x = nil, y = nil})
    local ui_force_rerender = Game.get_or_set_data("refuel", player.index, "force_rerender", false,
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
        Game.get_or_set_data("refuel", player.index, "force_rerender", true, false)
    end

    local closest_refuelable_entity = get_closest_refuelable_entity(player)

    -- get a reference to the grid table, remove any existing drawings, then save new drawings in it
    local ui_ids = Game.get_or_set_data("refuel", player.index, "ui_ids", false, {})
    for k, ui_id in pairs(ui_ids) do
        rendering.destroy(ui_id)
        ui_ids[k] = nil
    end

    -- draw closest fuelable
    if closest_refuelable_entity then
        ui_ids[#ui_ids + 1] = rendering.draw_circle(
                                  {
                color = defines.color.yellow,
                radius = 1,
                width = 2,
                filled = false,
                target = closest_refuelable_entity.position,
                target_offset = {0, 0},
                surface = player.surface,
                players = {player.index},
                visible = true,
                draw_on_ground = false,
            })
    end
end

function M.register_event_handlers()
    Event.register(defines.events.on_player_mined_item, function(event)
        request_ui_rerender(game.players[event.player_index])
    end)
end

return M
