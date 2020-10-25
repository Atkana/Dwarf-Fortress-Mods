-- Add an existing unit or animal to your fort.
--@ module = true
-- Created for dfhack version 0.47.04-r2
-- Release 1

local help = [====[

make-citizen
============
Add an existing unit or animal to your fort, or any entity.
While in fort mode, all you need to do is select a unit and run the script.

``-entity <ENTITY ID>``:
		The ID of the entity the unit will belong to.
		If not provided, this will be the current fortress government.
``-unit <UNIT ID>``:
		The ID of the unit to add to an entity.
		If not found/provided, the script will try defaulting to the currently selected unit.
``-histfig``:
		Include to force the unit to be made into a historical figure if they aren't already.
		This is required for units to properly join your fort as citizens.
		Some units that you might think are historical figures (like caravan guards) actually aren't!
``-tame``:
		Include if you want the unit to be tamed and domesticated.

Example usage:
Convert a person: `make-citizen -histfig`
Convert an animal: `make-citizen -tame`
]====]

local utils = require 'utils'

local validArgs = utils.invert({
    'help',
		'entity',
		'unit',
		'tame',
		'histfig'
})

--[[ TODO:
- Add options to recruit as performers, monster slayers, mercenaries, etc. to replicate some base-game stuff.
- Handle riders...
- Historical events
]]

-- Turn the given unit into a citizen of the given entity.
-- Use this for historical figures, and make_basic for non-historical units.
-- If a SiteGovernment is given as the entity, this will make the historical figure a member of that government's Civilization as well.
-- Setting `remove_former_links` to `true` replicates the default game behaviour of changing membership links to other SiteGovernments into former links (provided the entity they're being linked to is a SiteGovernment)
function make_citizen(unit, entity, remove_former_links)
	local histfig = df.historical_figure.find(unit.hist_figure_id)

	-- First, make a citizen of the major civilization (if applicable)
	if entity.type ~= df.historical_entity_type.Civilization then
		local parent_entity = get_entity_parent(entity)
		
		if parent_entity ~= nil then
			link_histfig_and_entity(histfig, parent_entity, remove_former_links)
			-- The set_civilization call later will already make the unit part of the parent entity, so no need to call it here.
		end
	end
	
	-- Link historical figure and entity together
	link_histfig_and_entity(histfig, entity, remove_former_links)
	
	-- Try to update the unit's whereabouts to be settled in the entity's site, if the entity has one.
	local site =	get_entity_residence(entity)
	if site ~= nil then
		set_settled(histfig, site)
	end
	
	-- Update their basic information
	set_civilization(unit, entity)
end

-- Add a non-historical unit to an entity.
function make_basic(unit, entity, tame)
	set_civilization(unit, entity)
end

-- Set a given unit's primary civilization to belong to the given entity.
-- If a site government entity is given, it will attempt to find the parent civilization and use that (the basic allegiances in-game are based on Civilizations)
-- Works on both regular units and historical figures.
-- Note that this doesn't do all the important linking - use make_citizen / make_basic for that!
function set_civilization(unit, entity)
	local parent_entity
	
	-- Try to get the parent entity, but if that fails just use the given entity.
	if entity.type ~= df.historical_entity_type.Civilization then
		parent_entity = get_entity_parent(entity) or entity
	else
		parent_entity = entity
	end
	
	-- Set the civ ids
	unit.civ_id = parent_entity.id
	if unit.hist_figure_id ~= -1 then
		local histfig = df.historical_figure.find(unit.hist_figure_id)
		histfig.civ_id = parent_entity.id
	end
	-- (Note that personality civ_id entries aren't changed - this is how it is for default game logic)
end

-- Make a unit tame
function tame_unit(unit)
	unit.flags1.tame = true
	unit.training_level = df.animal_training_level.Domesticated
end

-- Update the historical figure's whereabouts to record them as having settled at a site.
-- I don't know how important this actually is, but might as well do it.
-- In-game, when you accept a petition to stay (before full citizenship), a histfig's whereabouts are changed from visitor to settler.
function set_settled(histfig, site)
	histfig.info.whereabouts.whereabouts_type = df.whereabouts_type.settler
	histfig.info.whereabouts.site = site.id
end

-- Perform all the linking necessary to join a historical figure with an entity (and vice-versa)
-- Setting `remove_former_links` to `true` replicates the default game behaviour of changing membership links to other SiteGovernments into former links (provided the entity they're being linked to is a SiteGovernment)
function link_histfig_and_entity(histfig, entity, remove_former_links)
	local was_member = is_histfig_member(histfig, entity)
	-- Add the links to the new entity to the historical figure
	add_entity_to_histfig(histfig, entity, remove_former_links)
	
	-- Add the links to the historical figure to the entity
	add_histfig_to_entity(histfig, entity)
	
	if not was_member then
		-- Make a world event if linking to a Civilization (or does it apply to any entity?)
		-- TODO
	end
end

-- Update a historical figure's entity links to include their new entity
-- Setting `remove_former_links` to `true` replicates the default game behaviour of changing membership links to other SiteGovernments into former links (provided the entity they're being linked to is a SiteGovernment)
function add_entity_to_histfig(histfig, entity, remove_former_links)
	-- Perform a couple of different things on the already existing entity links
	for index = 0, #histfig.entity_links - 1 do
		local entry = histfig.entity_links[index]
		local linked_entity = df.historical_entity.find(entry.entity_id)
		local link_strength = entry.link_strength

		-- If a current member of a different site government, set that link to a former link
		-- (Assuming remove_former_links is true and that the entity we're linking to is a SiteGovernement)
		if remove_former_links and entity.type == df.historical_entity_type.SiteGovernment and entry._type == df.histfig_entity_link_memberst and linked_entity.id ~= entity.id and linked_entity.type == df.historical_entity_type.SiteGovernment then
			histfig.entity_links:erase(index)
			histfig.entity_links:insert(index,{new = df.histfig_entity_link_former_memberst, entity_id = linked_entity.id, link_strength = link_strength})

			remove_histfig_from_entity(histfig, linked_entity)
		end
		
		-- If a former member of the new entity, replace that with a current member link instead!
		-- (Not sure if this is actually how the game handles these situations)
		if entry._type == df.histfig_entity_link_former_memberst and linked_entity.id == entity.id then
			histfig.entity_links:erase(index)
			histfig.entity_links:insert(index,{new = df.histfig_entity_link_memberst, entity_id = entity.id, link_strength = 100})
		end
	end

	-- Create new link, provided not already listed as a member
	if not is_histfig_member(histfig, entity) then
		histfig.entity_links:insert("#",{new=df.histfig_entity_link_memberst, entity_id=entity.id, link_strength=100})
	end
end

-- Update an entity's data to add a historical figure's information (and nemesis information) if it's not already there
function add_histfig_to_entity(histfig, entity)
	-- Add historical figure data
	-- The game stores histfig data in order of ids
	local previous_id = -1
	for index = 0, #entity.histfig_ids - 1 do
		-- Find the index of the place this histfig id fits
		local current_id = entity.histfig_ids[index]
		
		if histfig.id == current_id then
			-- Histfig is already listed here!
			break
		end
		
		local here = false
		if (histfig.id > previous_id) and (histfig.id < current_id) then
			here = true
		elseif index == #entity.histfig_ids - 1 then
			here = true
		end
		
		if here == true then
			-- This current position is where the historical figure belongs
			entity.histfig_ids:insert(index, histfig.id)
			entity.hist_figures:insert(index, histfig)
			break
		else
			-- Continue searching
			previous_id = current_id
		end
	end
	
	-- Add nemesis data
	-- Make sure not already listed
	local nemesis_present = false
	for index = 0, #entity.nemesis_ids - 1 do
		local current_id = entity.nemesis_ids[index]
		
		if histfig.nemesis_id == current_id then
			-- Nemesis is already listed!
			nemesis_present = true
			break
		end
	end
	
	if not nemesis_present then
		-- The game doesn't care about id order for nemesis info, so just add it to the end
		entity.nemesis:insert("#", df.nemesis_record.find(histfig.nemesis_id))
		entity.nemesis_ids:insert("#", histfig.nemesis_id)
	end
end

-- Removes a historical figure's information (and nemesis information) from an entity
-- Note that it doesn't remove the entity_links present on the historical figure!
-- Basically, the opposite of add_histfig_to_entity
function remove_histfig_from_entity(histfig, entity)
	-- Remove historical figure entries
	for index = 0, #entity.histfig_ids - 1 do
		local current_id = entity.histfig_ids[index]
		
		if histfig.id == current_id then
			entity.histfig_ids:erase(index)
			entity.hist_figures:erase(index)
			break
		end
	end
	
	-- Remove nemesis entries
	for index = 0, #entity.nemesis_ids - 1 do
		local current_id = entity.nemesis_ids[index]
		
		if histfig.id == current_id then
			entity.nemesis:erase(index)
			entity.nemesis_ids:erase(index)
			break
		end
	end
end

-- Returns true if given historical figure is a current (not former) member of the given entity.
function is_histfig_member(histfig, entity)
	local is_member = false
	for index, entry in pairs(histfig.entity_links) do
		if (entry._type == df.histfig_entity_link_memberst) and (entry.entity_id == entity.id) then
			is_member = true
			break
		end
	end
	
	return is_member
end

-- Clean a unit of everything relevant that might have an affect on the unit being treated as an owned citizen (such as certain flags)
-- Note that I haven't really tested the extents of what is required. This is mostly based on guesses and looking at other scripts.
function clean_unit(unit)
	unit.flags1.marauder = false
	unit.flags1.merchant = false
	unit.flags1.forest = false
	unit.flags1.diplomat = false
	unit.flags1.active_invader = false
	unit.flags1.hidden_in_ambush = false
	unit.flags1.invader_origin = false
	unit.flags1.coward = false
	unit.flags1.hidden_ambusher = false
	unit.flags1.invades = false
	--unit.flags1.tame = false
	unit.flags1.royal_guard = false
	unit.flags1.fortress_guard = false
	
	unit.flags2.for_trade = false
	unit.flags2.locked_in_for_trading = false
	unit.flags2.underworld = false
	unit.flags2.resident = false -- Note for the curious: this flag is NOT about fort residence. I believe it refers to the clowns / bankers
	unit.flags2.visitor_uninvited = false
	unit.flags2.visitor = false
	unit.flags2.roaming_wilderness_population_source = false
	unit.flags2.roaming_wilderness_population_source_not_a_map_feature = false
	
	unit.flags3.wait_until_reveal = false
	
	-- Wipe any wild animal data
	unit.animal.population.region_x = -1
	unit.animal.population.region_y = -1
	unit.animal.population.unk_28 = -1
	unit.animal.population.population_idx = -1
	unit.animal.population.depth = -1
	
	-- Wipe any follow commands (otherwise guards and animals continue following their original targets)
	unit.idle_area_type = df.unit_station_type.None
	unit.follow_distance = 0
	unit.following = nil
	
	-- For now, auto-set animals to tame + domesticated (like beasts that come from trading)
	--[[
	if unit.enemy.caste_flags.SLOW_LEARNER == false or unit.enemy.caste_flags.CAN_LEARN == false then
		unit.flags1.tame = true
    unit.training_level = df.animal_training_level.Domesticated
	end
	]]
end

-- This is supposed to prevent the unit from dumping all their items on the floor, but it doesn't seem to work reliably.
function fix_inventory(unit, own)
	for index = 0, #unit.inventory - 1 do
		local item = unit.inventory[index].item
		item.flags.forbid = false
		
		if own then
			dfhack.items.setOwner(item, unit)
		end
	end
	
	-- According to notes in create-unit, this should prevent the unit dropping their items on the floor
	--unit.military.uniform_drop:resize(0)
end

-- Returns the entity entry of the Civilization that governs the given entity
-- This will fail for certain types of entities without entity links, like outcasts, guilds, performance troupes, etc. and some special uses of SiteGovernments which are solely linked to a site (like angels, evil)
function get_entity_parent(entity)
	local parent_id
	for index, entry in pairs(entity.entity_links) do
		if entry.type == df.entity_entity_link_type.PARENT then
			parent_id = entry.target
			break
		end
	end
	
	if parent_id then
		return df.historical_entity.find(parent_id)
	else
		return nil
	end
end

-- Returns the site the given entity considers its residence
-- (This is entirely guesswork as to how it works, and might be lacking some checks)
function get_entity_residence(entity)
	local site_id
	for index, entry in pairs(entity.site_links) do
		if entry.flags.residence == true then
			site_id = entry.target
			break
		end
	end
	
	if site_id then
		return df.world_site.find(site_id)
	else
		return nil
	end
end

function main(...)
    local args = utils.processArgs({...}, validArgs)

    if args.help then
			print(help)
			return
    end
		
		if not dfhack.world.isFortressMode() then
			qerror("Script must be used in Fortress Mode!")
		end
		
		-- Find entity
		local entity
		if not args.entity then
			entity = df.historical_entity.find(df.global.ui.group_id)
		else
			entity = df.historical_entity.find(tonumber(args.entity))
		end
		
		-- Find unit
		local unit
		if args.unit and tonumber(args.unit) then
			unit = df.unit.find(tonumber(args.unit))
		end
		-- If unit ID wasn't provided / unit couldn't be found,
		-- Try getting selected unit
		if unit == nil then
			unit = dfhack.gui.getSelectedUnit(true)
		end

		if unit == nil then
			qerror("Couldn't find unit.")
		end
		
		-- Begin conversion stuff
		clean_unit(unit)
		
		-- If we need to force a histfig status, we need to do some things first
		if args.histfig then
			-- Setting the civilization first is required for the later create unit functions to work properly
			set_civilization(unit, entity)
			-- Give the unit a name if they don't have one (it looks weird for historical figures to not have a name, otherwise)
			if unit.name.has_name == false then
				-- Create unit has a function for giving out names
				local entity_raw_code = entity.entity_raw.code
				dfhack.reqscript("modtools/create-unit").nameUnit(unit, entity_raw_code)
			end
			-- Create unit's createNemesis function will create a nemesis and historical figure entry for the unit
			dfhack.reqscript("modtools/create-unit").createNemesis(unit, unit.civ_id)
		end

		-- Use different methods depending on if the unit is a historical figure or not
		if unit.hist_figure_id ~= -1 then
			make_citizen(unit, entity, true)
			-- Enable labors for the unit (if possible), using a create unit function
			dfhack.reqscript("modtools/create-unit").enableUnitLabors(unit, true, true)
		else
			make_basic(unit, entity)
		end

		-- Make the unit tame, if told to
		if args.tame then
			tame_unit(unit)
		end
		
		fix_inventory(unit, unit.enemy.caste_flags.CAN_LEARN)
		
		print("Unit added to fort.")
end

if not dfhack_flags.module then
    main(...)
end
