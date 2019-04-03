data:extend(
    {
        {
            type = "shortcut",
            name = "runtool-shortcut",
            order = "a[alt-mode]-b[copy]",
            action = "create-blueprint-item",
            item_to_create = "runtool",
            localised_name = {"shortcut.runtool"},
            icon = {
                filename = "__A11y__/graphics/icons/shortcut-bar/" .. "runtool-x32.png",
                priority = "extra-high-no-scale",
                size = 32,
                scale = 1,
                flags = {"icon"}
            },
            small_icon = {
                filename = "__A11y__/graphics/icons/shortcut-bar/" .. "runtool-x24.png",
                priority = "extra-high-no-scale",
                size = 24,
                scale = 1,
                flags = {"icon"}
            },
            disabled_small_icon = {
                filename = "__A11y__/graphics/icons/shortcut-bar/" .. "runtool-x24-white.png",
                priority = "extra-high-no-scale",
                size = 24,
                scale = 1,
                flags = {"icon"}
            }
        },
        {
            type = "selection-tool",
            name = "runtool",
            icon = "__A11y__/graphics/icons/item/runtool.png",
            icon_size = 32,
            flags = {"only-in-cursor"},
            subgroup = "other",
            order = "c[automated-construction]-a[blueprint]",
            stack_size = 1,
            stackable = false,
            selection_color = {g = 1},
            alt_selection_color = {g = 1, b = 1},
            selection_mode = {"any-tile"},
            alt_selection_mode = {"any-tile"},
            selection_cursor_box_type = "copy",
            alt_selection_cursor_box_type = "electricity",
            --entity_filters = {'stone-furnace', 'steel-furnace'},
            --entity_type_filters = {'furnace', 'assembling-machine'},
            --tile_filters = {'concrete', 'stone-path'},
            --entity_filter_mode = 'whitelist',
            --tile_filter_mode = 'whitelist',
            --alt_entity_filters = {'stone-furnace', 'steel-furnace'},
            --alt_entity_type_filters = {'furnace', 'assembling-machine'},
            --alt_tile_filters = {'concrete', 'stone-path'},
            --alt_entity_filter_mode = 'whitelist',
            --alt_tile_filter_mode = 'whitelist',
            show_in_library = false
        }
    }
)