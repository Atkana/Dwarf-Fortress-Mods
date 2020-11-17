# Patches
These are an attempt to create a method of applying basic changes to the game via the use of non-destructive code rather than editing raw files. This makes it potentially simpler to run lots of different mods, as well as alter some aspects that wouldn't otherwise be available to edit in raws (such as the raws of generated creatures).

These scripts generally need to be run before a world is loaded, and persist until the game is closed (except in cases where the patch is marked as temporary - if you run one of the scripts while a save is loaded, it'll be unloaded when the world is). Therefore, you should probably run them in the main menu, or even better is to place all the commands you want to run inside a `dfhack*.init` file so they are automatically run when the game is launched.

## adventurer-creatures
Allows setting creatures to be available as outsiders during adventure mode. You can set specific creatures to be available, creatures that can learn, or all creatures, regardless of how well they might play...

See help entry for usage.

## make-moodable
Grants other creatures the ability to have strange moods during fort mode without having to edit their creature files. Since this isn't active during worldgen, it won't cause races that don't normally get strange moods to make artifacts during it.

See help entry for usage.

## modest-leather
Replicates Modest Mod's alterations to tanning without having to edit any files.
Brief summary of Modest Mod's tanning changes:
- Creatures effectively drop more skin based on their size, rather than 1 single unit of skin.
- Scales can be used to make leather, and also follow the rules of dropping more based on the creature's size.

Script notes:
- Specific creatures can be targeted for the edits, or they can be applied to every creature.
- Changes are only applied to creatures that follow the vanilla naming schemes for their materials. For `-scales`, creatures with a material called `SCALE` will be affected. For `-skin`, creatures with both a `SKIN` and a `LEATHER` material will be affected.
- You can alter the amount of skin/leather required to make a hide.
- Because these changes aren't active during worldgen, you won't see items made of scale made then (whereas if you were using the raw mod, you would).
- As with standard Modest Mod, there is some jankiness when it comes to using skin/scale from different creatures. During the tanning reaction, globs of skin/scale from different creatures can be combined, making leather from whatever glob of skin/scale is selected first (not whatever is the majority material). This is somewhat of a limitation from how the game's reaction system works.
- For compatibility with potential adventure mode crafting mods that are based on how tanning usually works, this is only active during fortress mode.

See help entry for usage.

## no-fort-fliers
Disables flight for creatures that can learn during fort mode. This helps avoid the potential pathfinding problems that can happen with flying citizens during fort mode, without having to completely remove flight from the creature (so you can still fly in adventure mode).

See help entry for usage.

## tame-and-train
Makes creatures available to tame as pets, train, or be available as mounts. Can be applied to specific creatures, all animals (creatures that can't learn), or all creatures (probably causing a lot of weirdness). Because this isn't active during worldgen, it shouldn't have an effect on what creatures get tamed and trained during it.

See help entry for usage.

## web-spray-rates
Ever get annoyed that the rate that creatures can spray immobilizing webs in vanilla mode is so high that they can permanently stunlock you? This modifies the wait period of all natural creature interactions that spray webs, by a provided multiplier (also allowing you to make them fire even faster, if you're crazy like that). Because this is implemented in code, the changes also apply to generated creatures with webbing abilities.

See help entry for usage.

## world-patch
Not intended to be run as a script by itself. It works as a handler for the patches, managing when to run the code of each patch that registers itself to it. It was originally also intended to provide sets of useful functions for handling some more standard style of patches (such as some handler for applying patches to creatures), but nothing has been included as of yet. Currently, all patches use their own bespoke custom code for applying their effects, and only take place during world loads.

(Documentation might go here at some point - otherwise just look at the code and examples here to figure it out for yourself if you're interested in using it :p The main functions you want to look at are `world-patch`'s `register_patch`, and the `register_patch` and `patch_code` functions of the patch examples)
