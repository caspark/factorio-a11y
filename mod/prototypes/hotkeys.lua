-- On custom-input's 'consuming' property:
-- available options:
-- * none: default if not defined
-- * all: if this is the first input to get this key sequence then no other inputs listening for this sequence are fired
-- * script-only: if this is the first *custom* input to get this key sequence then no other *custom* inputs listening for this sequence are fired. Normal game inputs will still be fired even if they match this sequence.
-- * game-only: The opposite of script-only: blocks game inputs using the same key sequence but lets other custom inputs using the same key sequence fire.
-- source: https://forums.factorio.com/viewtopic.php?t=30644
data:extend({
    {
        type = "custom-input",
        name = "hotkey-command-window-hide",
        key_sequence = "CONTROL + SHIFT + ALT + Y",
    },
    {type = "custom-input", name = "hotkey-command-window-show", key_sequence = "SHIFT + ALT + Y"},
    {type = "custom-input", name = "hotkey-explain-selection", key_sequence = "SHIFT + ALT + W"},
    {type = "custom-input", name = "hotkey-get-runtool", key_sequence = "SHIFT + ALT + R"},
    {type = "custom-input", name = "hotkey-mine-closest-building", key_sequence = "SHIFT + ALT + B"},
    {type = "custom-input", name = "hotkey-mine-closest-resouce", key_sequence = "SHIFT + ALT + E"},
    {type = "custom-input", name = "hotkey-mine-selection", key_sequence = "SHIFT + ALT + M"},
    {
        type = "custom-input",
        name = "hotkey-mine-tile-under-player",
        key_sequence = "SHIFT + ALT + T",
    }, {type = "custom-input", name = "hotkey-refuel-selection", key_sequence = "SHIFT + ALT + F"},
    {type = "custom-input", name = "hotkey-refuel-everything", key_sequence = "CONTROL + SHIFT + D"},
    {type = "custom-input", name = "hotkey-refuel-closest", key_sequence = "SHIFT + ALT + U"},
})
