-- Register creatures or entities as not requiring certain clothes.
-- Allows for playing custom civs / creatures where clothing is supposed to be optional, without having to completely remove their bashfulness.
-- This works by periodically resetting the clothing anger timer on affected units, meaning they never get angry enough to generate a bad thought.
--@ module = true
local help = [====[

clothing-optional
=================
Register creatures or entities as not requiring certain clothes, avoiding bad thoughts for not having them.
This script requires that it be called from an ``onLoad.init``, or while a world is loaded.
Requires both a target, and clothing modifiers. A target will be used, plus any number of clothing modifiers.

Valid targets:

:-creature <creature token>:
	The exemption will apply to all creatures of the given token. An example token would be DWARF.
:-entity <entity token>:
	The exemption will apply to anyone belonging to an entity of the given token. An example token would be PLAINS.
	Note that pets and animals are also considered members of an entity.
	
Valid modifiers:

:-all:
	The target won't get upset about having no shirts, pants, or shoes.
:-shirt:
	The target won't get upset about having no upper body coverage.
:-pants:
	The target won't get upset about having no lower body coverage.
:-shoes:
	The target won't get upset about having no shoes.
Example:

The following will make all dwarves be fine shirtless and shoeless:
``clothing-optional -creature DWARF -shirt -shoes``

]====]

local utils = require 'utils'
local validArgs = utils.invert({
  "help",
	"entity",
	"creature",
	"all",
	"shirt",
	"pants",
	"shoes",
})

registered = registered or {creatures = {}, entities = {}} -- Stores all registered exemptions until world is unloaded.
loop = loop or nil -- Stores current dfhack timeout for loop purposes (see: mainLoop)
rate = rate or 3000 -- Rate at which check repeats itself

--[[ For reference (somewhat accurate):
	Clothing checks occur when unit has no job, and has a cooldown of ~5000 ticks.
	If a unit is lacking a clothing type, 10,000 points of anger is generated for that type (which decreases 1 per tick)
	Once anger for clothing hits the cap of 20,000 points, an anger thought is generated
	This means that to go from no anger to max, the fastest this can happen is within 3 failed clothing checks.
	I'm not sure if newly generated units can start with anger, so I've set the rate as more often than clothing checks just to be on the safe side. If this proves to be too often, simply edit this file to change the rate (game will have to be restarted for the changes to take effect)
]]

function clearRegistered()
	registered = {creatures = {}, entities = {}}
end

function hasRegistered()
	return next(registered.creatures) ~= nil or next(registered.entities) ~= nil
end

---------------------------------------------------------------------
function addToEntry(entry, exemptionCode)
	if exemptionCode == "all" then
		entry.shirt = true
		entry.pants = true
		entry.shoes = true
	elseif exemptionCode == "shirt" then
		entry.shirt = true
	elseif exemptionCode == "pants" then
		entry.pants = true
	elseif exemptionCode == "shoes" then
		entry.shoes = true
	end
end

function addCreatureExemption(creatureToken, exemptionCode)
	-- Ensure there's an entry for the creature
	if registered.creatures[creatureToken] == nil then
		registered.creatures[creatureToken] = {}
	end
	local entry = registered.creatures[creatureToken]
	
	addToEntry(entry, exemptionCode)
	refresh()
end

function addEntityExemption(entityToken, exemptionCode)
	-- Ensure there's an entry for the entity
	if registered.entities[entityToken] == nil then
		registered.entities[entityToken] = {}
	end
	local entry = registered.entities[entityToken]
	
	addToEntry(entry, exemptionCode)
	refresh()
end
---------------------------------------------------------------------
-- Creature Related:
-- Returns true if creature of given token has the given clothing type as an exemption
-- Valid clothing types are "shirt", "pants", "shoes"
function getCreatureExemption(creatureToken, clothingType)
	if not registered.creatures[creatureToken] then
		return false
	end
	
	return registered.creatures[creatureToken][clothingType] == true
end

-- Returns true if creature of given token has registered shirt exemption
function creatureHasShirtExemption(creatureToken)
	return getCreatureExemption(creatureToken, "shirt")
end
-- Returns true if creature of given token has registered pants exemption
function creatureHasPantsExemption(creatureToken)
	return getCreatureExemption(creatureToken, "pants")
end
-- Returns true if creature of given token has registered shoes exemption
function creatureHasShoesExemption(creatureToken)
	return getCreatureExemption(creatureToken, "shoes")
end

-- Entity Related:
-- Returns true if entity of given token has the given clothing type as an exemption
-- Valid clothing types are "shirt", "pants", "shoes"
function getEntityExemption(entityToken, clothingType)
	if not registered.entities[entityToken] then
		return false
	end
	
	return registered.entities[entityToken][clothingType] == true
end

-- Returns true if entity of given token has registered shirt exemption
function entityHasShirtExemption(entityToken)
	return getEntityExemption(entityToken, "shirt")
end
-- Returns true if entity of given token has registered pants exemption
function entityHasPantsExemption(entityToken)
	return getEntityExemption(entityToken, "pants")
end
-- Returns true if entity of given token has registered shoes exemption
function entityHasShoesExemption(entityToken)
	return getEntityExemption(entityToken, "shoes")
end

-- Unit Related:
function getUnitExemption(unit, clothingType)
	-- First check unit's entity for exemption
	if unit.civ_id and unit.civ_id ~= -1 then -- (Not sure how wild animals work)
		-- Just this civ_id check is used internally in DFHack code, rather than also checking the unit's soul / entity links, so I'll assume that's all that's needed
		local entity = df.historical_entity.find(unit.civ_id)
		if getEntityExemption(entity.entity_raw.code, clothingType) then
			return true
		end
	end
	
	-- Otherwise, check unit's creature for exemption
	if getCreatureExemption(df.creature_raw.find(unit.race).creature_id, clothingType) then
		return true
	end
	
	-- If we get here, then they have no exemption
	return false
end

function unitHasShirtExemption(unit)
	return getUnitExemption(unit, "shirt")
end

function unitHasPantsExemption(unit)
	return getUnitExemption(unit, "pants")
end

function unitHasShoesExemption(unit)
	return getUnitExemption(unit, "shoes")
end

---------------------------------------------------------------------
local clothingTraitLookup = {["shirt"] = df.misc_trait_type.NoShirtAnger, ["pants"] = df.misc_trait_type.NoPantsAnger, ["shoes"] = df.misc_trait_type.NoShoesAnger}

-- Remove the anger trait for the given clothing type from a unit
-- It's slightly inefficient to do each individually, but I don't want to use my brain and worry about offsets :b
function unitScrubClothingAnger(unit, clothingType)
	for index, trait in ipairs(unit.status.misc_traits) do
		if trait.id == clothingTraitLookup[clothingType] then
			unit.status.misc_traits:erase(index)
			return
		end
	end
end

-- Remove all applicable clothing angers from given unit
function scrubUnit(unit)
	if unitHasShirtExemption(unit) then
		unitScrubClothingAnger(unit, "shirt")
	end
	
	if unitHasPantsExemption(unit) then
		unitScrubClothingAnger(unit, "pants")
	end
	
	if unitHasShoesExemption(unit) then
		unitScrubClothingAnger(unit, "shoes")
	end
end

-- Run this to go through every active unit and remove the appropriate clothing angers from them
function scrubAllPass()
	-- First check that there even are any registered exemptions
	-- If there are none, then skip doing the pass
	if not hasRegistered() then
		return
	end
	
	for index, unit in pairs(df.global.world.units.active) do
		scrubUnit(unit)
	end
end

-- This function will run periodically to trigger a scrubbing pass and set itself up to run again
-- There's no need to worry about stopping the loop, as it will happen automatically when the world is unloaded
function mainLoop()
	scrubAllPass()
	loop = dfhack.timeout(rate, "ticks", mainLoop)
end

-- This is called whenever a change is made to ensure that the mainLoop is always running
-- It's automatically run whenever:
-- > The script was running when the map was loaded (e.g. the command was run during an onLoad init, or had been run in the current DF session)
-- > An exemption is added (e.g. the script was called via a script or command line prompt)
function refresh()
	if loop == nil and dfhack.isWorldLoaded() and not dfhack.world.isLegends()  then
		-- Trigger the mainLoop starting
		mainLoop()
	end
end
---------------------------------------------------------------------
dfhack.onStateChange.clothingOptionalStateChange = dfhack.onStateChange.clothingOptionalStateChange or function(code)
	if code == SC_WORLD_UNLOADED then
		clearRegistered()
		loop = nil -- The loop will disable itself on unload anyway, so we just have to clear our record of it
	elseif code == SC_MAP_LOADED then
		-- Try to start the loop if it isn't already running
		refresh()
	end
end

function main(...)
	local args = utils.processArgs({...}, validArgs)
	
	if args.help then
		print(help)
		return
	end
	
	if not dfhack.isWorldLoaded() then
		qerror("Script must only be run when world is loaded.")
		return false
	end
	
	if dfhack.world.isLegends() then
		-- We don't want this to be running in legends mode, so just abort
		return
	end
	
	if not args.entity and not args.creature then
		qerror("Please provide an entity or creature to target with -entity or -creature.")
		return false
	end
	
	if args.creature then
		if args.shirt then addCreatureExemption(args.creature, "shirt") end
		if args.pants then addCreatureExemption(args.creature, "pants") end
		if args.shoes then addCreatureExemption(args.creature, "shoes") end
		if args.all then
			addCreatureExemption(args.creature, "shirt")
			addCreatureExemption(args.creature, "pants")
			addCreatureExemption(args.creature, "shoes")
		end
	end -- Won't use an elseif here, so you can technically assign an entity and a creature with 1 command
	if args.entity then
		if args.shirt then addEntityExemption(args.entity, "shirt") end
		if args.pants then addEntityExemption(args.entity, "pants") end
		if args.shoes then addEntityExemption(args.entity, "shoes") end
		if args.all then
			addEntityExemption(args.entity, "shirt")
			addEntityExemption(args.entity, "pants")
			addEntityExemption(args.entity, "shoes")
		end
	end
end

if not dfhack_flags.module then
	main(...)
end
