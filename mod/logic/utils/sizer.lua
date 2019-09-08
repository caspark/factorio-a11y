local M = {}

function M.calc_entity_width_and_height(entity_prototype_name)
    local building_prototype = game.entity_prototypes[entity_prototype_name]
    local width = math.ceil(building_prototype.selection_box.right_bottom.x
                                - building_prototype.selection_box.left_top.x)
    local height = math.ceil(building_prototype.selection_box.right_bottom.y
                                 - building_prototype.selection_box.left_top.y)
    return width, height
end

return M
