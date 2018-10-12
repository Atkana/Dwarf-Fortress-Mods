--DFhack console-based script for playing non-standard adventurer races
--Don't try to use this code to learn stuff from, it's a mess :P Arbitrary functions, probably more 'return's than are needed.

--Settings
local settingOnlyCleanEntities = true --Governs whether entities without names will be added when using the play as any entity feature. Basically, only(?) subterranean civs have no name, and picking them has some weirdness when it comes to assigning the site you're from. 
local autoNaturalSkills = false --After changing to a new race, natural skills will automatically be patched, rather than giving a prompt


if dfhack.gui.getCurFocus() ~= "setupadventure" then
	print("Use this while setting up an adventurer!")
	return
end

local utils = require "utils"
local view = df.global.gview.view.child
local creatures = df.global.world.raws.creatures.all

--Declaring a few functions ahead of time, I didn't think I'd have to do this but I guess I do?
local raceMain

--Ugh, having to use utils.prompt_input rather than io.read() is going to be annoying
--Checkstuff
local validInputs = {}
validInputs.raceMain = {["angel"] = true, ["demon"] = true,["forgotten beast"] = true,["night troll"] = true,["werebeast"] = true,["titan"] = true,["bogeyman"] = true,["search"] = true,["exit"] = true}
validInputs.yesno = {["y"] = true, ["n"] = true}

local function isValidRaceMain(check)
	local check = string.lower(check)
	if validInputs.raceMain[check] ~= nil then
		return true, check
	else
		return false
	end
end

local function isValidYesNo(check)
	local check = string.lower(check)
	if validInputs.yesno[check] ~= nil then
		return true, check
	else
		return false
	end
end

local function isValidSearch(check)
	if check ~= "" then
		return true, check
	end
end

local currentList --Assigned in chooseFromList()
local function isValidList(check)
	local check = tonumber(check) or ""
	if check == "" or check == nil then
		return false
	end
	if check <= #currentList then
		return true, check
	end
end

local function isValidNumber(check)
	local check = tonumber(check) or ""
	if check == "" then
		return false
	else
		return true, check
	end
end

--/Checkstuff

local function chooseFromList(list, style)
	print("Enter the number of the option you wish to choose")
	currentList = list --Gotta do this because prompt_input
	for i = 1, #list do
		local out = i .. ") "
		if style == nil then -- not sure if this one will every be used?
			local out = out .. list[i]
		elseif style == "creature" then
			local creature = creatures[list[i]]
			out = out .. tostring(creature.name[0]):gsub("^%l", string.upper) .. " - " .. creature.caste[0].description
		elseif style == "caste" then
			out = out .. list[i-1].caste_id --(i-1 because class # starts at 0)
		end
		print(out)
	end
	local choice = utils.prompt_input("", isValidList)
	if style == "creature" then
		return list[choice]
	elseif style == "caste" then
		return choice
	end
end

local function chooseCaste(creature)
	if #creature.caste == 1 then
		--No caste to choose
		return 0
	else
		print("Please choose a caste")
		return (chooseFromList(creature.caste, "caste") -1)
	end
end

local function finalRaceStage(creatureid)
	local creature = creatures[creatureid]
	local race = creatureid
	local casteNum = chooseCaste(creature)
	
	print("Play as a " .. tostring(creature.caste[casteNum].caste_name[0]):gsub("^%l", string.upper) .. " (" .. creature.creature_id .. " " .. creature.caste[casteNum].caste_id .. ") ? [Y/N]")
	
	local input = utils.prompt_input("", isValidYesNo)
	if input == "y" then
		--Good
		view.adventurer.race = race
		view.adventurer.caste = casteNum
		print("Your race has been updated!")
	else
		--NO? After all this!?
		return raceMain()
	end
	
	--Should be finished, though there's one final check to make:	
	if #creature.caste[casteNum].natural_skill_id > 0 then -- The creature caste has some natural skills!
		local input
		if autoNaturalSkills == false then
			print("Bugfix: The creature you've picked has some natural skills - in vanilla DF these skills don't get given to adventurers. Would you like to rectify this, adding the skills to your character? (Only do this if you haven't invested any skill points yet) [Y/N]")
				
			input = utils.prompt_input("", isValidYesNo)
		else
			input = "y"
		end
		if input == "y" then
			for i=1, #creature.caste[casteNum].natural_skill_id do
				local alti = i-1
				local skill = creature.caste[casteNum].natural_skill_id[alti]
				local level = creature.caste[casteNum].natural_skill_lvl[alti]
				view.adventurer.skills[df.job_skill[skill]] = level
			end
		print("Your skills have been updated!")
		if creature.caste[casteNum].flags.CAN_LEARN == false then
			print("Note that in order for these changes to mean anything, CAN_LEARN has temporarily been enabled for your caste. Save and reloadafter finishing to rectify this.") -- Yeah, I was surprised of this too.
			creature.caste[casteNum].flags.CAN_LEARN = true
		end
		end
	end
end

local function searchMain()
	print("Please enter the singular name for the creature you want (e.g. giant lynx), or alternatively enter the creature's creature ID in allcaps (e.g. GIANT_LYNX). Type back if you want to go back.")
	local input = utils.prompt_input("", isValidSearch)
	if input:lower() == "back" then
		return raceMain()
	else --Something to search
		--Build search options here, or in another function?
		local searchResults = {}
		local idsOnly = false
		if input:upper() == input then --Allcaps, therefore creature ID
			idsOnly = true
		end
		for i = 1, #creatures, 1 do
			local alti = i-1
			local current = creatures[alti]
			if current.creature_id == input or (idsOnly == false and (current.name[0]:lower():find(input:lower()) or current.creature_id:lower():find(input:lower()))) then --Blimey, that's some indecipherable code. Basically: if the input matches the id, it gets selected. Otherwise, if idsOnly is false then it tries to find matches in wither the name, or creature_id
				table.insert(searchResults, alti) --Need to record the entry number (alti), rather than the creature itself.
			end
		end
		if #searchResults == 0 then
			print("Sorry, we couldn't find anything. Please enter something new.")
			return searchMain()
		elseif #searchResults == 1 then
			print("Found exactly what you were looking for")
			finalRaceStage(searchResults[1])
		else
			finalRaceStage(chooseFromList(searchResults, "creature"))
		end
	end
end

local function listGeneratedCreatures()
	local out = {}
	out.angel = {}
	out.demon = {}
	out["forgotten beast"] = {}
	out["night troll"] = {}
	out.werebeast = {}
	out.titan = {}
	out.bogeyman = {}
	for i = 1, #creatures do
		local alti = i-1
		local current = creatures[alti]
		if current.flags.GENERATED == true then --Slight safety check for non-vanilla environments
			if current.flags.CASTE_DEMON == true then
				table.insert(out.demon, alti)
			elseif current.flags.CASTE_NIGHT_CREATURE_BOGEYMAN == true then
				table.insert(out.bogeyman, alti)
			elseif (#current.prefstring >= 1) and (current.prefstring[0].value == "macabre ways") then
				table.insert(out["night troll"], alti)
			elseif current.flags.CASTE_FEATURE_BEAST then
				table.insert(out["forgotten beast"], alti)
			elseif current.name[0]:sub(1,4) == "were" then --Ugh, so hacky
				table.insert(out.werebeast, alti)
			elseif (current.creature_id:find("HF") ~= nil) and (current.creature_id:find("DIVINE_") ~= nil) then --Hacky and the HF check isn't necessary, I just wanted to make sure this one has less chance of breaking
				table.insert(out.angel, alti)
			elseif current.flags.CASTE_TITAN == true then
				table.insert(out.titan, alti)
			end
		end		
	end
	return out
end

function raceMain()
	print("Choose a category for world-unique creatures, or type search if you want to search for a creature by name/creature id. Type exit if you want to close this.")
	print("Options: Angel, Demon, Forgotten beast, Night troll, Werebeast, Bogeyman, Titan, Search, Exit")
	local input = utils.prompt_input("", isValidRaceMain)
	if input == "exit" then
		return
	elseif input == "search" then
		return searchMain()
	else --generated creature
		local gennedCreatures = listGeneratedCreatures()
		if #gennedCreatures[input] > 0 then
			finalRaceStage(chooseFromList(gennedCreatures[input],"creature"))
		else
			print("Unfortunately (or fortunately?), there are no " .. input .. "s in this world")
			return raceMain()
		end		
	end
end

local function changeSkills()
	print("Enter a number for your new available attribute point total")
	print("Game defaults are: Peasant 15 | Hero 35 | Demigod 105")
	local input = utils.prompt_input("", isValidNumber)
	view.attribute_points_remaining = input
	input = ""
	print("Enter a number for your new available skill point total")
	print("Game defaults are: Peasant 35 | Hero 95 | Demigod 161")
	input = utils.prompt_input("", isValidNumber)
	view.skill_points_remaining = input
	print("New skills and attribute totals set. Enjoy.")
end

if view.page == 4 then
	print("Would you like to choose a special race for your adventurer? [Y/N]")
	local input = utils.prompt_input("", isValidYesNo)
	if input == "y" then
		return raceMain()
	end
	input = ""
	print("Would you like to change your available Attribute and Skill points? [Y/N]")
	input = utils.prompt_input("", isValidYesNo)
	if input == "y" then
		return changeSkills()
	end
	return
elseif view.page == 3 then
	--TODO Fairly broken.
	--copypastad from Max's generventurated script
	print("Would you like to be able to start as part of any entity? [Y/N]")
	local input = utils.prompt_input("", isValidYesNo)
	if input == "y" then
		gent = df.global.world.entities.all
		--clear home_entity_ids. Might be a better way to do this but this way is the only way I know and it seems safe :P
		while #view.home_entity_ids > 0 do
			view.home_entity_ids:erase(0)
		end
		for q, r in ipairs(gent) do
			if gent[q].type==0 then
				if gent[q].name.has_name == false and settingOnlyCleanEntities == true then
					--Skip it
				else
					view.home_entity_ids:insert("#", gent[q].id)
				end
			end
		end
		view.home_entity_ids:insert("#", -1)
		return
	end
	print("Would you like to be able to play as an Outsider? [Y/N]")
	input = ""
	input = utils.prompt_input("", isValidYesNo)
	if input == "y" then
		local alreadyOutsider = false
		for k, v in pairs(view.home_entity_ids) do
			if v == -1 then
				alreadyOutsider = true
			end
		end
		if alreadyOutsider == false then
			view.home_entity_ids:insert("#", -1)
			print("Outsider option added.")
		end
		return
	end
else
	print("Use this when choosing a Civilization or Setting your skills!")
end