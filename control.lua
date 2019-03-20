local Area = require("__stdlib__/stdlib/area/area")
local Entity = require("__stdlib__/stdlib/entity/entity")
local Event = require("__stdlib__/stdlib/event/event")
local table = require("__stdlib__/stdlib/utils/table")
local Game = require("__stdlib__/stdlib/game")
local Player = require("__stdlib__/stdlib/event/player").register_events()
local Position = require("__stdlib__/stdlib/area/position")

-- helper to quote a string in single quotes
function q(s)
    return "'" .. s .. "'"
end

function get_closest_mineable_resource(player)
    local resource_reach_area =
        Area.adjust(
        {player.position, player.position},
        {player.resource_reach_distance, player.resource_reach_distance}
    )
    local closest_resource = nil
    local closest_dist = 100000
    local all_resources =
        player.surface.find_entities_filtered {area = resource_reach_area, type = {"resource", "tree"}}
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

function request_ui_rerender(player)
    Game.get_or_set_data("ui", player.index, "force_rerender", true, true)
end

-- render a UI around the player showing their reach
function render_ui(player)
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

    local closest_resource = get_closest_mineable_resource(player)

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

    -- draw closest resource
    if closest_resource then
        ui_ids[#ui_ids + 1] =
            rendering.draw_circle(
            {
                color = defines.color.red,
                radius = 1,
                width = 2,
                filled = false,
                target = closest_resource.position,
                target_offset = {0, 0},
                surface = player.surface,
                players = {player.index},
                visible = true,
                draw_on_ground = true
            }
        )
    end

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

function stop_moving_player_along_path(player)
    request_ui_rerender(player)
    Game.get_or_set_data("pathfinder", player.index, "path_to_follow", true, nil)
    Game.get_or_set_data("pathfinder", player.index, "path_progress", true, nil)
end

function try_move_player_along_path(player)
    local path = Game.get_or_set_data("pathfinder", player.index, "path_to_follow", false, nil)
    if not path then
        return
    end

    local first_waypoint = path[0]
    if not first_waypoint then
        player.print("Found a path but it doesn't have a 0th waypoint!")
        return
    end
    local progress =
        Game.get_or_set_data("pathfinder", player.index, "path_progress", false, {waypoint = 0, dist = nil})
    local curr_waypoint = path[progress.waypoint]
    local next_waypoint = path[progress.waypoint + 1]

    if not curr_waypoint or not next_waypoint then
        -- done pathfinding, clear the path to follow
        stop_moving_player_along_path(player)
        return
    end
    if progress.dist_remaining == nil then
        -- new waypoint, stash how much distance we need to move
        progress.dist_remaining = Position.distance(curr_waypoint.position, next_waypoint.position)
    end
    -- move the player along the path
    progress.dist_remaining = progress.dist_remaining - player.character_running_speed
    -- local new_player_pos = Position.lerp(curr_waypoint.position, next_waypoint.position, progress.dist_remaining)
    local new_player_pos =
        Position.offset_along_line(curr_waypoint.position, next_waypoint.position, progress.dist_remaining)
    player.teleport(new_player_pos)
    if progress.dist_remaining <= 0 then
        -- move on to the next waypoint
        -- FIXME for sufficiently high player speeds or fine grained paths, this resetting results in "losing" part
        --       of your progress towards the next waypoint so what we should really do is keep going to further
        --       waypoints and decrementing dist_remaining until dist_remaining reaches zero (or we run out of waypoints)
        progress.dist_remaining = nil
        progress.waypoint = progress.waypoint + 1
    end
end

-- get an item from inventory by name
function grab(player, item_name)
    local ok, stack =
        pcall(
        function()
            return player.get_main_inventory().find_item_stack(item_name)
        end
    )
    if ok and stack then
        local stack_count = stack.count
        player.clean_cursor()
        if player.cursor_stack.transfer_stack(stack) then
            player.print("Grabbed " .. stack_count .. " of " .. q(item_name) .. "")
        else
            player.print("We have " .. stack_count .. " of " .. q(item_name) " but couldn't grab it :(")
        end
    else
        player.print("No " .. q(item_name) .. " found in inventory")
    end
end

-- being crafting a given item for a given count
function start_crafting(player, opts)
    setmetatable(opts, {__index = {count = 5}})
    local item_name = opts.item_name
    local count_asked = opts.count

    local count_available = player.get_craftable_count(item_name)
    if count_available == 0 then
        player.print("Missing ingredients for crafting any " .. q(item_name))
    elseif count_available < count_asked then
        -- we can't craft them all, but craft as many as we can
        local count_crafting = player.begin_crafting {recipe = item_name, count = count_available}
        player.print("Crafting " .. count_available .. " (not " .. count_asked .. ") of " .. q(item_name))
    else
        player.begin_crafting {recipe = item_name, count = count_asked}
    end
end

-- print out the name of the held or selected item
function explain_selection(player)
    if player.cursor_stack and player.cursor_stack.valid_for_read then
        player.print("That is " .. q(player.cursor_stack.name) .. " (cursor stack)")
    elseif player.selected then
        player.print("That is " .. q(player.selected.name) .. " (selected)")
    else
        player.print("No idea what that is :(")
    end
end

-- mine the item under the cursor instantly
-- (would be nice to do a regular mining action but doesn't seem possible
-- without locking cursor into place and hold right click, which is very
-- annoying when using eye tracking!)
function mine_selection(player)
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
        player.print("Mined a " .. q(target_name))
    end
end

-- mine the resource or tree closest to the player instantly
-- (again, would be nice to do a regular mining action but doesn't seem possible)
function mine_closest_resource(player)
    local target = get_closest_mineable_resource(player)
    if not target then
        player.print("No resource in range to mine!")
        return
    end
    local target_name = target.prototype.name
    if not player.can_reach_entity(target) then
        player.print("That " .. q(target_name) .. " is too far away to mine!")
        return
    end
    if player.mine_entity(target) then
        player.print("Mined a " .. q(target_name))
    end
end

-- mine the tile which the player is standing on
function mine_tile_under_player(player)
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

function run_to_selection(player)
    stop_moving_player_along_path(player)

    local target = player.selected
    if not target then
        player.print("No cursor selection to move to!")
        return
    end

    -- we can't path from the player's exact position, presumably because the player is an obstacle itself
    -- so instead we find a position near the player which we can path from
    local start_pos =
        player.surface.find_non_colliding_position(
        -- FIXME it'd be better to use something that's exactly the size of the player's bounding box (0.4x0.4)
        "wooden-chest", -- prototype name
        player.position, -- center
        .7, -- radius
        0.01, -- precision for search (step size)
        false -- force_to_tile_center
    )
    if not start_pos then
        player.print("No valid starting position for path!")
        return
    end

    local how_close = 0
    if target.prototype.collision_mask["player-layer"] then
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
        player.print("Closeness " .. serpent.block(furthest_corner_dist))
    end

    local path_id =
        player.surface.request_path {
        bounding_box = {{-0.2, -0.2}, {0.2, 0.2}}, -- player's collision box according to data.raw
        collision_mask = {"player-layer"},
        start = start_pos,
        goal = target.position,
        force = player.force,
        radius = how_close,
        pathfind_flags = {
            allow_destroy_friendly_entities = false,
            cache = false,
            prefer_straight_paths = true,
            low_priority = false
        },
        can_open_gates = true,
        path_resolution_modifier = 1
    }
    player.print(
        "Issued pathfinding request to " ..
            target.position.x .. "," .. target.position.y .. " (request-id: " .. path_id .. ")"
    )
    Game.get_or_set_data("pathfinder", player.index, "last_path_id", true, path_id)
end

-- ********* Event Handlers *********

-- it'd be nice to use on_player_changed_position, but that only fires when the player has
-- moved onto a discrete new tile
Event.register(
    defines.events.on_tick,
    function(event)
        for _, player in pairs(game.players) do
            try_move_player_along_path(player)
            render_ui(player)
        end
    end
)
Event.register(
    defines.events.on_script_path_request_finished,
    function(event, dog)
        local path_id = event.id
        for _, player in pairs(game.players) do
            if path_id == Game.get_or_set_data("pathfinder", player.index, "last_path_id", true, path_id) then
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

                    Game.get_or_set_data("pathfinder", player.index, "path_to_follow", true, event.path)
                end
            end
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
        stop_moving_player_along_path(game.players[event.player_index])
    end
)

-- simple hotkey mappings
local hotkey_actions = {
    ["a11y-hotkey-explain-selection"] = explain_selection,
    ["a11y-hotkey-run-to-selection"] = run_to_selection,
    ["a11y-hotkey-mine-selection"] = mine_selection,
    ["a11y-hotkey-mine-closest-resouce"] = mine_closest_resource,
    ["a11y-hotkey-mine-tile-under-player"] = mine_tile_under_player
}
Event.register(
    table.keys(hotkey_actions),
    function(event)
        hotkey_actions[event.input_name](game.players[event.player_index])
    end
)
