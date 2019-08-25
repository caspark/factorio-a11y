local table = require("__stdlib__/stdlib/utils/table")

local Selector = require("__A11y__/logic/utils/selector")

local function get_missing_ingredients(player, recipe_name, desired_count)
    local recipe = game.recipe_prototypes[recipe_name]
    local missing = table.map(recipe.ingredients, function(ingredient)
        local amount_held = player.get_item_count(ingredient.name)
        local amount_needed = ingredient.amount * desired_count
        local amount_missing = amount_needed - amount_held
        if amount_missing > 0 then
            return amount_missing .. " " .. q(ingredient.name)
        else
            return nil
        end
    end)
    missing = table.filter(missing, function(v)
        return v ~= nil
    end)
    if #missing > 0 then
        return (", "):join(missing)
    else
        return nil
    end
end

local M = {}

-- begin crafting a given item for a given count
function M.craft_item(player, item_or_recipe_name, item_count)
    local recipe = game.recipe_prototypes[item_or_recipe_name]

    if recipe == nil then
        player.print("Recipe " .. q(item_or_recipe_name) .. " does not exist in the game")
        return
    end

    if not player.force.recipes[recipe.name].enabled then
        player.print("Recipe " .. q(recipe.name)
                         .. " exists but isn't available for crafting (might require research?)")
        return
    end

    if not player.character.prototype.crafting_categories[recipe.category] then
        player.print("Recipe " .. q(recipe.name)
                         .. " cannot be crafted by hand by your player character")
        return
    end

    local count_available = player.get_craftable_count(recipe.name)
    if count_available == 0 then
        local missing = get_missing_ingredients(player, recipe.name, item_count)
        if missing == nil then
            player.print("Can't craft " .. q(recipe.name) .. " by hand - a11y is not sure why :(")
        else
            player.print("Missing ingredients for crafting any " .. q(recipe.name) .. ": need "
                             .. missing)
        end
    elseif count_available < item_count then
        -- we can't craft them all, but craft as many as we can
        local count_crafting = player.begin_crafting{recipe = recipe.name, count = count_available}
        local count_leftover = item_count - count_crafting
        local missing = get_missing_ingredients(player, recipe.name, count_leftover)
        player.print("Crafting " .. count_crafting .. " (not " .. item_count .. ") of "
                         .. q(recipe.name) .. "; to craft " .. count_leftover .. " more, need "
                         .. missing)
    else
        player.begin_crafting{recipe = recipe.name, count = item_count}
    end
end

-- begin crafting either the held or hovered item for a given count
function M.craft_selection(player, item_count)
    local item_name, _source = Selector.player_selection(player)
    if item_name then
        M.craft_item(player, item_name, item_count)
    else
        player.print("No idea what that is so can't craft it")
    end
end

return M
