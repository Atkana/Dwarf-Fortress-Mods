-- Changes the name of a world's Forgotten Beasts.

--[====[

rename-beasts
===========
Permanently changes the names of all Forgotten Beasts in a given save.
Requires ``-singular`` ``-plural`` and ``-adjective`` entry for the new names.

Example: ``rename-beasts -singular "Fun Beast" -plural "Fun Beasts" -adjective "Fun Beast"``

]====]
local utils=require('utils')

local validArgs = utils.invert({
 'singular',
 'plural',
 'adjective',
})

local args = utils.processArgs({...}, validArgs)

if not args.singular or not args.plural or not args.adjective then
	qerror("You must enter names for singular, plural, and adjectives.")
end

if not dfhack.isWorldLoaded() then
	qerror("A world must be loaded before running this script!")
end

function renameCreature(creatureRaw, singular, plural, adjective, doCaste, editRaws)
	local editRaws = editRaws or false
	local doCaste = doCaste or false
	local creature = creatureRaw

	-- Change the temporary values
	-- Creature name
	creature.name[0] = singular
	creature.name[1] = plural
	creature.name[2] = adjective
	
	-- Caste name(s)
	if doCaste == true then
		for index, _ in pairs(creature.caste) do
			creature.caste[index].caste_name[0] = singular
			creature.caste[index].caste_name[1] = plural
			creature.caste[index].caste_name[2] = adjective
		end
	end
	-- (Note: Not bothering with baby/child names)
	
	-- Edit the generated raws
	if editRaws == true then
		for index, _ in pairs(creature.raws) do
			if string.find(creature.raws[index].value, "%[NAME:") then
				creature.raws[index].value = "[NAME:" .. singular .. ":" .. plural .. ":" .. adjective .. "]"
			elseif doCaste == true and string.find(creature.raws[index].value, "%[CASTE_NAME:") then
				creature.raws[index].value = "[CASTE_NAME:" .. singular .. ":" .. plural .. ":" .. adjective .. "]"
			end
		end
	end
end

local count = 0
for index, creatureRaw in pairs(df.global.world.raws.creatures.all) do
	if creatureRaw.flags.CASTE_FEATURE_BEAST == true then
		renameCreature(creatureRaw, args.singular, args.plural, args.adjective, true, true)
		count = count + 1
	end
end

print("Renamed " .. count .. " creatures.")
