-- Accessibility functions to deal with managing inventories (primarily the player's).
local Area = require("__stdlib__/stdlib/area/area")
local Event = require("__stdlib__/stdlib/event/event")
local Selector = require("__A11y__/logic/utils/selector")
local Categories = require("__A11y__/logic/utils/categories")
local Text = require("__A11y__/logic/utils/text")

local function try_grab_real_item_if_holding_ghost(player)
    local held_item, held_source = Selector.player_held(player)
    if held_item ~= nil and held_source == Selector.source.CURSOR_GHOST then
        local ok, stack = pcall(function()
            return player.get_main_inventory().find_item_stack(held_item)
        end)
        if ok and stack then
            -- drop the ghost and pick up the real item from our inventory instead
            player.clean_cursor()
            player.cursor_stack.transfer_stack(stack)
        end
    end
end

local M = {}

function M.vacuum(player, item_name, item_limit)
    local reach_area = Area.adjust({player.position, player.position},
                                   {player.reach_distance, player.reach_distance})
    -- first pick up everything matching on the ground
    local items_on_ground = player.surface.find_entities_filtered{
        area = reach_area,
        name = 'item-on-ground',
    }

    local vacuumed_count = 0
    local found_count = 0
    local inventory = player.get_main_inventory()
    local inventory_full = false
    if items_on_ground then
        for _, item_on_ground in pairs(items_on_ground) do
            if player.can_reach_entity(item_on_ground) and item_on_ground.stack.name == item_name then
                found_count = found_count + item_on_ground.stack.count
                if vacuumed_count < item_limit and not inventory_full then
                    if inventory.can_insert(item_on_ground.stack) then
                        local inserted_count = inventory.insert(item_on_ground.stack)
                        vacuumed_count = vacuumed_count + inserted_count
                        Text.spawn_floating_item_delta(player, item_on_ground, item_name,
                                                       inserted_count)
                        item_on_ground.stack.clear()
                    else
                        -- inventory is full, bail out
                        inventory_full = true
                    end
                end
            end
        end
    end

    -- then pick up items from belts
    local entities = player.surface.find_entities_filtered{
        area = reach_area,
        -- we want all the TransportBeltConnectable prototypes
        name = {"loader", "splitter", "transport-belt", "underground-belt"},
    }
    if entities then
        for _, entity in pairs(entities) do
            if player.can_reach_entity(entity) then
                local num_lines = entity.get_max_transport_line_index()
                for line_index = 1, num_lines do
                    local line = entity.get_transport_line(line_index)
                    for line_item_name, line_item_count in pairs(line.get_contents()) do
                        if line_item_name == item_name then
                            found_count = found_count + line_item_count
                            if vacuumed_count < item_limit and not inventory_full then
                                local line_item_fake_stack =
                                    {
                                        name = line_item_name,
                                        count = math.min(line_item_count,
                                                         item_limit - vacuumed_count),
                                    }
                                if inventory.can_insert(line_item_fake_stack) then
                                    local inserted_count = inventory.insert(line_item_fake_stack)
                                    vacuumed_count = vacuumed_count + inserted_count
                                    Text.spawn_floating_item_delta(player, entity, line_item_name,
                                                                   inserted_count)
                                    line.remove_item{name = line_item_name, count = inserted_count}
                                else
                                    -- inventory is full, bail out
                                    inventory_full = true
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    local suffix = ''
    if inventory_full then
        suffix = suffix .. ' (inventory full)'
    end

    local msg = ''
    local remaining_count = found_count - vacuumed_count
    if found_count == 0 then
        msg = 'No ' .. q(item_name) .. ' found within reach'
    elseif vacuumed_count == 0 then
        msg = 'Failed to vacuum any of ' .. found_count .. ' ' .. q(item_name) .. ' within reach'
    else
        msg = 'Vacuumed ' .. vacuumed_count .. ' of ' .. found_count .. ' ' .. q(item_name)
                  .. ' within reach'
        player.print(found_count)
        if remaining_count > 0 then
            suffix = suffix .. '; ' .. remaining_count .. ' remaining'
        end
    end

    player.print(msg .. suffix)
end

-- get an item from inventory by name
function M.grab(player, item_name)
    local ok, stack = pcall(function()
        return player.get_main_inventory().find_item_stack(item_name)
    end)
    if ok and stack then
        local stack_count = stack.count
        player.clean_cursor()
        if player.cursor_stack.transfer_stack(stack) then
            player.print("Grabbed " .. stack_count .. " of " .. q(item_name) .. "")
        else
            player.print("We have " .. stack_count .. " of "
                             .. q(item_name) " but couldn't grab it :(")
        end
    else
        player.print("No " .. q(item_name) .. " found in inventory")
    end
end

-- print out how many items of a given type are in inventory and craftable
function M.count_item(player, item_name)
    local count_owned = player.get_item_count(item_name)
    local count_craftable = player.get_craftable_count(item_name)
    local msg = count_owned .. " of " .. q(item_name)
    msg = msg .. " in inventory (additional " .. count_craftable .. " craftable)"
    player.print(msg)
end

-- print out the name of the held or selected item
function M.explain_selection(player)
    local item_name, source = Selector.player_selection(player)
    if source == Selector.source.CURSOR_HELD then
        player.print("Holding " .. q(item_name) .. " in cursor")
    elseif source == Selector.source.CURSOR_GHOST then
        player.print("Holding ghost of " .. q(item_name) .. " in cursor")
    elseif source == Selector.source.HOVERED_GHOST then
        player.print("Hovering over ghost of " .. q(item_name))
    elseif source == Selector.source.HOVERED then
        player.print("Hovering over " .. q(item_name))
    else
        player.print("No idea what that is :(")
    end
end

function M.register_event_handlers()
    Event.register(defines.events.on_player_main_inventory_changed, function(event)
        local player = game.players[event.player_index]

        try_grab_real_item_if_holding_ghost(player)
    end)
end

return M
