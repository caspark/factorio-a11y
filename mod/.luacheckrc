ignore = {
    -- max line length should be handle by autoformatter
    "631",
    -- unused variables starting with _ should be okay
    "21*/_.*"
}

-- the set of standard globals to expect
std = "lua52"

-- settable globals (these are also allowed to be read)
globals = {
    -- globals which a11y defines
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
            "extend",
            raw = {read_only = false, other_fields = true}
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
    "serpent",
    "table_size"
}
