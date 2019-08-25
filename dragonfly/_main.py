from __future__ import print_function

import dragonfly
import re
import json
import datetime
import os

# =========== Settings ===========
# TODO make this configurable
FACTORIO_SCRIPT_OUTPUT_DIRECTORY = r"C:\Games\Factorio_0.17\script-output"

# =========== Constants ===========
DUMP_FILE_NAME = os.path.join(
    FACTORIO_SCRIPT_OUTPUT_DIRECTORY, r"A11y_data_dump.json")

# =========== General utility functions ===========


def combine_maps(*maps):
    """Merge the contents of multiple maps, giving precedence to later maps. Skips
    empty maps and deletes entries with value None."""
    result = {}
    for map in maps:
        if not map:
            continue
        for key, value in map.iteritems():
            if value is None and key in result:
                del result[key]
            else:
                result[key] = value
    return result


def p(*args):
    print("Factorio grammar:", *args)

# =========== Dragonfly utility functions ===========


def text_to_literal_elements(text_list):
    return [dragonfly.Literal(txt) for txt in text_list]


def make_action_hold_keys(keys):
    return dragonfly.Key(",".join(["{}:down".format(x) for x in keys]))


def make_action_release_keys(keys):
    return dragonfly.Key(",".join(["{}:up".format(x) for x in keys]))

# =========== Factorio data ===========


factorio_items = dragonfly.DictList("factorio_items")
factorio_recipes = dragonfly.DictList("factorio_recipes")


# =========== Actual Factorio grammar ===========


FACTORIO_STOP_WALKING_ACTION = make_action_release_keys("wasd")

# after we open a text field or hit a hotkey, how long should we wait before
# continuing? 2ms works fine for fast computers, slower computers (or bigger
# factorio bases!) may need more of a delay to allow Factorio to keep up.
FACTORIO_UI_DELAY_ACTION = dragonfly.Pause("2")

# 1 is default zoom
# most zoomed out in vanilla factorio is about 0.375
# most zoomed in is about 2
FACTORIO_ZOOM_LEVELS = [0.3, 0.4, 0.6, 0.8, 1, 1.2, 1.5, 2]


def factorio_start_walking(dir_8):
    make_action_release_keys("wasd").execute()
    keys = ""
    if "north" in dir_8:
        keys += "w"
    if "east" in dir_8:
        keys += "d"
    if "south" in dir_8:
        keys += "s"
    if "west" in dir_8:
        keys += "a"
    make_action_hold_keys(keys).execute()


def make_factorio_action_console_command(command, silent=True):
    """Send a given code snippet to the Factorio console.
    Note that big snippets cause Dragon to hang for 1-5 seconds - it's probably trying to read
    the contents of the text box or something silly like that"""

    # Hacky way to munge the command to remove whitespace and get it onto one line
    # Would be better to use a lua parser, but doesn't seem to be one available for py2.

    # 1. As a minor optimization, compress known operators separated only by whitespace
    command = re.sub(" +([+-/*=]|\\.\\.|==|~=) +", r"\1", command)
    # 2. Find lines ending in what seems to be the end of an expression (naively determined by
    #    checking if it's alphanumeric or a closing bracket), which are followed by a line
    #    that's a new expression ( naively determined by checking if it's alphanumeric); this
    #    case should be safe to join the lines with a semicolon.
    command = re.sub("([a-zA-Z)\\]}0-9])\n+ +([a-zA-Z])",
                     r"\1;\2", command.strip())
    # 3. Remaining lines should be lines starting with "(", "{", ",", etc, or lines which are
    #    ending in those chars. Here we need to not use a semicolon, because we're continuing
    #    a previous statement.
    command = re.sub("\n +", r"", command)
    # print(command)  # kept around for easy debugging

    text = "/sc " if silent else "/c "
    text += command
    return FACTORIO_STOP_WALKING_ACTION + dragonfly.Key("backtick, backspace") + dragonfly.Text(text, pause=0) + dragonfly.Key("enter")


def make_factorio_action_a11y_command(command):
    json_command = json.dumps(command, separators=(',', ':'))
    return dragonfly.Key("as-y") + FACTORIO_UI_DELAY_ACTION + dragonfly.Text(json_command, pause=0) + dragonfly.Key("enter")


def factorio_set_zoom(n):
    t = "game.player.zoom = %s" % FACTORIO_ZOOM_LEVELS[n + 1]
    make_factorio_action_console_command(t).execute()


def factorio_count_item(item_name):
    make_factorio_action_a11y_command(["count_item", item_name]).execute()


def factorio_grab_item(item_name):
    make_factorio_action_a11y_command(["grab", item_name]).execute()


def factorio_craft_item(recipe_name, item_count):
    make_factorio_action_a11y_command(
        ["craft_item", recipe_name, item_count]).execute()


def factorio_craft_selection(item_count):
    make_factorio_action_a11y_command(
        ["craft_selection", item_count]).execute()


def data_reload():
    make_factorio_action_a11y_command(["dump_data"]).execute()
    dragonfly.Pause("50").execute()
    with open(DUMP_FILE_NAME, "r") as f:
        data = json.load(f)

    def pronounceable(thing):
        return thing[u'n'].replace('-', ' ')

    loaded_items = {pronounceable(x): x[u'n'] for x in data[u'items']}
    loaded_recipes = {pronounceable(x): x[u'n'] for x in data[u'recipes']}

    factorio_items.set(loaded_items)
    factorio_recipes.set(loaded_recipes)

    p('successfully loaded {item_count} items and {recipe_count} recipes from {path}'.format(
        item_count=len(loaded_items), recipe_count=len(loaded_recipes), path=DUMP_FILE_NAME
    ))


def data_list_items():
    p("known items are:", ', '.join(sorted(factorio_items.keys())))


def data_list_recipes():
    p("known recipes are:", ', '.join(sorted(factorio_recipes.keys())))


factorio_console_commands = {
    # put selected item stack away (like pressing Q while holding some items)
    "clean cursor": "game.player.clean_cursor()",
    # use capsules like defender bots and eat fish
    "use cursor": "game.player.use_from_cursor(game.player.position)",

    # debugging commands
    "clear console": "game.player.clear_console()",
    "reload mods": """game.reload_mods(); game.player.print("mods reloaded!")""",
    "print my tile position": "game.player.print(game.player.surface.get_tile(game.player.position).position)",
    "print my tile name": "game.player.print(game.player.surface.get_tile(game.player.position).prototype.name)",
}
factorio_a11y_commands = {
    "draw grid": "render_reach_grid(game.player)",
}


class FactorioRule(dragonfly.MappingRule):
    mapping = combine_maps(
        {k: make_factorio_action_console_command(
            v) for k, v in factorio_console_commands.items()},
        {k: make_factorio_action_a11y_command(
            v) for k, v in factorio_a11y_commands.items()},
        {
            # commands to manage and debug reading data (e.g. recipe & item names) from Factorio
            "data reload": dragonfly.Function(data_reload),
            "data list items": dragonfly.Function(data_list_items),
            "data list recipes": dragonfly.Function(data_list_recipes),

            "zoom <n>": dragonfly.Function(factorio_set_zoom),
            "zoom out": dragonfly.Function(lambda: factorio_set_zoom(0)),
            "zoom in": dragonfly.Function(lambda: factorio_set_zoom(len(FACTORIO_ZOOM_LEVELS)-2)),
            "zoom reset": dragonfly.Function(lambda: factorio_set_zoom(len(FACTORIO_ZOOM_LEVELS) // 2)),

            # walking controls (except for running to cursor)
            "run <dir_8>": dragonfly.Function(factorio_start_walking),
            "stop": FACTORIO_STOP_WALKING_ACTION,

            # make rotate repeatable
            "red <rotate_count>": dragonfly.Key("r:%(rotate_count)s"),
            # reverse rotate
            "wrap <rotate_count>": dragonfly.Key("s-r:%(rotate_count)s"),

            # a11y commands that take inputs
            "count <item_name>": dragonfly.Function(factorio_count_item),
            "grab <item_name>": dragonfly.Function(factorio_grab_item),
            "craft [<item_count>] <recipe_name>": dragonfly.Function(factorio_craft_item),
            "craft [<item_count>] it": dragonfly.Function(factorio_craft_selection),

            # ally commands bound to hotkeys
            "explain it": dragonfly.Key("as-w"),
            "run there": FACTORIO_STOP_WALKING_ACTION + dragonfly.Key("as-r") + FACTORIO_UI_DELAY_ACTION + dragonfly.Mouse("left") + dragonfly.Pause("10") + dragonfly.Key("q"),
            "mine ore": dragonfly.Key("as-e"),
            "mine house": dragonfly.Key("as-b"),
            "mine it": dragonfly.Key("as-m"),
            "mine tile": dragonfly.Key("as-t"),
            "refuel it": dragonfly.Key("as-f"),
            "refuel here": dragonfly.Key("as-u"),
            "refuel everything": dragonfly.Key("cs-d"),

            # mouse shortcuts
            "paste": dragonfly.Key("shift:down") + dragonfly.Mouse("left") + dragonfly.Key("shift:up"),
            "copy": dragonfly.Key("shift:down") + dragonfly.Mouse("right") + dragonfly.Key("shift:up"),
            "transfer": dragonfly.Key("ctrl:down") + dragonfly.Mouse("left") + dragonfly.Key("ctrl:up"),
            "split": dragonfly.Key("ctrl:down") + dragonfly.Mouse("right") + dragonfly.Key("ctrl:up"),

            "tile bigger [<n>]": dragonfly.Key("equals:%(n)s"),
            "tile smaller [<n>]": dragonfly.Key("minus:%(n)s"),
        }
    )
    extras = [
        dragonfly.Alternative(name="dir_8", children=text_to_literal_elements(
            ["north", "north east", "east", "south east",
             "south", "south west", "west", "north west"]
        )),
        dragonfly.Integer(name="n", default=1, min=1, max=20),
        dragonfly.Integer(name="item_count", default=1, min=1, max=101),
        dragonfly.Integer(name="rotate_count", default=1, min=1, max=4),
        dragonfly.DictListRef("item_name", factorio_items),
        dragonfly.DictListRef("recipe_name", factorio_recipes),
    ]


grammar = dragonfly.Grammar('factorio', context=dragonfly.AppContext(
    executable="factorio.exe"))
grammar.add_rule(FactorioRule())
grammar.load()

p('loaded at ' + str(datetime.datetime.now()))


def unload():
    global grammar
    if grammar:
        grammar.unload()
        p('unloaded')
    grammar = None
