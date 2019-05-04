local Event = require("__stdlib__/stdlib/event/event")
local Game = require("__stdlib__/stdlib/game")
local Is = require("__stdlib__/stdlib/utils/is")
local Position = require("__stdlib__/stdlib/area/position")

local M = {}

-- replace whatever the user has grabbed with the runtool.
function M.grab_runtool(player)
    if player.clean_cursor() then
        player.cursor_stack.set_stack({name = "runtool"})
    end
end

-- if the player is moving along a path, stop moving them along it.
function M.stop_moving_player_along_path(player)
    Game.get_or_set_data("ui", player.index, "force_rerender", true, true)
    Game.get_or_set_data("run", player.index, "path_to_follow", true, nil)
    Game.get_or_set_data("run", player.index, "path_progress", true, nil)
end

-- try to calculate a path from the given player to the given target
-- target can be either a Position or a LuaEntity
function M.run_to_target(player, target)
    M.stop_moving_player_along_path(player)

    -- we can't path from the player's exact position, presumably because the player is an obstacle itself
    -- so instead we find a position near the player which we can path from
    local start_pos =
        player.surface.find_non_colliding_position(
        "character", -- prototype name
        player.position, -- center
        .7, -- radius
        0.01, -- precision for search (step size)
        false -- force_to_tile_center
    )
    if not start_pos then
        player.print("No valid starting position for path!")
        return
    end

    local target_position
    local how_close = 0

    if Is.Object(target) then
        target_position = target.position

        if target.prototype.collision_mask ~= nil and target.prototype.collision_mask["player-layer"] then
            -- since this target can collide with the player, we need to figure out its edges and use
            -- that to modify how close we try to get
            local target_box = target.prototype.collision_box

            local left_top = target_box.left_top
            local right_top = {x = target_box.right_bottom.x, y = target_box.left_top.y}
            local right_bottom = target_box.right_bottom
            local left_bottom = {x = target_box.left_top.x, y = target_box.right_bottom.y}
            local corners = {left_top, right_top, right_bottom, left_bottom}
            local furthest_corner = nil
            local furthest_corner_dist = nil
            for _, corner in pairs(corners) do
                local dist = Position.distance({x = 0.0, y = 0.0}, corner)
                if furthest_corner == nil or furthest_corner_dist < dist then
                    furthest_corner = corner
                    furthest_corner_dist = dist
                end
            end
            how_close = furthest_corner_dist + .3
        end
    elseif Is.Position(target) then
        target_position = target
    else
        player.print("Unrecognized target to run to: " .. serpent.block(target))
        return
    end

    local path_id =
        player.surface.request_path {
        bounding_box = player.character.prototype.collision_box,
        collision_mask = {"player-layer"},
        start = start_pos,
        goal = target_position,
        force = player.force,
        radius = how_close,
        pathfind_flags = {
            allow_destroy_friendly_entities = false,
            cache = false,
            prefer_straight_paths = false, -- we don't want paths with right angles here
            low_priority = false
        },
        can_open_gates = true,
        -- resolution of >= 3 seems to be necessary to allow the player to run between
        -- side-by-side assembly machines.
        path_resolution_modifier = 3
    }
    Logger.log(
        "Issued pathfinding request to " ..
            target_position.x .. "," .. target_position.y .. " (request-id: " .. path_id .. ")"
    )
    Game.get_or_set_data("run", player.index, "last_path_id", true, path_id)
end

function M.try_move_player_along_path(player)
    local path = Game.get_or_set_data("run", player.index, "path_to_follow", false, nil)
    if not path then
        return
    end

    local first_waypoint = path[0]
    if not first_waypoint then
        player.print("Found a path but it doesn't have a 0th waypoint!")
        return
    end
    local progress = Game.get_or_set_data("run", player.index, "path_progress", false, {waypoint = 0})

    -- Move the player along the path in steps. This is tricky because we need to respect the player's
    -- speed each step of the way, which is influenced by their position (due to concrete). To do this,
    -- we introduce the concept of "travel power" (the fraction of their unused speed this tick) and
    -- "travel dist" (the actual distance the player can travel still, based on applying their travel
    -- power to their current speed).
    -- Also, to avoid overshooting waypoints, each step is sized as the smaller of the player's travel
    -- dist and the current player pos<->next waypoint pos.
    local travel_power_left = 1.0 -- fraction
    local next_waypoint = path[progress.waypoint]

    while (travel_power_left > 0 and next_waypoint ~= nil) do
        local old_player_pos = player.position
        local next_waypoint_dist = Position.distance(old_player_pos, next_waypoint.position)
        local travel_dist_left = travel_power_left * player.character_running_speed

        local new_player_pos
        if travel_dist_left >= next_waypoint_dist then
            -- this step is moving the player straight to the next waypoint
            new_player_pos = next_waypoint.position
            -- now make progress towards the next waypoint
            progress.waypoint = progress.waypoint + 1
            next_waypoint = path[progress.waypoint]
        else
            -- in this step we just move the player as far we can towards the next waypoint
            local distance_remaining = next_waypoint_dist - travel_dist_left
            new_player_pos = Position.offset_along_line(old_player_pos, next_waypoint.position, distance_remaining)
        end

        -- Actually move the player; unfortunately we there's no API to "run" them, so teleport instead.
        -- This also means there's no walking animation or noise unfortunately, but oh well.
        player.teleport(new_player_pos)

        local travel_dist_used = Position.distance(old_player_pos, new_player_pos)
        if travel_dist_used >= travel_dist_left then
            -- Sometimes (due to floating point imprecision?) we travel more distance than we should
            -- be able to, so just wipe out all our travel power in this case.
            travel_power_left = 0
        elseif travel_dist_used > 0 then
            travel_power_left = travel_power_left - (travel_dist_left / travel_dist_used)
        end
    end

    if not next_waypoint then
        Logger.log("Done moving player along path; ended up at " .. player.position.x .. "," .. player.position.y)
        M.stop_moving_player_along_path(player)
    end
end

function M.render_ui(player)
    local ui_last_player_pos =
        Game.get_or_set_data("run", player.index, "ui_last_player_pos", false, {x = nil, y = nil})
    local ui_force_rerender = Game.get_or_set_data("run", player.index, "ui_force_rerender", false, false)
    if player.position.x == ui_last_player_pos.x and player.position.y == ui_last_player_pos.y and not ui_force_rerender then
        -- bail out to avoid rerendering when position has not changed
        return
    else
        -- update position to avoid unnecessary work next time
        ui_last_player_pos.x = player.position.x
        ui_last_player_pos.y = player.position.y
        -- and flush rerender flag
        Game.get_or_set_data("run", player.index, "force_rerender", true, false)
    end

    -- get a reference to the UI state, remove any existing drawings, then save new drawings in it
    local ui_ids = Game.get_or_set_data("run", player.index, "ui_ids", false, {})
    for k, ui_id in pairs(ui_ids) do
        rendering.destroy(ui_id)
        ui_ids[k] = nil
    end

    -- render last provided path
    local waypoints = Game.get_or_set_data("run", player.index, "path_to_follow", false, nil)
    if waypoints then
        local progress = Game.get_or_set_data("run", player.index, "path_progress", false, {waypoint = 0, dist = nil})
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

function M.register_event_handlers()
    Event.register(
        defines.events.on_script_path_request_finished,
        function(event)
            local path_id = event.id
            for _, player in pairs(game.players) do
                if path_id == Game.get_or_set_data("run", player.index, "last_path_id", true, path_id) then
                    if event.try_again_later then
                        player.print("Pathfinder was too busy - got try again later result for pathfinding")
                    else
                        -- player.print("Got paths of " .. serpent.block(event))
                        if event.path then
                            -- update the path to have a 0th waypoint which is the player's current position
                            -- (necessary to avoid a jerk at the start of pathing since the path needs to
                            -- start outside the player's collision box)
                            event.path[0] = {position = player.position, needs_destroy_to_reach = false}
                        else
                            player.print("Failed to find path!")
                        end

                        Game.get_or_set_data("run", player.index, "path_to_follow", true, event.path)
                    end
                end
            end
        end
    )

    Event.register(
        {
            defines.events.on_player_selected_area,
            defines.events.on_player_alt_selected_area
        },
        function(e)
            if e.item ~= "runtool" then
                return
            end
            local player = game.players[e.player_index]
            local area = e.area

            local selected_entities = player.surface.find_entities(area)

            if #selected_entities > 0 then
                local target = selected_entities[1]
                player.print("Running to selected " .. q(target.name))
                M.run_to_target(player, target)
            elseif player.selected ~= nil then
                local target = player.selected
                player.print("Running to highlighted " .. q(target.name))
                M.run_to_target(player, target)
            else
                local target = area.left_top
                player.print("Running to position " .. target.x .. "," .. target.y)
                M.run_to_target(player, target)
            end
        end
    )

    Event.register(
        {
            "a11y-hook-player-walked-up",
            "a11y-hook-player-walked-right",
            "a11y-hook-player-walked-down",
            "a11y-hook-player-walked-left"
        },
        function(event)
            M.stop_moving_player_along_path(game.players[event.player_index])
        end
    )
end

return M
