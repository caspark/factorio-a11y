local M = {}

function M.spawn_floating_text(entity, text, offY)
    local surface = entity.surface
    local pos = entity.position

    surface.create_entity({
        name = "flying-text",
        position = pos,
        text = text,
        color = defines.color.white,
    })
end

function M.spawn_floating_item_delta(player, target, item_name, count)
    local sign
    if count > 0 then
        sign = "+"
    else
        sign = ""
    end
    local item_localized_name = game.item_prototypes[item_name].localised_name
    M.spawn_floating_text(target, {
        "", sign, count, " ", item_localized_name, " (",
        player.get_main_inventory().get_item_count(item_name), ")",
    })
end

return M
