local Json = require("__A11y__/logic/vendor/json")
local Categories = require("__A11y__/logic/utils/categories")

local output_filename = "A11y_data_dump.json"

local function load_recipes()
    local recipes = {}
    for name, proto in pairs(game.recipe_prototypes) do
        table.insert(
            recipes,
            {
                n = name,
                ln = proto.localised_name
            }
        )
    end
    return recipes
end

local function load_items()
    local items = {}
    for name, proto in pairs(game.item_prototypes) do
        table.insert(
            items,
            {
                n = name,
                ln = proto.localised_name
            }
        )
    end
    return items
end

local function load_entities()
    local buildings = {}
    local resources = {}
    local robots = {}
    local vehicles = {}
    local others = {}
    for name, entity in pairs(game.entity_prototypes) do
        local entry = {
            n = name,
            ln = entity.localised_name
        }
        if Categories.is_building_prototype(entity.type) then
            table.insert(buildings, entry)
        elseif Categories.is_resource_prototype(entity.type) then
            table.insert(resources, entry)
        elseif Categories.is_robot_prototype(entity.type) then
            table.insert(robots, entry)
        elseif Categories.is_vehicle_prototype(entity.type) then
            table.insert(vehicles, entry)
        else
            table.insert(others, entry)
        end
    end
    return {
        buildings = buildings,
        resources = resources,
        robots = robots,
        vehicles = vehicles,
        others = others
    }
end

local M = {}

-- dump data to a file in the script output directory
function M.dump_data(player)
    local entities = load_entities()
    local data = {
        items = load_items(),
        recipes = load_recipes(),
        building_entities = entities.buildings,
        resource_entities = entities.resources,
        robot_entities = entities.robots,
        vehicle_entities = entities.vehicles,
        other_entities = entities.others
    }
    local ok, possible_error =
        pcall(
        function()
            local json = Json.encode(data)
            local append = false
            game.write_file(output_filename, json, append, player.index)
        end
    )
    if ok then
        player.print("A11y successfully dumped data to script-output/" .. output_filename)
    else
        player.print("Failed write data as JSON to " .. output_filename .. "; error was:\n" .. possible_error)
    end
end

return M
