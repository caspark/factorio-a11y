A11y for Factorio
=================

A11y (pronounced "ally") is an [accessibility](https://en.wikipedia.org/wiki/Computer_accessibility) mod for [Factorio](https://www.factorio.com/), which aims to make it possible to play the game with a little as possible input from mouse and keyboard while preserving the spirit of the game.

You can use it as a "quality of life" mod but it really shines when it's paired with voice recognition software; for example:

* Say <samp>refuel everything</samp> to put the best fuel you have into every furnace, car, burner inserter/mining drill in your reach
* Say <samp>run there, grab stone furnace, click, refuel it</samp> to run where the cursor is, get a stone furnace from your inventory, build it, and load it up with the best fuel you have.
* Say <samp>mine here repple five, craft ten wooden chest</samp> to mine the 5 closest trees and craft ten wooden chests

A11y aims to be compatible with other mods and to preserve existing gameplay mechanics; e.g. although it adds a way to move the character via the mouse cursor, rather than having the character instantly teleport from point A to point B, the character still needs to walk there along a valid path and brick/concrete still provide relevant speed boosts.

Currently the mod is done enough to use for the early (pre combat) game, with new features being added regularly. **Star this repository if you're interested to help me prioritize my projects.**

Awesome, how do I make it work!?
--------------------------------

First, a warning: **you'll get the most out of this mod right now if you're already familar with Dragon NaturallySpeaking, Vocola, Dragonfly, or Talon** (see *Relevant Software* below); This is mainly because I haven't included a ready-to-go voice grammar in this mod.

With that out of the way:

1. The mod is not listed on the [Factorio mod portal](http://mods.factorio.com/) yet, so clone this repository into your `factorio/mods` directory
2. Load up factorio to test that the A11y hotkeys documented below work to your satisfaction
3. Write a voice grammar for Factorio to make voice commands hit your hotkeys
4. Extend your grammar to support A11y's console commands. For now, you'll want to use Dragonfly's [DictListRef](https://dragonfly2.readthedocs.io/en/latest/elements.html#dictlistref-class) or equivalent with [a list of Factorio items](https://wiki.factorio.com/Data.raw#item) to make it easy to say item names.

Eventually this mod will ship with an included voice grammar for Dragonfly and/or Talon, but for now the focus is on developing the capabilities of the mod itself.

Visual Aids
-----------

To make it easier to predict what your voice commands will do, A11y adds several visual aids:

<img alt="Example screenshot of visual aids in Factorio" src="https://i.imgur.com/WWLJMIc.jpg" height="250"/>

* The outer green circle is your reach for picking up items, mining and placing buildings.
* The inner green circle is your reach for mining resources
* The red circle denotes your closest resource (what <kbd>Alt+Shift+E</kbd> would mine)
* The orange circle denotes your closest building (what <kbd>Alt+Shift+B</kbd> would mine)
* The yellow circle denotes your closest refuelable entity (what <kbd>Alt+Shift+F</kbd> would refuel)

Hotkeys
-------

### Utility

* <kbd>Alt+Shift+W</kbd> - the "*Explain*" command; print out name of item in hand or entity hovered by cursor

### Movement

* <kbd>Alt+Shift+R</kbd> then left click - run to clicked tile or entity

### Mining

Mining covers removing builds, getting resources, and removing tiles.

* <kbd>Alt+Shift+E</kbd> - mine closest resource (ore, rock, tree, etc)
* <kbd>Alt+Shift+B</kbd> - mine closest building
* <kbd>Alt+Shift+M</kbd> - mine resource or entity hovered by cursor
* <kbd>Alt+Shift+T</kbd> - mine tile directly under player (brick, concrete, etc)

#### Refueling

Refueling covers putting fuel into burner miners/inserters, stone furnaces, cars, etc. The best fuel available in your inventory is always used, unless there is already fuel in the entity, in which case more fuel of that type is added.

* <kbd>Alt+Shift+F</kbd> - refuel entity hovered by cursor
* <kbd>Ctrl+Alt+Shift+F</kbd> - refuel everything in reach
* <kbd>Alt+Shift+U</kbd> - refuel closest entity

You should also know [Tutorial:Keyboard shortcuts](https://wiki.factorio.com/Tutorial:Keyboard_shortcuts) and [TIL all the keyboard shortcuts](https://www.reddit.com/r/factorio/comments/5odbdf/til_all_the_keyboard_shortcuts/).

Console commands
----------------

**Warning:** The API for these commands is unstable and subject to change.

These commands can be entered via the console (press `` ` ``) and should be automated via your voice grammar; for example:

```lua
-- have your grammar press backtick, wait 10ms, then type:
/sc __A11y__ a11y_api.grab(game.player, 'stone-furnace')
-- or instead try
/sc __A11y__ a11y_api.start_crafting(game.player, {item_name='stone-furnace', count=1})
-- then have your grammar press enter to submit the command
```

### Available commands

| What                                 | Command                                                                                  |  |
|--------------------------------------|------------------------------------------------------------------------------------------|--|
| Grab item from inventory into cursor | `a11y_api.grab(game.player, <item_name>)`                                                |  |
| Craft an item                        | `a11y_api.start_crafting(game.player, {item_name=<item_name>, item_count=<item_count>})` |  |
| Count item in inventory              | `a11y_api.count_item(player, <item_name>)`                                               |  |

### Argument explanations

| Argument    | Explanation                                                                                                                           |
|-------------|---------------------------------------------------------------------------------------------------------------------------------------|
| `item_name` | [Prototype name](https://wiki.factorio.com/Data.raw#item) of an item. Use the *Explain* hotkey command (see above) to discover these. |
| `*_count`   | A numeric count for something. It's usually obvious from the command what this does.                                                  |

Recommended Grammar
-------------------

A11y assumes you already have voice commands for clicking, right clicking, hitting individual keys (to open/close inventory/map/etc), but here are things you may not have thought of:

* Bind the following for easier inventory management:
  * <samp>copy</samp> to Shift Left Click
  * <samp>paste</samp> to Shift Right Click
  * <samp>transfer</samp> to Ctrl Left Click
  * <samp>split</samp> to Ctrl Right Click
* Bind <samp>run ( north | west | south | east )</samp> to hold down <kbd>W/A/S/D</kbd> for you for easier exploring
  * Also add a <samp>stop</samp> to release those 4 keys!
* Make sure you have a quick command to hit <kbd>R</kbd> repeatedly, like <samp>red 3</samp> to rotate 3 times (although technically you only need 1-2 rotations, since <kbd>Shift+R</kbd> rotates once in reverse)

Todo list
---------

### Investigate

* Can we see what someone is hovering the UI? Would be useful to "what is" a hovered item in inventory.

### QoL and papercuts

* When you can't craft something because of missing resources, print out how many of what is missing
* Commands that require input should probably have a hotkey to open a text box for input to avoid disabling achievements unnecessarily.
* Restore the thing in hand after a "run there"
* When mining nearest resource, prefer mining things that collide with the player (e.g. trees & rocks) for convenience in clearing a path.

### New Features

* Have a way to grab all of an item in range quickly (both from floor and from inventories of items)
* Have a way to mine everything in range quickly (for clearing trees)
* Have a way to craft what's in cursor (as a ghost or regular) or hovered over
* Have a way to lay belt (assuming belt is in hand) from first to last click (assuming it's in a row). Maybe show a cross of visual lines as a guide to help line up tiles? Will probably need to check that each tile can be built before starting, and if we fail to build anything then stop building and print an error.
* Allow aliasing virtual items when crafting or grabbing? E.g. "craft/grab electric"

### Bugs

* oil is not mineable, so should be filtered out from the mining UI. Is there a generic API for detecting non-mineable objects?
* Mining resources and buildings should take some time - implement the mining hardness formula for this based on the FF post.


Relevant Software
-----------------

### Mouse Alternatives

Aside from relatively obvious options like vertical mice, graphics tablet pens and trackballs, the next easiest options to use are any controllers or joysticks you have lying around; remap them to send keypresses and/or mouse movements/clicks with [JoyToKey](https://joytokey.net/en/) or [Gopher360](https://github.com/Tylemagne/Gopher360).

### Mouse replacements

If you can't use a mouse, you can look into these options:

* [eViacam](http://eviacam.crea-si.com/index.php) (free, open source, Windows/Linux) uses commodity webcams to control the cursor by tracking your face so that the cursor moves when your head moves
* [Precision-Gaze](https://precisiongazemouse.com/) (free, open source, Windows) is better, but requires you to buy eye or head tracking hardware (usually available for < 200 USD).
* [Talon](https://talonvoice.com/) (free, MacOS) requires you to buy eye tracking hardware (usually available for < 200 USD), but is probably the most advanced option available (also supports making mouth noises to click).

### Voice Control Software

Voice control software is useful for simulating clicks, keypresses, and typing; as of early 2019, the main options available are:

* [Dragonfly](https://github.com/dictation-toolbox/dragonfly) (Windows, some Linux support too) - supports Windows Speech Recognition, Dragon Naturally Speaking 13 or higher, or (experimentally) the open source Sphinx speech recognition system.
* [Vocola](http://vocola.net/) (Windows) - requires Dragon Naturally Speaking 13 or higher.
* [Talon](https://talonvoice.com/) (MacOS) - has a built in speech recognition engine, but can make use of Dragon Naturally Speaking 6.

Scratchpad
----------

### Voice control grammar notes

It's important to have a uniform interface to perform actions on game entities, so here are thoughts on voice grammar design to inform the API of A11y:

* Most actions should be of the form `<action> <target>`.
* Actions are things like "mine", "craft", "grab", "run", etc
  * Certain actions might have numbers after them - e.g. "craft 15"
* Targets should link to game objects/entities. To support both eye/head-tracking and voice-only
  playstyles, we need to support several targeting mechanisms:
  * `it` - whatever cursor hovers over (or chose using a selection tool)
  * `here` - target closest entity eligible for action
  * `all` - target all entities eligible for action
  * `<item prototype name>` - target the entities whose prototype is named this. E.g. `grab copper plate` or `mine iron ore`
  * `<item prototype group>` - some items are part of the same named "group" (`game.player.selected.prototype.subgroup.name`), like all trees are `tree`.
  * `grid <coordinate>` - to enable true voice-only play, we need to be able to move and interact via
    something like a grid system, or naming tiles via tiny UI.

Open questions:

* should mining resources use different keyword than deconstructing buildings? They're the same as
  far as the game is concerned, but it might be helpful to allow mining items
* there needs to be a name for mining tiles, separate from mining resources
* we have an indicator for the closest resource, and closest building still needs implementing.. but
  what about tiles? Since the only interesting thing to do with a tile is mine it, maybe this should only
  be drawn when there's a tile in mining range?
* should the grid system use rows & columns like B3 or should each tile just have its own number? how
  do these scale for longer reach or interacting outside reach? Due to latency we want to avoid a
  dragon-mousegrid-like system.
* sometimes you're okay with your character moving to fulfil the command, sometimes not. Should there be
  a modifier suffix, like `<action> <target> [<modifier>]`, where you can say things like `moving` to
  allow your character to move?

### Debugging tricks

```

-- convert a table to a string
-- see https://github.com/pkulchenko/serpent
game.player.print(serpent.block(p))
-- alternative
game.player.print(inspect(p))

-- drop a traceback
debug.traceback()


-- writes to the game's log
log()

--  writes to stdout (run the game from a terminal)
print()
```

### References

https://lua-api.factorio.com/latest/index.html

https://wiki.factorio.com/Data.raw
https://wiki.factorio.com/Prototype_definitions
https://wiki.factorio.com/Prototype/Decorative
https://wiki.factorio.com/Prototype/SimpleEntity

https://github.com/Afforess/Factorio-Stdlib/tree/master/stdlib
http://afforess.github.io/Factorio-Stdlib/index.html

Attributions
------------

* Contains modified icons from Font Awesome, licensed under CC Attributions 4.0 license (https://creativecommons.org/licenses/by/4.0/).
