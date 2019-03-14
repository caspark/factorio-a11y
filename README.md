A11y for Factorio
=================

A set of accessibility helpers for Factorio, to assist in playing the game with less (or no) input from mouse & keyboard (e.g. via voice control, foot pedals, eye/head-tracking, etc).

Generally speaking, this mod aims to preserve existing gameplay mechanics - e.g. although this mod adds a way to move the character via the mouse cursor, rather than having the character instantly teleport from point A to point B, the character still needs to walk there along a valid path.


How does it work?
-----------------

This mod exposes a number of functions, which an accessibility-impaired user can call by using Factorio 0.17's mechanism to call functions in mods using syntax like this:

```
/sc __A11y__ what_is_this(game.player) -- this prints out the name of the item the mouse cursor is holding or hovering over
```

The intended way to use call these functions is to use voice recognition software to turn voice commands into text shortcuts - for example, using [Dragonfly](https://github.com/dictation-toolbox/dragonfly), [Vocola](http://vocola.net/), or [Talon](https://talonvoice.com/) - while using either a mouse-alternative (e.g. trackball or [controller/joystick with JoyToKey](https://joytokey.net/en/) or [controller/joystick with Gopher360](https://github.com/Tylemagne/Gopher360)) if physically able or low cost head/eye-tracking equipment (using e.g. [eViacam](http://eviacam.crea-si.com/index.php) or [Precision-Gaze](https://precisiongazemouse.com/) or [Talon](https://talonvoice.com/)) if not. With enough work, it may eventually be possible to play Factorio with no hands at all.

Features
--------

Commands are provided to:

* mine ores/buildings which are hovered over by the mouse or close to the character
* run the character to the entity under the mouse cursor (respecting player speed, tile speed modifiers like concrete, and obstacles in the way)
* summon items from inventory to your cursor by name (e.g. "grab inserter") without having to open the inventory
* craft items by name without opening the inventory (e.g. you could say "craft eleven stone furnace")
* print out the name of the item being held or under your cursor (useful for crafting or grabbing items by name)

If you're looking at this mod, you should probably also read [Tutorial:Keyboard shortcuts](https://wiki.factorio.com/Tutorial:Keyboard_shortcuts) and [TIL all the keyboard shortcuts](https://www.reddit.com/r/factorio/comments/5odbdf/til_all_the_keyboard_shortcuts/).

Todo list
---------

* mine closest resource is ignoring rocks but shouldn't
* should be able to mine tile under cursor (needs selection tool probably?)
* Sufficiently high speed players don't run at max speed due to how we're tracking progress along the path found
* Running to a location is only possible if there is an entity under the cursor - maybe a selection tool needs to be introduced to be able to run to anywhere?
* Mining resources and buildings should take some time - implement the mining hardness formula for this based on the FF post.
* Commands that don't require input should be triggerable via a hotkey (or a chord) to prevent having to send console commands to trigger every command.
* Commands that do require input should probably have a hotkey to accept a text box for input.

Scratchpad
----------

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
