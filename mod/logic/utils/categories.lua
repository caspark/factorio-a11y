local Table = require("__stdlib__/stdlib/utils/table")

local M = {}

--[[
    uncategorized prototypes, according to https://wiki.factorio.com/Prototype_definitions

    "player",
    "unit-spawner",
    "fish",
    "land-mine",
    "market",
    "player-port",
    "simple-entity",
    "simple-entity-with-owner",
    "simple-entity-with-force",
    "tree",
    "unit",
]]
M.resource_prototypes = {"resource", "tree", "simple-entity"}

M.building_prototypes = {
    "accumulator", "ammo-turret", "arithmetic-combinator", "artillery-turret", "assembling-machine",
    "beacon", "boiler", "constant-combinator", "container", "curved-rail", "decider-combinator",
    "electric-energy-interface", "electric-pole", "electric-turret", "fluid-turret", "furnace",
    "gate", "generator", "heat-interface", "heat-pipe", "infinity-container", "infinity-pipe",
    "inserter", "lab", "lamp", "loader", "logistic-container", "mining-drill", "offshore-pump",
    "pipe-to-ground", "pipe", "power-switch", "programmable-speaker", "pump", "radar",
    "rail-chain-signal", "rail-signal", "reactor", "roboport", "rocket-silo", "solar-panel",
    "splitter", "storage-tank", "straight-rail", "train-stop", "transport-belt", "turret",
    "underground-belt", "wall",
}

M.robot_prototypes = {"combat-robot", "construction-robot", "logistic-robot"}

M.vehicle_prototypes = {"car", "artillery-wagon", "cargo-wagon", "fluid-wagon", "locomotive"}

-- turn arrays into set-like tables for quick lookup
local building_prototypes_set = Table.array_to_dictionary(M.building_prototypes, true)
local resource_prototypes_set = Table.array_to_dictionary(M.resource_prototypes, true)
local robot_prototypes_set = Table.array_to_dictionary(M.robot_prototypes, true)
local vehicle_prototypes_set = Table.array_to_dictionary(M.vehicle_prototypes, true)

function M.is_building_prototype(prototype_type)
    return building_prototypes_set[prototype_type]
end

function M.is_resource_prototype(prototype_type)
    return resource_prototypes_set[prototype_type]
end

function M.is_robot_prototype(prototype_type)
    return robot_prototypes_set[prototype_type]
end

function M.is_vehicle_prototype(prototype_type)
    return vehicle_prototypes_set[prototype_type]
end

return M
