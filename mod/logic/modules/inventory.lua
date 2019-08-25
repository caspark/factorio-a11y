-- Accessibility functions to deal with managing inventories (primarily the player's).
local Selector = require("__A11y__/logic/utils/selector")
local Area = require("__stdlib__/stdlib/area/area")

local function spawn_floating_text(entity, text, offY)
    local surface = entity.surface
    local pos = entity.position

    surface.create_entity({
        name = "flying-text",
        position = pos,
        text = text,
        color = defines.color.white,
    })
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
                if vacuumed_count < item_limit then
                    if inventory.can_insert(item_on_ground.stack) then
                        local inserted_count = inventory.insert(item_on_ground.stack)
                        vacuumed_count = vacuumed_count + inserted_count
                        spawn_floating_text(item_on_ground, {
                            "", "+", inserted_count, " ",
                            game.item_prototypes[item_name].localised_name, " (",
                            inventory.get_item_count(item_name), ")",
                        })
                        item_on_ground.stack.clear()
                    else
                        -- inventory is full, bail out
                        inventory_full = true
                        break
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
    if vacuumed_count == 0 then
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

return M
