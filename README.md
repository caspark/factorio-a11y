A11y for Factorio
=================

A set of accessibility helpers for Factorio, to assist in playing the game with less (or no) input from mouse & keyboard (e.g. via voice control, foot pedals, etc).

Early days so far, don't rely on this yet :)

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