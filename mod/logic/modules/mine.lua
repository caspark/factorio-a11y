local Area = require("__stdlib__/stdlib/area/area")
local Event = require("__stdlib__/stdlib/event/event")
local Game = require("__stdlib__/stdlib/game")
local Position = require("__stdlib__/stdlib/area/position")

local Categories = require("__A11y__/logic/utils/categories")

local function request_ui_rerender(player)
    Game.get_or_set_data("mine", player.index, "force_rerender", true, true)
end

local function get_closest_reachable_resource(player)
    local resource_reach_area = Area.adjust({player.position, player.position}, {
        player.resource_reach_distance, player.resource_reach_distance,
    })
    local all_resources = player.surface.find_entities_filtered{
        area = resource_reach_area,
        type = Categories.resource_prototypes,
    }

    local closest_resource = nil
    local closest_dist = math.huge
    if all_resources then
        for _, res in pairs(all_resources) do
            local d = Position.distance_squared(player.position, res.position)
            if d < closest_dist and player.can_reach_entity(res) then
                closest_dist = d
                closest_resource = res
            end
        end
    end
    return closest_resource
end

local function get_closest_reachable_building(player)
    local reach_area = Area.adjust({player.position, player.position},
                                   {player.reach_distance, player.reach_distance})
    local all_buildings = player.surface.find_entities_filtered{
        area = reach_area,
        type = Categories.building_prototypes,
    }
    local closest_building = nil
    local closest_dist = math.huge
    if all_buildings then
        for _, building in pairs(all_buildings) do
            local d = Position.distance_squared(player.position, building.position)
            if d < closest_dist and player.can_reach_entity(building) then
                closest_dist = d
                closest_building = building
            end
        end
    end
    return closest_building
end

local M = {}

-- mine the resource or tree closest to the player instantly
function M.mine_closest_resource(player)
    local target = get_closest_reachable_resource(player)
    if not target then
        player.print("No resource in range to mine!")
        return
    end
    local target_name = target.prototype.name
    if player.mine_entity(target) then
        player.print("Mined closest resource " .. q(target_name))
    end
end

-- mine the closest building
function M.mine_closest_building(player)
    local target = get_closest_reachable_building(player)
    if not target then
        player.print("No building in range to mine!")
        return
    end
    local target_name = target.prototype.name
    if player.mine_entity(target) then
        player.print("Mined closest building " .. q(target_name))
    end
end

-- mine the resource or building which the player has selected
function M.mine_selection(player)
    local target = player.selected
    if not target then
        player.print("No cursor selection to mine!")
        return
    end
    local target_name = target.prototype.name
    if not player.can_reach_entity(target) then
        player.print("That " .. q(target_name) .. " is too far away to mine!")
        return
    end
    if player.mine_entity(target) then
        player.print("Mined selected " .. q(target_name))
    end
end

-- mine the tile which the player is standing on
function M.mine_tile_under_player(player)
    local to_mine = player.surface.get_tile(player.position)
    if to_mine then
        local to_mine_name = to_mine.prototype.name
        if player.mine_tile(to_mine) then
            player.print("Mined a " .. to_mine_name)
        end
    else
        player.print("Not standing on a tile!")
    end
end

-- render a UI around the player showing their reach
function M.render_ui(player)
    local ui_last_player_pos = Game.get_or_set_data("mine", player.index, "last_player_pos", false,
                                                    {x = nil, y = nil})
    local ui_force_rerender = Game.get_or_set_data("mine", player.index, "force_rerender", false,
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
        Game.get_or_set_data("mine", player.index, "force_rerender", true, false)
    end

    local normal_reach = player.reach_distance
    local resource_reach = player.resource_reach_distance

    local closest_reachable_resource = get_closest_reachable_resource(player)
    local closest_reachable_building = get_closest_reachable_building(player)

    -- get a reference to the grid table, remove any existing drawings, then save new drawings in it
    local ui_ids = Game.get_or_set_data("mine", player.index, "ui_ids", false, {})
    for k, ui_id in pairs(ui_ids) do
        rendering.destroy(ui_id)
        ui_ids[k] = nil
    end

    -- render mining reach
    ui_ids[#ui_ids + 1] = rendering.draw_circle({
        color = defines.color.green,
        radius = resource_reach,
        width = 2,
        filled = false,
        target = player.position,
        target_offset = {0, 0},
        surface = player.surface,
        players = {player.index},
        visible = true,
        draw_on_ground = true,
    })

    -- render normal reach
    ui_ids[#ui_ids + 1] = rendering.draw_circle({
        color = defines.color.green,
        radius = normal_reach,
        width = 2,
        filled = false,
        target = player.position,
        target_offset = {0, 0},
        surface = player.surface,
        players = {player.index},
        visible = true,
        draw_on_ground = true,
    })

    -- draw closest resource
    if closest_reachable_resource then
        ui_ids[#ui_ids + 1] = rendering.draw_circle(
                                  {
                color = defines.color.red,
                radius = 1,
                width = 2,
                filled = false,
                target = closest_reachable_resource.position,
                target_offset = {0, 0},
                surface = player.surface,
                players = {player.index},
                visible = true,
                draw_on_ground = true,
            })
    end

    -- draw closest building
    if closest_reachable_building then
        ui_ids[#ui_ids + 1] = rendering.draw_circle(
                                  {
                color = defines.color.orange,
                radius = 0.5,
                width = 2,
                filled = false,
                target = closest_reachable_building.position,
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
