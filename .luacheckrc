ignore = {
    -- max line length should be handle by autoformatter
    "631",
    -- unused variables starting with _ should be okay
    "21*/_.*"
}

-- the set of standard globals to expect
std = "lua52"

-- globals which we define (these are also allowed to be read)
globals = {
    "a11y_api",
    "Logger",
    "q",
    "q_list"
}
-- globals which can only be read
read_globals = {
    -- factorio documented built-ins for data loading
    data = {
        fields = {
            "extend"
        }
    },
    -- factorio documented built-ins for runtime
    "game",
    "script",
    "remote",
    "commands",
    "settings",
    "rcon",
    "rendering",
    "defines",
    -- other globals factorio exposes
    "serpent"
}
