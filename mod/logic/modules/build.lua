require('__stdlib__/stdlib/utils/defines/color')
local Area = require("__stdlib__/stdlib/area/area")
local Event = require("__stdlib__/stdlib/event/event")
local Game = require("__stdlib__/stdlib/game")
local Memoize = require("__stdlib__/stdlib/vendor/memoize")
local Position = require("__stdlib__/stdlib/area/position")
local Table = require("__stdlib__/stdlib/utils/table")

-- TODO document this entire module's behavior in the readme

-- TODO need to actually call this
local function clear_build_history(player)
    player.print('clearing build history')
    Game.get_or_set_data("build", player.index, "last_build", true, nil)
end

local function draw_block(player, color, area)
    rendering.draw_rectangle({
        color = color,
        width = 2,
        filled = false,
        left_top = area.left_top,
        right_bottom = area.right_bottom,
        surface = player.surface,
        time_to_live = 60 * 15,
        players = {player.index},
        draw_on_ground = true,
    })
end

local function extend_build(player, building_item, building_position, building_direction)
    local build_history = Game.get_or_set_data("build", player.index, "last_build", false, nil)

    local building_prototype = game.entity_prototypes[building_item]

    player.print("extendbuild: " .. building_position.x .. ',' .. building_position.y .. ' dir='
                     .. building_direction .. " item: " .. q(building_item) .. " prototype type: "
                     .. building_prototype.type)

    local surface = player.surface

    local building_box = Area.construct(building_position.x
                                            + building_prototype.selection_box.left_top.x,
                                        building_position.y
                                            + building_prototype.selection_box.left_top.y,
                                        building_position.x
                                            + building_prototype.selection_box.right_bottom.x,
                                        building_position.y
                                            + building_prototype.selection_box.right_bottom.y)
    local width = building_prototype.selection_box.right_bottom.x
                      - building_prototype.selection_box.left_top.x
    local height = building_prototype.selection_box.right_bottom.y
                       - building_prototype.selection_box.left_top.y

    -- TODO it's probably more helpful to always show the guide on every build? (but only complete builds on shift-click)
    local guide_dirs = {{width, 0}, {-width, 0}, {0, height}, {0, -height}}
    for _, direction in pairs(guide_dirs) do
        -- TODO display a longer guide for smaller items, like belts?
        for i = 1, 10 do
            local offset = Position.multiply(direction, {i, i})
            local new_pos = Position.add(offset, building_position)
            local new_area = Area.offset(building_box, offset)
            if surface.can_place_entity{
                name = building_item,
                position = new_pos,
                direction = building_direction,
                force = player.force,
                build_check_type = defines.build_check_type.ghost_place,
                forced = true,
            } then
                draw_block(player, defines.color.yellow, new_area)
            else
                break
            end
        end
    end

    if build_history ~= nil and build_history.position.x == building_position.x
        or build_history.position.y == building_position.y then

        local offset = Position.subtract(building_position, build_history.position)
        offset = Position.divide(offset, {width, height})

        if offset == Position.round(offset) then
            -- we have an even division, all buildings should fit
            local increment = Position.trim(offset, 1)
            local abs_offset = Position.abs(offset)
            local magnitude = abs_offset.x > abs_offset.y and abs_offset.x or abs_offset.y

            -- check whether we can build all buildings in a line from history to here
            local can_build_all = true
            for i = 1, magnitude - 1 do
                local initial_pos = Position.new(build_history.position) -- to avoid mutating original
                local check_pos = Position.add(initial_pos, Position.multiply(
                                                   Position.multiply(increment, {i, i}),
                                                   {width, height}))

                -- TODO this isn't actually catching cases where the player is standing in the way
                can_build_all = can_build_all and surface.can_place_entity{
                    name = building_item,
                    position = check_pos,
                    direction = building_direction,
                    force = player.force,
                    build_check_type = defines.build_check_type.ghost_place,
                    forced = true,
                }
            end

            -- actually build the buildings
            if can_build_all then
                for i = 1, magnitude - 1 do
                    local initial_pos = Position.new(build_history.position) -- to avoid mutating original
                    local check_pos = Position.add(initial_pos, Position.multiply(
                                                       Position.multiply(increment, {i, i}),
                                                       {width, height}))

                    local check_box = Area.new(building_prototype.selection_box)
                    check_box = Area.offset(check_box, check_pos)
                    draw_block(player, defines.color.green, check_box)
                    -- TODO how does this behave when the player has 2 items and we need 3 to fill the gap?
                    if player.can_build_from_cursor{
                        position = check_pos,
                        direction = building_direction,
                    } then
                        -- TODO we should be building ghosts here instead of the real thing
                        player.build_from_cursor{
                            position = check_pos,
                            direction = building_direction,
                        }
                    end
                end
            end
        end
    end

    Game.get_or_set_data("build", player.index, "last_build", true, {
        item = building_item,
        position = building_position,
        direction = building_direction,
    })
end

local M = {}

function M.register_event_handlers()
    Event.register(defines.events.on_put_item, function(event)
        local player = game.players[event.player_index]

        if event.shift_build then
            extend_build(player, player.cursor_stack.name, event.position, event.direction)
        end
    end)

    Event.register(defines.events.on_player_cursor_stack_changed, function(event)
        local player = game.players[event.player_index]

        -- TODO should clear the guide when this happens, but only if the user's cursor has changed to another item
        -- player.print('cursor stack chanqged: ' .. serpent.block(event))
        -- clear_build_history(player)
    end)
end

return M
