-- Changes the name of a world's generated creatures.

--[====[

rename-beasts
===========
Permanently changes the names of all of a given type of generated creature in the current save.
Requires `-singular` `-plural` and `-adjective` entry for the new names, and
a `-type` (what creature's name to change).
Valid types: FORGOTTEN_BEAST, DEMON, UNIQUE_DEMON, ANGEL, NIGHT_TROLL, TITAN,
BOGEYMAN, WEREBEAST

Example: ``rename-beasts -type FORGOTTEN_BEAST -singular "Fun beast" -plural "Fun beasts" -adjective "Fun beast"``

]====]
local utils=require('utils')

local validArgs = utils.invert({
 'singular',
 'plural',
 'adjective',
 'type',
})
local validTypes = {
	FORGOTTEN_BEAST = true,
	DEMON = true,
	UNIQUE_DEMON = true,
	ANGEL = true,
	NIGHT_TROLL = true,
	TITAN = true,
	BOGEYMAN = true,
	WEREBEAST = true,
}

local args = utils.processArgs({...}, validArgs)

if not args.singular or not args.plural or not args.adjective then
	qerror("You must enter names for singular, plural, and adjectives.")
end

args.type = string.upper(args.type or "")

if validTypes[args.type] == nil  then
	qerror("You must provide a valid type to target. Valid types: FORGOTTEN_BEAST, DEMON, UNIQUE_DEMON, ANGEL, NIGHT_TROLL, TITAN, BOGEYMAN, WEREBEAST.")
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
	local hit = false
	
	if args.type == "FORGOTTEN_BEAST" and creatureRaw.flags.CASTE_FEATURE_BEAST == true then
		hit = true
	elseif args.type == "DEMON" and creatureRaw.flags.CASTE_DEMON == true and creatureRaw.flags.CASTE_UNIQUE_DEMON == false then
		hit = true
	elseif args.type == "UNIQUE_DEMON" and creatureRaw.flags.CASTE_UNIQUE_DEMON == true then
		hit = true
	elseif args.type == "ANGEL" and creatureRaw.source_hfid ~= -1 then
		hit = true
	elseif args.type == "NIGHT_TROLL" and creatureRaw.flags.CASTE_NIGHT_CREATURE_ANY == true and creatureRaw.flags.CASTE_NIGHT_CREATURE_HUNTER == true and (creatureRaw.caste[0].flags.CONVERTED_SPOUSE == true or creatureRaw.caste[0].flags.SPOUSE_CONVERTER == true) then
		hit = true
	elseif args.type == "TITAN" and creatureRaw.flags.CASTE_TITAN == true then
		hit = true
	elseif args.type == "BOGEYMAN" and creatureRaw.flags.CASTE_NIGHT_CREATURE_BOGEYMAN == true then
		hit = true
	elseif args.type == "WEREBEAST" and creatureRaw.flags.CASTE_NIGHT_CREATURE_ANY == true and creatureRaw.flags.CASTE_NIGHT_CREATURE_HUNTER == true and creatureRaw.caste[0].flags.CONVERTED_SPOUSE == false and creatureRaw.caste[0].flags.SPOUSE_CONVERTER == false then 
		hit = true
	end
	
	if hit == true then
		renameCreature(creatureRaw, args.singular, args.plural, args.adjective, true, true)
		count = count + 1
	end
end

print("Renamed " .. count .. " creatures.")
