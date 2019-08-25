local Event = require("__stdlib__/stdlib/event/event")
local Game = require("__stdlib__/stdlib/game")
local Is = require("__stdlib__/stdlib/utils/is")
local Position = require("__stdlib__/stdlib/area/position")
local Table = require("__stdlib__/stdlib/utils/table")

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

    -- The path's collision mask determines what things <the thing that travels along the path>
    -- would collide with, and hence the things that need to be pathed around.
    local path_collion_mask = Table.keys(player.character.prototype.collision_mask)
    -- We need "not-colliding-with-itself" to be in effect so the path doesn't "collide with"
    -- the player (https://wiki.factorio.com/Types/CollisionMask#.22not-colliding-with-itself.22),
    -- but:
    -- a) that only happens if both the player's character and the path have the layer
    --    "not-colliding-with-itself" set on their collision mask
    -- b) "not-colliding-with-itself" is kind of a fake layer that gets moved to a property
    --    on the entity later ("collision_mask_collides_with_self" on LuaPrototype)
    -- So, first we check that the player's character is set up correctly to have the
    -- "not-colliding-with-itself" flag set (a11y should have configured this itself in
    -- its data-updates.lua).
    local start_pos
    if not player.character.prototype.collision_mask_collides_with_self then
        -- Since it's set on the player, we need to manually insert "not-colliding-with-itself"
        -- into the collision layer of the path, and we can start the path immediately at the
        -- player's character's position.
        Table.insert(path_collion_mask, "not-colliding-with-itself")
        start_pos = player.character.position
    else
        -- If it is not set on the player character (happens when e.g. a mod has swapped out the
        -- character of the player), then the path will collide with the player, which causes no
        -- path to be found (because the start of the path itself is blocked by the player).
        -- So in this case, fall back to the alternative approach of finding a place
        -- for the path to start which is at least near the player. This will manifest in the
        -- character sometimes running a little way in the wrong direction when pathing to a
        -- location (because the start position for the path is going to be approximately
        -- <player bounding box's radius> away from the player and not necessarily in the
        -- direction of the destination).
        start_pos = player.surface.find_non_colliding_position("character", -- prototype name
        player.position, -- center
        .7, -- radius
        0.01, -- precision for search (step size)
        false -- force_to_tile_center
        )
        Logger.log("Player's character collides with self so found alternative start pos of "
                       .. start_pos.x .. "," .. start_pos.y)
    end

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

    local path_id = player.surface.request_path{
        bounding_box = player.character.prototype.collision_box,
        collision_mask = path_collion_mask,
        -- {
        --     "player-layer",
        --     "train-layer",
        --     "consider-tile-transitions",
        --     "not-colliding-with-itself"
        -- },
        start = start_pos,
        goal = target_position,
        force = player.force,
        radius = how_close,
        pathfind_flags = {
            allow_destroy_friendly_entities = false,
            cache = false,
            prefer_straight_paths = false, -- we don't want paths with right angles here
            low_priority = false,
        },
        can_open_gates = true,
        -- resolution of >= 3 seems to be necessary to allow the player to run between
        -- side-by-side assembly machines.
        path_resolution_modifier = 3,
    }
    Logger.log("Issued pathfinding request to " .. target_position.x .. "," .. target_position.y
                   .. " (request-id: " .. path_id .. ")")
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
    local progress = Game.get_or_set_data("run", player.index, "path_progress", false,
                                          {waypoint = 0})

    local next_waypoint = path[progress.waypoint]
    local old_player_pos = player.position
    local next_waypoint_dist = Position.distance(old_player_pos, next_waypoint.position)

    -- Find the next waypoint to move the character towards which is at least <running speed>
    -- away from the player (to avoid overshooting the target waypoint).
    -- Theoretically it's possible the player may end up stuck ping ponging between 2
    -- waypoints here still, but let's see if that's a problem in practice first.
    while next_waypoint ~= nil and next_waypoint_dist <= player.character_running_speed do
        progress.waypoint = progress.waypoint + 1
        next_waypoint = path[progress.waypoint]
        if next_waypoint == nil then
            Logger.log("Done moving player along path; ended up at " .. player.position.x .. ","
                           .. player.position.y)
            M.stop_moving_player_along_path(player)
            return
        end
        next_waypoint_dist = Position.distance(old_player_pos, next_waypoint.position)
    end

    -- Make the player walk for one tick in the right direction
    local dir_to_walk = Position.complex_direction_to(old_player_pos, next_waypoint.position, true)
    player.character.walking_state = {walking = true, direction = dir_to_walk}
end

function M.render_ui(player)
    local ui_last_player_pos = Game.get_or_set_data("run", player.index, "ui_last_player_pos",
                                                    false, {x = nil, y = nil})
    local ui_force_rerender = Game.get_or_set_data("run", player.index, "ui_force_rerender", false,
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
        local progress = Game.get_or_set_data("run", player.index, "path_progress", false,
                                              {waypoint = 0, dist = nil})
        for i, waypoint in ipairs(waypoints) do
            if i >= progress.waypoint then
                ui_ids[#ui_ids + 1] = rendering.draw_circle{
                    color = defines.color.lightblue,
                    radius = 0.1,
                    width = 2, -- min width=2 (if radius=0.1) for path to be visible when zoomed out
                    filled = false,
                    target = waypoint.position,
                    target_offset = {0, 0},
                    surface = player.surface,
                    players = {player.index},
                    visible = true,
                    draw_on_ground = true,
                }
            end
        end
    end
end

function M.register_event_handlers()
    Event.register(defines.events.on_script_path_request_finished, function(event)
        local path_id = event.id
        for _, player in pairs(game.players) do
            if path_id == Game.get_or_set_data("run", player.index, "last_path_id", true, path_id) then
                if event.try_again_later then
                    player.print(
                        "Pathfinder was too busy - got try again later result for pathfinding")
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
    end)

    Event.register({
        defines.events.on_player_selected_area, defines.events.on_player_alt_selected_area,
    }, function(e)
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
    end)

    Event.register({
        "a11y-hook-player-walked-up", "a11y-hook-player-walked-right",
        "a11y-hook-player-walked-down", "a11y-hook-player-walked-left",
    }, function(event)
        M.stop_moving_player_along_path(game.players[event.player_index])
    end)
end

return M
