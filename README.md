A11y for Factorio
=================

A set of accessibility helpers for Factorio, to assist in playing the game with less (or no) input from mouse & keyboard (e.g. via voice control, foot pedals, eye/head-tracking, etc).

Generally speaking, this mod aims to preserve existing gameplay mechanics - e.g. although this mod adds a way to move the character via the mouse cursor, rather than having the character instantly teleport from point A to point B, the character still needs to walk there along a valid path.


How does it work?
-----------------

This mod exposes a number of hot keys to provide alternate control schemes. For example:

* Run character to cursor - <kbd>Shift</kbd>+<kbd>Alt</kbd>+<kbd>R</kbd> (then left click)
* Mine closest resource in range of character - <kbd>Shift</kbd>+<kbd>Alt</kbd>+<kbd>E</kbd>
* etc

It also exposes more complex functions, which an accessibility-impaired user can call from the console:

```
/sc __A11y__ grab(game.player, 'iron-plate') -- grabs iron plates from the player's inventory
```

(The intended way to call these functions is to use voice recognition software - see *Relevant Software* heading below - to turn voice commands into text shortcuts which type them in.)

With enough work, it may eventually be possible to play Factorio with no hands at all.

Features
--------

Commands are provided to:

* mine ores/buildings which are hovered over by the mouse or close to the character
* run the character to the location or entity under the mouse cursor (respecting player speed, tile speed modifiers like concrete, and obstacles in the way)
* summon items from inventory to your cursor by name (e.g. "grab inserter") without having to open the inventory
* craft items by name without opening the inventory (e.g. you could say "craft eleven stone furnace")
* print out the name of the item being held or under your cursor (useful for crafting or grabbing items by name)

Oh, if you're looking at this mod, you should probably also read [Tutorial:Keyboard shortcuts](https://wiki.factorio.com/Tutorial:Keyboard_shortcuts) and [TIL all the keyboard shortcuts](https://www.reddit.com/r/factorio/comments/5odbdf/til_all_the_keyboard_shortcuts/), as this mod assumes that you know and use these existing tricks.

Todo list
---------

### Investigate

* Can we see what someone is hovering the UI? Would be useful to "what is" a hovered item in inventory.

### QoL and papercuts

* When you can't craft something because of missing resources, print out how many of what is missing
* Commands that require input should probably have a hotkey to open a text box for input to avoid disabling achievements unnecessarily.
* Restore the thing in hand after a "run there"

### New Features

* Have a way to refuel something or everything quickly, prioritizing the best fuel first (look at autofill mod)
* Have a way to grab all of an item in range quickly (both from floor and from inventories of items)
* Have a way to mine everything in range quickly (for clearing trees)
* Have a way to print how many of an item you have in inventory (maybe also how many you can craft?)
* Have a way to craft what's in cursor (as a ghost or regular) or hovered over
* Have a way to lay belt (assuming belt is in hand) from first to last click (assuming it's in a row). Maybe show a cross of visual lines as a guide to help line up tiles? Will probably need to check that each tile can be built before starting, and if we fail to build anything then stop building and print an error.
* Allow aliasing virtual items when crafting or grabbing? E.g. "craft/grab electric"

### Bugs

* oil is not mineable, so should be filtered out from the mining UI. Is there a generic API for detecting non-mineable objects?
* mining a item should refresh the UI
* Sufficiently high speed players don't run at max speed due to how we're tracking progress along the path found
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

### Attributions

* Contains modified icons from Font Awesome, licensed under CC Attributions 4.0 license (https://creativecommons.org/licenses/by/4.0/).
