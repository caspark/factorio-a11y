require('__stdlib__/stdlib/utils/defines/color')
local Area = require("__stdlib__/stdlib/area/area")
local Event = require("__stdlib__/stdlib/event/event")
local Game = require("__stdlib__/stdlib/game")
local Memoize = require("__stdlib__/stdlib/vendor/memoize")
local Position = require("__stdlib__/stdlib/area/position")
local Table = require("__stdlib__/stdlib/utils/table")

-- TODO document this entire module's behavior in the readme

local function reset_build_history(player, build_history)
    local guide_handles = Game.get_or_set_data("build", player.index, "guide_ui_handles", false, {})
    for _, handle in pairs(guide_handles) do
        rendering.destroy(handle)
    end

    Game.get_or_set_data("build", player.index, "last_build", true, build_history)
end

local function draw_block(player, color, area)
    return rendering.draw_rectangle({
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

local function calc_entity_width_and_height(entity_prototype_name)
    local building_prototype = game.entity_prototypes[entity_prototype_name]
    local width = math.ceil(building_prototype.selection_box.right_bottom.x
                                - building_prototype.selection_box.left_top.x)
    local height = math.ceil(building_prototype.selection_box.right_bottom.y
                                 - building_prototype.selection_box.left_top.y)
    return width, height
end

local function render_guide_ui(player, building_item, building_position, building_direction)
    local max_guide_length_in_tiles = 50 -- how long in tiles should the guide extend to either side?

    local building_prototype = game.entity_prototypes[building_item]
    local building_box = Area.construct(building_position.x
                                            + building_prototype.selection_box.left_top.x,
                                        building_position.y
                                            + building_prototype.selection_box.left_top.y,
                                        building_position.x
                                            + building_prototype.selection_box.right_bottom.x,
                                        building_position.y
                                            + building_prototype.selection_box.right_bottom.y)
    local width, height = calc_entity_width_and_height(building_item)
    local guide_dirs = {{width, 0}, {-width, 0}, {0, height}, {0, -height}}
    local guide_handles = {}
    local max_guide_width = math.floor(max_guide_length_in_tiles / width)
    local max_guide_height = math.floor(max_guide_length_in_tiles / height)
    local max_guide_length = {max_guide_width, max_guide_width, max_guide_height, max_guide_height}
    for dir_i, direction in pairs(guide_dirs) do
        for i = 1, max_guide_length[dir_i] do
            local offset = Position.multiply(direction, {i, i})
            local new_pos = Position.add(offset, building_position)
            local new_area = Area.offset(building_box, offset)
            if player.surface.can_place_entity{
                name = building_item,
                position = new_pos,
                direction = building_direction,
                force = player.force,
                build_check_type = defines.build_check_type.ghost_place,
                forced = false,
            } then
                table.insert(guide_handles, draw_block(player, defines.color.yellow, new_area))
            else
                break
            end
        end
    end
    return guide_handles
end

local function extend_build(player, building_item, building_position, building_direction,
                            shift_build)
    local width, height = calc_entity_width_and_height(building_item)
    local build_history = Game.get_or_set_data("build", player.index, "last_build", false, nil)

    reset_build_history(player, {
        item = building_item,
        position = building_position,
        direction = building_direction,
    })

    local guide_handles = render_guide_ui(player, building_item, building_position,
                                          building_direction)
    Game.get_or_set_data("build", player.index, "guide_ui_handles", true, guide_handles)

    if shift_build and build_history ~= nil
        and (build_history.position.x == building_position.x or build_history.position.y
            == building_position.y) then
        player.print('line building triggered')

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

                can_build_all = can_build_all and player.surface.can_place_entity{
                    name = building_item,
                    position = check_pos,
                    direction = building_direction,
                    force = player.force,
                    build_check_type = defines.build_check_type.ghost_place,
                    forced = false,
                }
            end

            -- actually build the buildings
            if can_build_all then
                for i = 1, magnitude - 1 do
                    local initial_pos = Position.new(build_history.position) -- to avoid mutating original
                    local check_pos = Position.add(initial_pos, Position.multiply(
                                                       Position.multiply(increment, {i, i}),
                                                       {width, height}))

                    player.surface.create_entity{
                        name = 'entity-ghost',
                        position = check_pos,
                        direction = build_history.direction,
                        force = player.force,
                        player = player,
                        raise_built = true,
                        -- ghost specific params
                        inner_name = building_item,
                        expires = false,
                    }
                end
            end
        end
    end
end

local M = {}

function M.register_event_handlers()
    Event.register(defines.events.on_put_item, function(event)
        local player = game.players[event.player_index]

        if player.cursor_stack.valid_for_read then
            extend_build(player, player.cursor_stack.name, event.position, event.direction,
                         event.shift_build)
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
