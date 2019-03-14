A11y for Factorio
=================

A set of accessibility helpers for Factorio, to assist in playing the game with less (or no) input from mouse & keyboard (e.g. via voice control, foot pedals, eye/head-tracking, etc).

Generally speaking, this mod aims to preserve existing gameplay mechanics - e.g. although this mod adds a way to move the character via the mouse cursor, rather than having the character instantly teleport from point A to point B, the character still needs to walk there along a valid path.


How does it work?
-----------------

This mod exposes a number of hot keys to provide alternate control schemes. For example:

* Run character to cursor - <kbd>Shift</kbd>+<kbd>Alt</kbd>+<kbd>R</kbd>
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
* run the character to the entity under the mouse cursor (respecting player speed, tile speed modifiers like concrete, and obstacles in the way)
* summon items from inventory to your cursor by name (e.g. "grab inserter") without having to open the inventory
* craft items by name without opening the inventory (e.g. you could say "craft eleven stone furnace")
* print out the name of the item being held or under your cursor (useful for crafting or grabbing items by name)

Oh, if you're looking at this mod, you should probably also read [Tutorial:Keyboard shortcuts](https://wiki.factorio.com/Tutorial:Keyboard_shortcuts) and [TIL all the keyboard shortcuts](https://www.reddit.com/r/factorio/comments/5odbdf/til_all_the_keyboard_shortcuts/), as this mod assumes that you know and use these existing tricks.

Todo list
---------

* mine closest resource is ignoring rocks but shouldn't
* should be able to mine tile under cursor (needs selection tool probably?)
* Sufficiently high speed players don't run at max speed due to how we're tracking progress along the path found
* Running to a location is only possible if there is an entity under the cursor - maybe a selection tool needs to be introduced to be able to run to anywhere?
* Mining resources and buildings should take some time - implement the mining hardness formula for this based on the FF post.
* Commands that don't require input should be triggerable via a hotkey (or a chord) to prevent having to send console commands to trigger every command.
* Commands that do require input should probably have a hotkey to accept a text box for input.


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
