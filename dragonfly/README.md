Dragonfly voice grammar for Factorio
------------------------------------

This is a grammar to control Factorio via voice using Dragonfly.

It will only work properly when the matching mod (`A11y`) is installed into Factorio.

- [Dragonfly voice grammar for Factorio](#dragonfly-voice-grammar-for-factorio)
- [Installing](#installing)
  - [Dragonfly with Dragon NaturallySpeaking (via Natlink) on Windows](#dragonfly-with-dragon-naturallyspeaking-via-natlink-on-windows)
  - [Dragonfly with other speech backends](#dragonfly-with-other-speech-backends)
  - [Dragonfly on other operating systems](#dragonfly-on-other-operating-systems)
- [Using](#using)

Installing
----------

### Dragonfly with Dragon NaturallySpeaking (via Natlink) on Windows

You can hardlink `_factorio_dragonfly_grammar.py` directly into your Natlink user directory:

```
mklink /H C:\Users\Admin\Documents\natlink\_factorio.py C:\src\factorio-a11y\dragonfly\_main.py
```

(You want to use a hardlink rather than a symlink because Natlink does naive caching of file contents based on their modified-at timestamps, and there doesn't seem to be any way to have symlinks update those.)

This is the configuration that I develop and test on, and hence most likely to work.

### Dragonfly with other speech backends

You should be able to use the provided grammar with Windows Speech Recognition ("WSR") but I haven't tried. PRs to update these instructions are welcome.

### Dragonfly on other operating systems

Honestly if you've gotten [Aenea](https://github.com/dictation-toolbox/aenea) working then you don't need instructions on how to install new grammars ;)

Using
-----

To verify your installation, start a new game, then:

1. Test whether the most basic command is working: <samp>walk north</samp> should start your character running north (up)
2. Check whether you can use the A11y shortcuts: <samp>run there</samp> should start moving your character to the cursor
3. Check whether you can use the A11y textual commands: <samp>dump data</samp> should print a message to the console.

The full grammar is documented in the repository's main README.
