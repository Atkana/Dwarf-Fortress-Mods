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

## rename-beasts
A simple script that permanently changes the names of all of a given type of generated creature in the current save. The script requires an entry for their `singular`, `plural`, and `adjective` names just like vanilla raws, as well as a `type` to select which generated creature type to change.

Valid types are: `FORGOTTEN_BEAST`, `DEMON`, `UNIQUE_DEMON`, `ANGEL`, `NIGHT_TROLL`, `TITAN`, `BOGEYMAN`, `WEREBEAST`

Example usage: ``rename-beasts -type FORGOTTEN_BEAST -singular "Fun beast" -plural "Fun beasts" -adjective "Fun beast"``

## prefUtils
A utility for interacting with a unit's preferences via script code. I never built the nice wrapper for it so you could execute its functions using the dfhack command prompt (like modtools/whatever), and I don't think it follows the standard dfhack procedure for making a module. Has a few useful notes about preference related stuff in its comments. I *think* I tested to make sure everything worked...

## make-companion
Turns the selected unit into a companion for your current adventurer. 

See help entry for usage.

**Notes:**
* The game will usually generate a nemesis record and historical figure data after you first talk to that person.
* Because the unit didn't join as part of an agreement, you'll have to use dfhack's `gui/companion-order` to get them to leave. If you're using dfhack 0.44.12-r2, you'll need to download an updated version of `companion-order` since the one that shipped with the release is broken.
* While animals are smart enough to obey your request via the talk menu for them to wait in a spot, they aren't smart enough to follow you again if you ask them. They'll just stand in place, forever. So maybe don't do that.

## sexuality
A simple GUI for editing the orientation of a selected unit. You can manually toggle each value, or use randomise to roll again using the weights set out by the creature's caste (the values set by the `ORIENTATION` token).

## clothing-optional
A utility script that you can use to make creatures or entities not generate bad thoughts for lacking particular clothing items (i.e. shirts, pants, or shoes). Changes persist until the world is unloaded, so it's best to run every command you want from within an [onLoad.init](https://dfhack.readthedocs.io/en/stable/docs/Core.html#onload-init "DFHack Documentation"). Works by resetting the anger points every so often, so it may let some thoughts slip through at the start if this is the first time the script has been used on a save, and it won't remove the angry thoughts that are already present.

See help entry for usage.

Example usage: ``clothing-optional -creature DWARF -shoes -shirt`` Will make dwarves not care about being shoeless and/or shirtless. I like to think dwarven taverns operate on a "No shoes, no shirt, no problem" policy.

## make-citizen
An attempt at replacing the functionality of the now outdated `tweak makeown`. The script allows for converting units and animals to belong to a different civilization. In fort mode, you can use this to make full citizens out of visiting units.

The script isn't extensively tested (and missing some extra features), but is completely functional in basic cases. I haven't tested the more weirder cases such as what happens when you convert invaders.

See help entry for usage.

## patch/*
An attempt to create a method of applying basic changes to the game via the use of non-destructive code rather than editing raw files. This makes it potentially simpler to run lots of different mods, as well as alter some aspects that wouldn't otherwise be available to edit in raws (such as the raws of generated creatures).

As of time of writing, this is what's currently available via patches:
- Have Modest Mod's extra skin yields and ability to tan scales in fortress mode.
- Make creatures tameable, trainable and/or mountable.
- Disable flight on intelligent creatures during fortress mode.
- Alter the wait period for web spray attacks (for both raw-defined and generated creatures).
- Make particular creatures available to play as outsiders in adventure mode.
- Make creatures be able to have strange mood during fortress mode (because hey, they're fun).

See the readme in the `patch/` folder for more detailed information on each.

## announce-skills
Creates announcements related to citizens levelling up their skills in fort mode. The script can make announcements for any skill increase, as well as report when a new citizen becomes the best at a skill. It can be configured to only consider certain categories of skills, in case there's some you're focused/not interested in. Unless you plan to have different configurations between saves, this only needs to be run once per session, and so is a good candidate to include within a [dfhack*.init](https://dfhack.readthedocs.io/en/stable/docs/Core.html#dfhack-init "DFHack Documentation")

I've only lightly tested this, but it seems to work fine. There might be a bit of jank when insane citizens are involved, but it's not like everything will be ruined if this fails to report some skill gains properly.

See help entry for usage.

Example usage: ``announce-skills -best -skillup -all`` Will report whenever citizens gain any skill level, and whenever there's a new best citizen at any skill.
