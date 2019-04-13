-- This module provides functions intended to be invoked directly by the player.
-- Providing support for functions which take inputs means that we can support far more
-- flexible forms of input than if we were just using hotkeys, because we can take
-- arguments directly from the player as well.
--
-- There are two means to do so. The first is using the console directly,
-- using syntax like (e.g.) `/sc __A11y__ grab(game.player, 'small-electric-pole')`.
--
-- The second is using the UI provided in `__A11y__/logic/command_ui.lua`, e.g.
-- `["grab", "small-electric-pole"]`.

local Craft = require("__A11y__/logic/modules/craft")
local Inventory = require("__A11y__/logic/modules/inventory")

return {
    grab = Inventory.grab,
    count_item = Inventory.count_item,
    craft_item = Craft.craft_item,
    craft_selection = Craft.craft_selection
}
