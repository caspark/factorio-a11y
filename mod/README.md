A11y for Factorio
=================

A11y is a Factorio mod that adds shortcuts and a textual command interface (similar to the console) which make it possible to control Factorio with little to no use of a keyboard or mouse.

It is intended to be used with voice recognition software; see the README at the root of the repository.

Installing
----------

0. Make sure you're running at least Factorio 0.17.something (the "experimental" version as of 2019-04-18)
1. The mod is not listed on the [Factorio mod portal](http://mods.factorio.com/) yet, so clone this repository.
2. Install the mod by creating a symlink or directory junction from `/mod` in this repo to `<factorio>/mods/A11y_0.1.0` (e.g. `mklink /J C:\Games\Factorio\mods\A11y_0.1.0 C:\src\factorio-a11y\mod` on Windows)
3. Load up factorio to test that the visual aids, hotkeys and commands documented below work to your satisfaction

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
* <kbd>Alt+Shift+Y</kbd> - show the A11y text interface (see *Commands* heading below for more info)
* <kbd>CtrL+Alt+Shift+Y</kbd> - hide the A11y text interface

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
* <kbd>Ctrl+Shift+D</kbd> - refuel everything in reach
* <kbd>Alt+Shift+U</kbd> - refuel closest entity

Commands
--------

**Warning:** The API for these commands is unstable and subject to change.

Factorio exposes a UI (hit <kbd>Alt+Shift+Y</kbd> to show it) which is used for entering commands which take arguments in JSON format: you should automate entering these via your voice grammar. For example:

```json
-- have your grammar press Alt+Shift+Y, wait 10ms, then type:
["grab", "stone-furnace"]
-- or instead try
["craft_item", "stone-furnace", 2]
-- then have your grammar press enter to submit the command
```

**NB:** You may be wondering "why bother with this when Factorio already has a console?". 1) So that this mod can be used on multiplayer servers where admins don't want to give console access and 2) Factorio console flashes all past output when it's activated to enter a command and that's really distracting. (Earlier versions of this mod used this approach to get started - it's still useful for prototyping!)

### Available commands

| What                                 | Command                                     |
|--------------------------------------|---------------------------------------------|
| Count item in inventory              | `["count_item", <item_name>]`               |
| Grab item from inventory into cursor | `["grab", <item_name>]`                     |
| Craft an item                        | `["craft_item", <item_name>, <item_count>]` |
| Craft item currently held            | `["craft_selection", <item_count>]`         |
| Dump prototype data to a JSON file   | `["dump_data"]`                             |

### Argument explanations

| Argument    | Type    | Explanation                                                        |
|-------------|---------|--------------------------------------------------------------------|
| `item_name` | String  | [Item prototype name]. Use the *Explain* hotkey to discover these. |
| `*_count`   | Integer | A numeric count for something (e.g. amount to craft.)              |

[Item prototype name]: https://wiki.factorio.com/Data.raw#item
