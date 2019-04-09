std = {
    globals = {}, -- these globals can be set and accessed.
    read_globals = {
        -- lua built-ins which luacheck doesn't include by default for some reason
        "ipairs",
        "pairs",
        "pcall",
        "setmetatable",
        "table",
        -- factorio built-ins
        "game",
        "script",
        "remote",
        "commands",
        "settings",
        "rcon",
        "rendering",
        -- factorio constants
        "defines",
        -- custom globals
        "Logger",
        "q",
        "q_list"
    }
}
