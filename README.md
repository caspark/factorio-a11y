Factorio-A11y
=============

Factorio-A11y (pronounced "factorio ally") is an [accessibility](https://en.wikipedia.org/wiki/Computer_accessibility) mod and associated voice control grammar for [Factorio](https://www.factorio.com/), which aims to make it possible to play the game with a little as possible input from mouse and keyboard while preserving the spirit of the game.

Paired with voice freely available voice recognition software, you can say:

* `refuel everything` to put the best fuel you have into every furnace, car, burner inserter/mining drill in your reach
* `run there, grab stone furnace, click, refuel it` to run where the cursor is, get a stone furnace from your inventory, build it, and load it up with the best fuel you have.
* `mine here repple five, craft ten wooden chest` to mine the 5 closest trees and craft ten wooden chests

A11y aims to be compatible with other mods and to preserve existing gameplay mechanics; e.g. although it adds a way to move the character via the mouse cursor, rather than having the character instantly teleport from point A to point B, the character still needs to walk there along a valid path and brick/concrete still provide relevant speed boosts.

Currently the mod is done enough to use for the early game; the main thing missing is support for combat. **Star this repository if you're interested to help me prioritize my projects.**

- [Factorio-A11y](#factorio-a11y)
  - [Prerequisites](#prerequisites)
    - [Voice Control Software (required)](#voice-control-software-required)
    - [Mouse alternatives and replacements (optional)](#mouse-alternatives-and-replacements-optional)
  - [Ok I'm in, how do I make it work!?](#ok-im-in-how-do-i-make-it-work)
  - [Voice Grammar](#voice-grammar)
    - [Data syncing](#data-syncing)
    - [Utility](#utility)
    - [Movement](#movement)
    - [Mining resources](#mining-resources)
    - [Building buildings](#building-buildings)
      - [Line building](#line-building)
    - [Crafting](#crafting)
    - [Manipulating entities](#manipulating-entities)
    - [Inventory management](#inventory-management)
    - [Fueling](#fueling)
    - [Reloading](#reloading)
  - [Todo list](#todo-list)
    - [Investigate](#investigate)
    - [QoL and papercuts](#qol-and-papercuts)
    - [New Features](#new-features)
    - [Bugs](#bugs)
  - [Scratchpad](#scratchpad)
    - [Voice control grammar notes](#voice-control-grammar-notes)
    - [Debugging tricks](#debugging-tricks)
    - [References](#references)
  - [Attributions](#attributions)

Prerequisites
-------------

### Voice Control Software (required)

Factorio-A11y expects you to use voice control software; as of early 2019, the main options available are:

* [Dragonfly](https://github.com/dictation-toolbox/dragonfly) (Windows, some Linux support too) - supports Windows Speech Recognition, Dragon Naturally Speaking 13 or higher, or (experimentally) the open source Sphinx speech recognition system.
* [Vocola](http://vocola.net/) (Windows) - requires Dragon Naturally Speaking 13 or higher.
* [Talon](https://talonvoice.com/) (MacOS) - has a built in speech recognition engine, but can make use of Dragon Naturally Speaking 6.

You only need to set up and install one of these.

### Mouse alternatives and replacements (optional)

If you're interested in this mod for serious use, you might also want to check out:

* Vertical mice, graphics tablet pens and trackballs might be less painful to your hands.
* [JoyToKey](https://joytokey.net/en/) or [Gopher360](https://github.com/Tylemagne/Gopher360) can remap controllers/joysticks to send keypresses and/or mouse movements/clicks
* [eViacam](http://eviacam.crea-si.com/index.php) (free, open source, Windows/Linux) can use a standard webcam to control the cursor by tracking your face so that the cursor moves when your head moves
* [Precision-Gaze](https://precisiongazemouse.com/) (free, open source, Windows) is better, but requires you to buy eye or head tracking hardware (usually available for < 200 USD).
* [Talon](https://talonvoice.com/) (free, MacOS) requires you to buy eye tracking hardware (usually available for < 200 USD), but is probably the most advanced option available (also supports making mouth noises to click).

If you can use a mouse fine and just want to use voice control for convenience, then you can ignore these. (Although it is very cool to control a game using only your eyes!)

Ok I'm in, how do I make it work!?
----------------------------------

1. Install the mod into Factorio: follow the setup instructions in `mod/README.md`
2. Install a Factorio voice grammar (a set of voice commands for some software):
  * If you use Dragonfly, follow the installation instructions in `dragonfly/README.md`
  * If you use Vocola or Talon, you'll have to first port the Dragonfly grammar over. Send a PR when you're done!
3. Start controlling Factorio by voice!
  * Start by saying `data reload` to get the voice grammar to know about all the Factorio items, recipes, etc loaded into the game.

Voice Grammar
-------------

A voice grammar is a collection of a set of voice commands and associated logic.

Factorio-A11y assumes you already have a grammar for regular clicking, right clicking, hitting individual keyboard keys (to open/close inventory/map/etc), etc.

You should also know [Tutorial:Keyboard shortcuts](https://wiki.factorio.com/Tutorial:Keyboard_shortcuts) and [TIL all the keyboard shortcuts](https://www.reddit.com/r/factorio/comments/5odbdf/til_all_the_keyboard_shortcuts/).

With that out of the way, Factorio-A11y provides the following commands:

### Data syncing

The voice grammar loads data from Factorio, but you need to ask it to do so:

* `data reload` will force Factorio to dump data which the voice grammar will then read
* `data list items` will list out names of known items (things you can `grab`)
* `data list recipes` will list out names of known recipes (things you can `craft`)

Basically you should say `data reload` anytime after unloading & reloading your voice grammar, after updating Factorio, or after changing your Factorio mods.

### Utility

* `explain it` will print out the name of what you're holding or hovering over, which is very useful in combination with other commands.

### Movement

* `run there` will run your character to where your cursor is on the screen.
* `run <direction>` will run your character in the given direction indefinitely (useful for exploring)
  * `direction` is any 1-2 of `north`, `south`, `east`, `west`
* `stop` will stop your character from running in a direction indefinitely.

### Mining resources

* `mine here` will mine the closest resource in reach which the player can mine (ore, tree or rock)

### Building buildings

* `raze here` will mine the closest building in reach
* `raze it` will mine the item being hovered as long as it is in reach (building, resource, vehicle, etc)
* `detile here` will mine the tile being stood on (bricks, concrete, etc)

#### Laboring

A11y can build ghosts for you thanks to your character's newfound willingness to do **hard backbreaking labor**:

* `labor here` will start your character laboring if there are any ghosts in reach: your character will run to each ghost in turn and build it using an item from your inventory. More expensive buildings take longer to build, of course!

Tips:

* Issue a run command to stop the laboring (or manually walk in any direction).
* Ghosts queued for laboring will have a white circle overlaid.
* Ghosts you don't have the right items for will have a brown circle overlaid.
* If you run out of items necessary to build any ghosts, laboring will stop.

#### Line building

Building lines of immediately adjacent buildings (e.g. transport belt lines or rows of assembly machines) is very common so A11y augments building to improve this:

* When you build anything, you'll see a cross-guide showing where adjancent buildings can fit, to help you line up buildings in a line
* Normally shift-clicking will place a ghost of the item you're holding, but with A11y, if you shift click on the cross-guide (while holding a building that's lined up with the guide), you'll place a row of ghosts of those buildings.

### Crafting

* `craft <count> it` will craft the item being held or hovered over `<count>` times.
  * `<count>` is the number of times you want to craft the recipe which creates the hovered item
* `craft <count> <recipe>` will craft the item which `<recipe>` produces `<count>` times.
  * `<count>` is the number of times you want to craft the recipe
  * `<recipe>` is the name of an item you can craft
  * For example: `craft 2 transport belt` will craft two regular conveyor belts.

### Manipulating entities

* `copy` and `paste` will Shift + Left/Right Click respectively (and hence work as per [Manipulating Entities](https://wiki.factorio.com/Tutorial:Keyboard_shortcuts#Manipulating_entities)).
* `red <rotate_count>` and `wrap <rotate_count>` (where `<rotate_count>` is an optional number from 1-4) will rotate/reverse-rotate an entity 1-4 times.
  * For example, `red 2` will reverse the facing of a building.

### Inventory management

* `transfer` and `split` will Ctrl + Left/Right Click respectively (and hence work as per [Manipulating Entities](https://wiki.factorio.com/Tutorial:Keyboard_shortcuts#Manipulating_items)).
* `count <item>` will print out how many of that item you have, and let you know how many more you can craft
  * `<item>` is the name of an item you might or might not have in your inventory
  * For example: `count wooden chest`
* `grab <item>` will transfer that item from your inventory to your cursor (so you can build it or put it into an assembly machine, etc)
  * `<item>` is the name of an item you have in your inventory
  * For example: `grab iron plate` will put a stack of iron plates into your hand.
* `vacuum <count> <item>` will pick up items of that type from the ground & belts to your inventory
  * `<count>` is the maximum number of items to pick up (default is 100)
  * `<item>` is the name of an item lying on the floor or on a belt within your reach
  * For example: `vacuum 10 electronic circuit` will move up to 10 basic circuits from the ground & belts into your inventory.

NB: for convenience, if you're holding a ghost of an item and your inventory gains one of those items, the ghost will be swapped out for the real item.

### Fueling

You can add fuel (wood, coal, etc) into buildings (burner miners, burner inserters, stone furnaces, etc) and vehicles (cars, tanks, trains):

* `refuel here` will refuel the closest refuelable entity in reach
* `refuel it` will refuel the entity being hovered over (building, vehicle, etc) as long as it is in reach
* `refuel everything` will refuel everything that is reachable

Tips:

* The highest energy value fuel is used first (e.g. coal before wood).
* Acceptable fuel for each entity is calculated dynamically, not hardcoded, so this should work with mods.

### Reloading

You can load ammo into turrets (gun and artillery turrets) and vehicles (cars and tanks), as well as into your character's guns:

* `reload here` will reload the closest entity that takes ammo and is in reach
* `reload it` will reload the entity being hovered over (building, vehicle)
* `reload everything` will reload every entity that is reachable (not including the character's guns)
* `reload self` will put ammo into your character's guns

Tips:

* The most expensive ammunition is used first (e.g. piercing bullets before regular bullets).
* Acceptable ammo for each entity is calculated dynamically, not hardcoded, so this should work with mods.

Todo list
---------

### Investigate

* Can we see what someone is hovering the UI? Would be useful to "what is" a hovered item in inventory.

### QoL and papercuts

* When vacuuming up ammo, put it in your active firearm first (if it fits)
* Make voice grammar detect Factorio script output location? Or at least read it from config file.
* Voice grammar should save and load last data loaded from Factorio and restore it upon grammar reload
* When mining nearest resource, prefer mining things that collide with the player (e.g. trees & rocks) for convenience in clearing a path.

### New Features

* Have a way to mine everything in range quickly (for clearing trees)
* Repairing items, using repair packs (ideally it should take some time to repair something, like in the base game)
* Allow aliasing virtual items when crafting or grabbing? E.g. "craft/grab electric"

### Bugs

* oil is not mineable, so should be filtered out from the mining UI. Is there a generic API for detecting non-mineable objects? Looks like the player prototype has a mining_categories field: https://wiki.factorio.com/Prototype/Character and it defaults to `basic-solid` according to a data raw dump I found.
* Mining resources and buildings should take some time - implement the mining hardness formula for this based on the FF post.



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

Thank you to:

* [Factorio stdlib](https://github.com/Afforess/Factorio-Stdlib) - thanks for making Factorio's API much easier to work with.
* rxi's [json.lua](https://github.com/rxi/json.lua) - thanks for writing a good json library.
* Font Awesome - this library contains icons modified from Font Awesome, licensed under CC Attributions 4.0 license (https://creativecommons.org/licenses/by/4.0/).
