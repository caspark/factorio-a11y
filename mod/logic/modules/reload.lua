require('__stdlib__/stdlib/utils/defines/color')
local Area = require("__stdlib__/stdlib/area/area")
local Event = require("__stdlib__/stdlib/event/event")
local Game = require("__stdlib__/stdlib/game")
local Memoize = require("__stdlib__/stdlib/vendor/memoize")
local Position = require("__stdlib__/stdlib/area/position")
local Table = require("__stdlib__/stdlib/utils/table")
local ProductionScore = require("__A11y__/logic/vendor/production_score")
local Text = require("__A11y__/logic/utils/text")

local calc_production_costs_of_items = Memoize(ProductionScore.generate_price_list)

-- returns a map of entities which can be reloaded to the ammo type(s) they can use
local get_reloadables_to_ammo_categories = Memoize(
                                               function()
        local prototypes = {}
        for name, prototype in pairs(game.entity_prototypes) do
            local accepted_ammo_categories = {}
            if prototype.type == 'ammo-turret' then -- standard gun turrets
                table.insert(accepted_ammo_categories, prototype.attack_parameters.ammo_category)
            elseif prototype.type == 'car' then -- also covers tanks
                for _gun_name, gun_prototype in pairs(prototype.guns) do
                    table.insert(accepted_ammo_categories,
                                 gun_prototype.attack_parameters.ammo_category)
                end
            elseif prototype.type == 'artillery-wagon' or prototype.type == 'artillery-turret' then
                -- doesn't seem to be a way to list the ammo of an artillery wagon or turret
                -- programmatically, so we just hardcode it to be `artillery-shell`, as that's what
                -- artillery shells say their ammo category is.
                table.insert(accepted_ammo_categories, 'artillery-shell')
            end
            if #accepted_ammo_categories > 0 then
                prototypes[name] = accepted_ammo_categories
            end
        end

        -- guns themselves can also be reloaded, and because they're items, they'll never conflict
        -- with gun turrets or vehicles, so just go ahead and find them here too
        for name, prototype in pairs(game.item_prototypes) do
            if prototype.attack_parameters ~= nil and prototype.attack_parameters.ammo_category
                ~= nil then
                prototypes[name] = {prototype.attack_parameters.ammo_category}
            end
        end

        return prototypes
    end)

-- Return a map of: ammo category -> list of ammo names in this type.
-- Each list of ammo names is sorted from best ammo to worst ammo, as determined by the cost of producing that ammo
local get_ammo_categories_to_ammo_names = Memoize(function()
    local categories = {}

    for name, prototype in pairs(game.item_prototypes) do
        local ammo_type = prototype.get_ammo_type()
        if ammo_type then
            if categories[ammo_type.category] ~= nil then
                local list_of_ammos = categories[ammo_type.category]
                table.insert(list_of_ammos, name)
            else
                categories[ammo_type.category] = {name}
            end
        end
    end

    return categories
end)

-- Return a map of: name of reloadable prototype -> list of ammo item names this prototype accepts
-- Each list of ammo names is sorted from best ammo to worst ammo.
local get_reloadables_to_ammo_names = Memoize(function()
    local reloadables = {}

    local ammo_categories_to_ammo_names = get_ammo_categories_to_ammo_names()

    for reloadable_name, ammo_categories in pairs(get_reloadables_to_ammo_categories()) do
        local list_of_ammo = {}
        for _, ammo_category in pairs(ammo_categories) do
            for _, ammo_name in pairs(ammo_categories_to_ammo_names[ammo_category]) do
                table.insert(list_of_ammo, ammo_name)
            end
        end

        table.sort(list_of_ammo, function(ammo_name_a, ammo_name_b)
            local ammo_name_a_score = calc_production_costs_of_items()[ammo_name_a] or 0
            local ammo_name_b_score = calc_production_costs_of_items()[ammo_name_b] or 0
            return ammo_name_a_score > ammo_name_b_score
        end)

        reloadables[reloadable_name] = list_of_ammo
    end

    Logger.log('Reloadables to ammo names: ' .. serpent.block(reloadables))

    return reloadables
end)

local function request_ui_rerender(player)
    Game.get_or_set_data("reload", player.index, "force_rerender", true, true)
end

local function get_all_reachable_reloadable_entities(player)
    local reach_area = Area.adjust({player.position, player.position},
                                   {player.reach_distance, player.reach_distance})
    local reloadable_things = Table.keys(get_reloadables_to_ammo_categories())
    local all_reloadable = player.surface.find_entities_filtered{
        area = reach_area,
        name = reloadable_things,
    }

    local results = {}
    if all_reloadable then
        for _, reloadable in pairs(all_reloadable) do
            if player.can_reach_entity(reloadable) then
                table.insert(results, reloadable)
            end
        end
    end
    return results
end

local function get_closest_reloadable_entity(player)
    local reachable_reloadables = get_all_reachable_reloadable_entities(player)

    local closest_reloadable = nil
    local closest_dist = math.huge
    for _, reloadable in pairs(reachable_reloadables) do
        local dist = Position.distance_squared(player.position, reloadable.position)
        if dist < closest_dist then
            closest_dist = dist
            closest_reloadable = reloadable
        end
    end
    return closest_reloadable
end

local function get_ammo_inventory_for_entity(target)
    if target.prototype.type == 'ammo-turret' then
        return target.get_inventory(defines.inventory.turret_ammo)
    elseif target.prototype.type == 'car' then
        return target.get_inventory(defines.inventory.car_ammo)
    elseif target.prototype.type == 'artillery-turret' then
        return target.get_inventory(defines.inventory.artillery_turret_ammo)
    elseif target.prototype.type == 'artillery-wagon' then
        return target.get_inventory(defines.inventory.artillery_wagon_ammo)
    else
        return nil
    end
end

-- Reload `target` using up to `ammo_count` ammo from the inventory of `player`.
-- Better ammo will be used first.
-- Returns 2 values:
-- 1. error message if reloading failed or `nil` if it succeeded
-- 2. `SimpleItemStack` containing the ammo name and count reloaded with
local function reload_entity(player, target, ammo_count)
    local target_ammo_inventory = get_ammo_inventory_for_entity(target)
    if not target_ammo_inventory then
        return q(target.name) .. " does not take ammo!"
    end

    local ammo_names = get_reloadables_to_ammo_names()[target.name]
    if not ammo_names then
        return q(target.name) .. " can't be reloaded - no ammo exists for it in the game!"
    end
    Logger.log("Acceptable ammo for " .. q(target.name) .. ": " .. q_list(ammo_names))

    for _, ammo_name in pairs(ammo_names) do
        local ammo_owned_count = player.get_item_count(ammo_name)
        if ammo_owned_count > 0 then
            if ammo_count > ammo_owned_count then
                ammo_count = ammo_owned_count
            end
            Logger.log("Will try to load " .. q(target.name) .. " with " .. ammo_count .. " of "
                           .. q(ammo_name))

            local ammo_loaded_count = target_ammo_inventory.insert(
                                          {name = ammo_name, count = ammo_count})
            Logger.log("Loaded " .. ammo_loaded_count .. " of " .. q(ammo_name))
            if ammo_loaded_count > 0 then
                local used_ammo = {name = ammo_name, count = ammo_loaded_count}
                local removed_count = player.get_main_inventory().remove(used_ammo)
                if removed_count < ammo_loaded_count then
                    -- try to remove equipped ammo from player
                    local remaining_to_remove = {
                        name = ammo_name,
                        count = ammo_loaded_count - removed_count,
                    }
                    local extra_removed = player.get_inventory(defines.inventory.character_ammo)
                                              .remove(remaining_to_remove)
                    if extra_removed then
                        removed_count = removed_count + extra_removed
                    end
                end
                if removed_count ~= ammo_loaded_count then
                    -- despite our earlier checks, we've added more ammo to the target than we had
                    -- in our inventory, so we've made ammo out of nothing.
                    -- welp, if this happens there's not much to do other than log it and move on.
                    local msg = "WARNING: added " .. ammo_loaded_count .. " " .. q(ammo_name)
                    msg = msg .. " ammo to " .. q(target.name) .. " but could only remove "
                    msg = msg .. removed_count .. " from player inventory"
                    Logger.log(msg)
                end

                Text.spawn_floating_item_delta(player, target, ammo_name, -removed_count)

                ---- now we're all done!
                return nil, used_ammo
            else
                -- We failed to load in what we tried to load, despite the target accepting this ammo.
                -- This can happen when e.g. there's piercing bullets in the target with no empty slots in its
                -- inventory, but we ran out of piercing bullets so we tried to load it with normal bullets; this fails
                -- since there's no empty item slot for the normal bullets to fit.
                -- This isn't a problem because we'll eventually get to the ammo type that the
                -- target is currently loaded with
                Logger.log("Failed to load " .. q(target.name) .. " with any " .. q(ammo_name))
            end
        else
            Logger.log("Don't own any ammo of type " .. q(ammo_name) .. ", trying next")
        end
    end

    -- If we got here, then we don't have valid ammo for the target.
    -- The cause is one of:
    -- * the target is loaded with ammo which we don't have
    -- * the target is full of ammo and has no more space
    -- * we flat out need to collect some ammo of that ammo category
    -- Try to give the player a helpful error message in each case.
    local ammos_in_use = {}
    local has_ammos_in_use = false
    local player_has_all_ammos = true
    for ammo_name, _ in pairs(target_ammo_inventory.get_contents()) do
        table.insert(ammos_in_use, ammo_name)
        has_ammos_in_use = true
        if player.get_item_count(ammo_name) == 0 then
            player_has_all_ammos = false
        end
    end
    local msg = "Can't reload " .. q(target.name) .. " - "
    if has_ammos_in_use then
        if player_has_all_ammos then
            return msg .. "it is fully reloaded already!"
        else
            return msg .. "it's loaded with " .. q_list(ammos_in_use) .. " and you have none"
        end
    else
        return msg .. "don't have any " .. q_list(ammo_names) .. " ammo"
    end
end

local M = {}

function M.reload_closest(player)
    local target = get_closest_reloadable_entity(player)
    if target then
        local error, stack = reload_entity(player, target, 20)
        if error ~= nil then
            player.print(error)
        else
            player.print("Reloaded closest " .. q(target.name) .. " with " .. stack.count .. " "
                             .. q(stack.name))
        end
    else
        player.print("Nothing in reach which can be reloaded!")
    end
end

function M.reload_selection(player)
    local target = player.selected
    if target then
        local error, stack = reload_entity(player, target, 20)
        if error ~= nil then
            player.print(error)
        else
            player.print("Reloaded hovered " .. q(target.name) .. " with " .. stack.count .. " "
                             .. q(stack.name))
        end
    else
        player.print("No cursor selection to reload!")
    end
end

function M.reload_everything(player)
    local targets = get_all_reachable_reloadable_entities(player)
    local targets_count = #targets
    if targets_count > 0 then
        local reloaded_count = 0
        local ammo_used = {}
        local last_failure = nil
        for _, target in pairs(targets) do
            local error, stack = reload_entity(player, target, 20)
            if error == nil then
                if ammo_used[stack.name] == nil then
                    ammo_used[stack.name] = stack.count
                else
                    ammo_used[stack.name] = ammo_used[stack.name] + stack.count
                end
                reloaded_count = reloaded_count + 1
            else
                last_failure = error
            end
        end
        if reloaded_count == 0 then
            player.print("Failed to reload anything; last failure reason was:\n" .. last_failure)
        else
            local ammo_used_descs = {}
            for ammo_name, count in pairs(ammo_used) do
                table.insert(ammo_used_descs, count .. " " .. ammo_name)
            end
            local ammo_used_msg = (", "):join(ammo_used_descs)
            if reloaded_count == targets_count then
                player.print("Reloaded all " .. targets_count .. " entities in reach using "
                                 .. ammo_used_msg)
            else
                local msg = "Reloaded " .. reloaded_count .. " of " .. targets_count
                                .. " entities using "
                msg = msg .. ammo_used_msg .. "; last failure reason was:\n" .. last_failure
                player.print(msg)
            end
        end
    else
        player.print("Nothing in reach which can be reloaded!")
    end
end

function M.reload_self(player)
    local target = player.character
    local target_ammo_inventory = target.get_inventory(defines.inventory.character_ammo)
    local target_guns_inventory = target.get_inventory(defines.inventory.character_guns)
    local ammo_count = 20

    local reloadables_to_ammo_names = get_reloadables_to_ammo_names()

    local num_gun_slots = #target_guns_inventory
    for slot_number = 1, num_gun_slots do
        local current_gun = target_guns_inventory[slot_number]
        local current_slot_has_gun = current_gun.valid_for_read
        if current_slot_has_gun then
            local ammo_names = reloadables_to_ammo_names[current_gun.prototype.name]

            local current_gun_ammo = target_ammo_inventory[slot_number]
            local current_slot_has_ammo = current_gun_ammo.valid_for_read
            if current_slot_has_ammo then
                local ammo_name = current_gun_ammo.prototype.name
                local ammo_owned_count = player.get_main_inventory().get_item_count(
                                             current_gun_ammo.prototype.name)
                if ammo_owned_count > 0 then
                    if ammo_count > ammo_owned_count then
                        ammo_count = ammo_owned_count
                    end

                    local previous_ammo_count = current_gun_ammo.count
                    current_gun_ammo.count = current_gun_ammo.count + ammo_count

                    local ammo_loaded_count = current_gun_ammo.count - previous_ammo_count
                    if ammo_loaded_count > 0 then
                        local used_ammo = {
                            name = current_gun_ammo.prototype.name,
                            count = ammo_loaded_count,
                        }
                        local removed_count = player.get_main_inventory().remove(used_ammo)

                        if removed_count ~= ammo_loaded_count then
                            -- despite our earlier checks, we've added more ammo to the target than we had
                            -- in our inventory, so we've made ammo out of nothing.
                            -- welp, if this happens there's not much to do other than log it and move on.
                            local msg =
                                "WARNING: added " .. ammo_loaded_count .. " " .. q(ammo_name)
                            msg = msg .. " ammo to " .. q(target.name) .. " but could only remove "
                            msg = msg .. removed_count .. " from player inventory"
                            Logger.log(msg)
                        end

                        player.print('Loaded ' .. q(current_gun.name) .. ' with '
                                         .. ammo_loaded_count .. ' ' .. q(ammo_name))
                        Logger.log(
                            'Loaded player #' .. player.index .. '\'s ' .. q(current_gun.name)
                                .. ' with ' .. ammo_loaded_count .. ' ' .. q(ammo_name))
                    end
                end
            else
                -- gun is unloaded, so try all possible types of ammo, based on what player is carrying
                for _, ammo_name in pairs(ammo_names) do
                    local ammo_owned_count = player.get_item_count(ammo_name)
                    if ammo_owned_count > 0 then
                        if ammo_count > ammo_owned_count then
                            ammo_count = ammo_owned_count
                        end
                        Logger.log("Will try to load " .. q(target.name) .. "'s ammo slot #"
                                       .. slot_number .. " with " .. ammo_count .. " of "
                                       .. q(ammo_name))

                        local ammo_stack = {name = ammo_name, count = ammo_count}
                        if target_ammo_inventory[slot_number].can_set_stack(ammo_stack)
                            and target_ammo_inventory[slot_number].set_stack(ammo_stack) then

                            local used_ammo = {name = ammo_name, count = ammo_count}
                            local removed_count = player.get_main_inventory().remove(used_ammo)
                            if removed_count ~= ammo_count then
                                -- despite our earlier checks, we've added more ammo to the target than we had
                                -- in our inventory, so we've made ammo out of nothing.
                                -- welp, if this happens there's not much to do other than log it and move on.
                                local msg = "WARNING: added " .. ammo_count .. " " .. q(ammo_name)
                                msg = msg .. " ammo to " .. q(target.name)
                                          .. " but could only remove "
                                msg = msg .. removed_count .. " from player inventory"
                                Logger.log(msg)
                            end

                            player.print('Loaded ' .. q(current_gun.name) .. ' with ' .. ammo_count
                                             .. ' ' .. q(ammo_name))
                            Logger.log('Loaded player #' .. player.index .. '\'s '
                                           .. q(current_gun.name) .. ' with ' .. ammo_count .. ' '
                                           .. q(ammo_name))
                        end
                    end
                end
            end
        end -- end if condition to handle loaded and unloaded guns
    end -- end looping through guns
end

function M.render_ui(player)
    local ui_last_player_pos = Game.get_or_set_data("reload", player.index, "last_player_pos",
                                                    false, {x = nil, y = nil})
    local ui_force_rerender = Game.get_or_set_data("reload", player.index, "force_rerender", false,
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
        Game.get_or_set_data("reload", player.index, "force_rerender", true, false)
    end

    local closest_reloadable_entity = get_closest_reloadable_entity(player)

    -- get a reference to the grid table, remove any existing drawings, then save new drawings in it
    local ui_ids = Game.get_or_set_data("reload", player.index, "ui_ids", false, {})
    for k, ui_id in pairs(ui_ids) do
        rendering.destroy(ui_id)
        ui_ids[k] = nil
    end

    -- draw closest reloadable thing
    if closest_reloadable_entity then
        ui_ids[#ui_ids + 1] = rendering.draw_circle(
                                  {
                color = defines.color.pink,
                radius = 1,
                width = 2,
                filled = false,
                target = closest_reloadable_entity.position,
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
