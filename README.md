# Dwarf-Fortress-Mods
An assortment of my DF mods and DFhack scripts, ranging from complete, to random scraps.

## Adventurer Freedom
(Description copied from my [bay12 post](http://www.bay12forums.com/smf/index.php?topic=164709.0))
### Brief Feature Overview
* Play as any creature, including world-unique generated creatures (contains spoilers)
* Start as a member of any Civilization
* Start as an Outsider of any race
* Begin with any natural skills you should have (bugfix of vanilla bug)
* Edit the size of your attribute and skill pool

~~At the moment it runs through the DFhack command-prompt but I hope one day (when I actually figure GUI stuff out) it'll have a swanky GUI interface, or at the very least use the Dwarf Fortress window~~

I was delayed long enough before uploading the mod that there's now a whole new addition. First, there's the original command-prompt version, and now there's an additional new script that performs some of its features automatically, as well as some new features. The new automatic version automatically adds every creature to the Intelligent Wilderness Animal section, automatically makes every civ available to start from, automatically patches in any natural skills and automatically unlocks the skill list to make every skill available to purchase. Automatically automatically automatically. It also has a bunch of settings that can be altered to toggle certain features on/off, among other things. With all the extra stuff added to the menus, it's worth remembering that Page Up and Page Down can be used to help navigate :P

The download also contains a small tweak script to allow for playing as non-standard race to be a more enjoyable experience, like giving your adventurer the ability to open doors, learn skills, and speak. The features of the tweak script are fully customizable and can be toggled on/off.

## The Hive
*I'll do the description later, man!*

## gm-newnit
A version of gui/gm-unit from the base DFhack scripts that adds the ability to change the unit's personality, beliefs, and physical appearance. This was made a while ago, and may no longer work properly. It was also my first and only attempt at GUI-related DFhackery, and so may be janky (though it works). *Requires modtools/set-personality and modtools/set-belief. Find them in the modtools section of this repo.*

## rename-beasts
A simple script that permanently changes the names of all of a given type of generated creature in the current save. The script requires an entry for their `singular`, `plural`, and `adjective` names just like vanilla raws, as well as a `type` to select which generated creature type to change.

Valid types are: `FORGOTTEN_BEAST`, `DEMON`, `UNIQUE_DEMON`, `ANGEL`, `NIGHT_TROLL`, `TITAN`, `BOGEYMAN`, `WEREBEAST`

Example usage: ``rename-beasts -type FORGOTTEN_BEAST -singular "Fun beast" -plural "Fun beasts" -adjective "Fun beast"``

## prefUtils
A utility for interacting with a unit's preferences via script code. I never built the nice wrapper for it so you could execute its functions using the dfhack command prompt (like modtools/whatever), and I don't think it follows the standard dfhack procedure for making a module. Has a few useful notes about preference related stuff in its comments. I *think* I tested to make sure everything worked...
