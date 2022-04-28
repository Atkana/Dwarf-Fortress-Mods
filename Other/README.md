This folder contains miscellaneous files that may have specific install requirements, or just don't belong alongside the regular mods.

## script-data
`script-data` is a utility for persistently saving information in lua tables for use in scripts. It can store data globally (available anywhere) or as world data (specific to the save). World data is saved automatically whenever the world is unloaded, as well as whenever the game is saved via autosave or quicksave.

Documentation is provided in the file, and I'm sure there's likely to be at least one script that uses this in this repo to look at for examples.

Installation: Place the file in `hack/lua`.

**Important Note:** A version of this has also been submitted for inclusion with DFhack. If the DFhack version exists, use that instead of this, as that will be more up to date!
