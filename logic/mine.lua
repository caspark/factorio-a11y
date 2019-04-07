local Area = require("__stdlib__/stdlib/area/area")
local Event = require("__stdlib__/stdlib/event/event")
local Game = require("__stdlib__/stdlib/game")
local Position = require("__stdlib__/stdlib/area/position")

local Categories = require("utils/categories")

local function request_ui_rerender(player)
    Game.get_or_set_data("ui", player.index, "force_rerender", true, true)
end

local M = {}

function M.get_closest_reachable_resource(player)
    local resource_reach_area =
        Area.adjust(
        {player.position, player.position},
        {player.resource_reach_distance, player.resource_reach_distance}
    )
    local all_resources =
        player.surface.find_entities_filtered {area = resource_reach_area, type = Categories.resource_prototypes}

    local closest_resource = nil
    local closest_dist = math.huge
    if all_resources then
        for k, res in pairs(all_resources) do
            local d = Position.distance_squared(player.position, res.position)
            if d < closest_dist and player.can_reach_entity(res) then
                closest_dist = d
                closest_resource = res
            end
        end
    end
    return closest_resource
end

function M.get_closest_reachable_building(player)
    local reach_area = Area.adjust({player.position, player.position}, {player.reach_distance, player.reach_distance})
    local all_buildings =
        player.surface.find_entities_filtered {
        area = reach_area,
        type = Categories.building_prototypes
    }
    local closest_building = nil
    local closest_dist = math.huge
    if all_buildings then
        for k, building in pairs(all_buildings) do
            local d = Position.distance_squared(player.position, building.position)
            if d < closest_dist and player.can_reach_entity(building) then
                closest_dist = d
                closest_building = building
            end
        end
    end
    return closest_building
end

-- render a UI around the player showing their reach
function M.render_ui(player)
    local ui_last_player_pos = Game.get_or_set_data("ui", player.index, "last_player_pos", false, {x = nil, y = nil})
    local ui_force_rerender = Game.get_or_set_data("ui", player.index, "force_rerender", false, false)
    if player.position.x == ui_last_player_pos.x and player.position.y == ui_last_player_pos.y and not ui_force_rerender then
        -- bail out to avoid rerendering when position has not changed
        return
    else
        -- update position to avoid unnecessary work next time
        ui_last_player_pos.x = player.position.x
        ui_last_player_pos.y = player.position.y
        -- and flush rerender flag
        Game.get_or_set_data("ui", player.index, "force_rerender", true, false)
    end

    local color_grid_background = {r = 0, g = 0, b = 0, a = 0.4}
    local normal_reach = player.reach_distance
    local resource_reach = player.resource_reach_distance

    local normal_reach_area = Area.adjust({player.position, player.position}, {normal_reach, normal_reach})
    local resource_reach_area = Area.adjust({player.position, player.position}, {resource_reach, resource_reach})

    local closest_reachable_resource = M.get_closest_reachable_resource(player)
    local closest_reachable_building = M.get_closest_reachable_building(player)

    -- get a reference to the grid table, remove any existing drawings, then save new drawings in it
    local ui_ids = Game.get_or_set_data("ui", player.index, "ui_ids", false, {})
    for k, ui_id in pairs(ui_ids) do
        rendering.destroy(ui_id)
        ui_ids[k] = nil
    end

    -- draw the grid
    ui_ids[#ui_ids + 1] =
        rendering.draw_rectangle {
        color = color_grid_background,
        filled = true,
        left_top = {normal_reach_area.left_top.x, normal_reach_area.left_top.y},
        right_bottom = {normal_reach_area.right_bottom.x, normal_reach_area.right_bottom.y},
        surface = player.surface,
        draw_on_ground = true
    }

    -- render mining reach
    ui_ids[#ui_ids + 1] =
        rendering.draw_circle(
        {
            color = defines.color.green,
            radius = resource_reach,
            width = 2,
            filled = false,
            target = player.position,
            target_offset = {0, 0},
            surface = player.surface,
            players = {player.index},
            visible = true,
            draw_on_ground = true
        }
    )

    -- render normal reach for comparison
    ui_ids[#ui_ids + 1] =
        rendering.draw_circle(
        {
            color = defines.color.green,
            radius = normal_reach,
            width = 2,
            filled = false,
            target = player.position,
            target_offset = {0, 0},
            surface = player.surface,
            players = {player.index},
            visible = true,
            draw_on_ground = true
        }
    )

    -- draw closest resource
    if closest_reachable_resource then
        ui_ids[#ui_ids + 1] =
            rendering.draw_circle(
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
                draw_on_ground = true
            }
        )
    end

    -- draw closest building
    if closest_reachable_building then
        ui_ids[#ui_ids + 1] =
            rendering.draw_circle(
            {
                color = defines.color.orange,
                radius = 1,
                width = 2,
                filled = false,
                target = closest_reachable_building.position,
                target_offset = {0, 0},
                surface = player.surface,
                players = {player.index},
                visible = true,
                draw_on_ground = false
            }
        )
    end

    -- render last provided path
    local waypoints = Game.get_or_set_data("pathfinder", player.index, "path_to_follow", false, nil)
    if waypoints then
        local progress =
            Game.get_or_set_data("pathfinder", player.index, "path_progress", false, {waypoint = 0, dist = nil})
        for i, waypoint in ipairs(waypoints) do
            if i >= progress.waypoint then
                ui_ids[#ui_ids + 1] =
                    rendering.draw_circle(
                    {
                        color = defines.color.lightblue,
                        radius = 0.2,
                        width = 2,
                        filled = false,
                        target = waypoint.position,
                        target_offset = {0, 0},
                        surface = player.surface,
                        players = {player.index},
                        visible = true,
                        draw_on_ground = true
                    }
                )
            end
        end
    end
end

Event.register(
    defines.events.on_player_mined_item,
    function(event)
        local player = game.players[event.player_index]
        request_ui_rerender(player)
    end
)

return M
