--Automagic version of adventurer-freedom which makes (most) adventurer-freedom changes automatically

--[[
Lacks following legacy features:
	Ability to select a specific caste.
	Ability to set skill + attribute point pool.
	Ability to change appearance (technically not part of legacy either but sush :P)
]]

--[[
--TODO: 
	Nada :D
]]
local view = df.global.gview.view.child

--We only want this to be doing anything during adventurer setup
--Unfortunately, because there's a slight delay between when onLoad launches this script and when the view is updated, we have to use a slightly clunkier method to test if the script should abort
--Since I want this near the top of the script it also means I have to declare onStep here
local onStep

local function canGo()
	view = df.global.gview.view.child --Update the view to test properly
	--Interestingly, having a delay of 100 frames means that the script never executes during the updating region screen, though I still check just in case :P
	if df.global.gamemode == 1 and (df.viewscreen_setupadventurest:is_instance(view) or df.viewscreen_update_regionst:is_instance(view)) then
		--print("DEBUG: Letsa go!")
		onStep()
	else
		--print("DEBUG: Not in adventure setup")
	end
end

local frameDelay = 100 --I'm paranoid that playing at different speeds might screw something up, so this variable is available for editing. Yes, I realise this is just one line above where you could just edit the argument itself, but I'm future proofing in case I need to have a function adapt the delay based on the FPS caps :P
local delay = dfhack.timeout(frameDelay,"frames",canGo)

--Settings

--Automatic toggles. If you don't want some of the scripts automatic features, set its toggle to false
local autoAnyEntity					= true --Makes every entity available to play as
local autoOutsider						= true --Makes every creature able to start as an outsider. Redundant if autoAnyEntity is enabled
local autoNaturalSkills				= true --Automatically patches in natural skills if playing as a creature with natural skills
local autoAnySkills					= true --Makes every skill available to purchase
local autoEveryCreature			= true --Makes every creature available to use (placed in the intelligent wilderness creatures tab). Particular types of generated creatures can be disabled with settings below.
local settingOnlyCleanEntities		= true --Makes it so the buggy underground civs don't come up as an option when making every entity available

--Generated creatures toggles. If you don't want to have the option to play as them, set its toggle to false
local beAngel 	= true		--Angel
local beDemon	= true		--Demon
local beBeast 	= true		--Forgotten Beast
local beTroll		= true		--Night Troll
local beWere 	= true		--Werebeast
local beTitan		= true		--Titan
local beBogey 	= true		--Bogeyman

--Various blacklists to control what comes up as available
local blacklist = {}
blacklist.creature = {}
--If you don't want certain creatures to be available on the list created by autoEveryCreature, then add their creature_id to blacklist.creature
--For example, if you didn't want dragons available you'd write the following (although obviously not commented out):
-- blacklist.creature["DRAGON"] = true

blacklist.skill = {} 
--If you don't want certain skills coming up from autoAnySkills then add either the skill id, or the allcaps skill token to blacklist.skill. Useful if you don't want the skills currently unused in the game to show up.
--For example, if you wanted to stop carpentry from showing up you could either write
-- blacklist.skill[2] = true
-- or you could write
-- blacklist.skill["CARPENTRY"] = true

--Misc Settings
local silent = true --If true, the script won't report what it's doing in the dfhack command window
local reportExotic = true --If true, the script will print a generated creature's description into the dfhack command window if one was picked before transitioning to the entity selection page. Ignores the silent setting.
local prompts = true --If true, the script will print prompts into the dfhack console whenever it's suitable to use one of my (Atkana's) other scripts to achieve certain effects that this script can't. Ignores the silent setting

--/Settings

local creatures = df.global.world.raws.creatures.all

--statusSkills used to determine how many skill points should be set after refreshing the skills list
local statusSkills = {}
statusSkills[0] = 35		--Peasant
statusSkills[1] = 95		--Hero
statusSkills[2] = 161		--Demigod

--All the variables relating to repeating are declared later on so it's all grouped together

local function announce(arg)
	if not silent then
		print("Auto Freedom: " .. arg)
	end
end

local function prompt(arg)
	--If/When I learn how to detect what scripts a user has installed, I could do some fancy checks to only give prompts for scripts they have.
	if prompts then
		print("AF Prompt: " .. arg)
	end
end

--If player's caste has natural skills, adds those to their skills. Doesn't require the race to have been selected
local function naturalSkills()
	local caste = creatures[view.adventurer.race].caste[view.adventurer.caste]
	if #caste.natural_skill_id > 0 then
		for i=0, #caste.natural_skill_id-1 do
			local skill = caste.natural_skill_id[i]
			local level = caste.natural_skill_lvl[i]
			view.adventurer.skills[df.job_skill[skill]] = level
		end
	end
	
	announce("Added natural skills.")
end

--Used to reset any skill changes and reset the skill points amount to the number befitting the adventurer's status
local function resetSkills()
	local skills = view.adventurer.skills
	for k, v in pairs(skills) do
		skills[k] = 0
	end
	
	view.skill_points_remaining = statusSkills[view.adventurer.status]
	
	announce("Reset skill purchases.")
end

local prevWildPosition --Created by onEntityPage(). Records the position of the last selected creature so user doesn't have to scroll through again. Unfortunately seems like its too quick to work.
-- . Places all the creatures into the wild creatures tab to maintain some illusion of orderliness
local function anyCreature()
	view.wild_creature_ids = {}
	
	for i=0, #creatures-1 do
		local current = creatures[i]
		local reject = false
		--Check to see if it's not a creature that's been disabled in the settings
		if current.flags.GENERATED == true then --Slight safety check for non-vanilla environments
			if current.flags.CASTE_DEMON == true and not beDemon then
				--Demon
				reject = true
			elseif current.flags.CASTE_NIGHT_CREATURE_BOGEYMAN == true and not beBogey then
				--Bogeyman
				reject = true
			elseif ((#current.prefstring >= 1) and (current.prefstring[0].value == "macabre ways")) and not beTroll then
				--Night Troll
				reject = true
			elseif current.flags.CASTE_FEATURE_BEAST and not beBeast then
				--Forgotten Beast
				reject = true
			elseif current.name[0]:sub(1,4) == "were" and not beWere then --Ugh, so hacky
				--Werebeast
				reject = true
			elseif ((current.creature_id:find("HF") ~= nil) and (current.creature_id:find("DIVINE_") ~= nil)) and not beAngel then --Hacky and the HF check isn't necessary, I just wanted to make sure this one has less chance of breaking
				--Angel
				reject = true
			elseif current.flags.CASTE_TITAN == true and not beTitan then
				--Titan
				reject = true
			end
		end
		
		--Check if the creature is blacklisted
		if blacklist.creature[current.creature_id] then
			reject = true
		end
		
		if not reject then
			view.wild_creature_ids:insert("#", i)
		end
	end
	
	--If we've been here before, it'd be nice if it remembered where we left off
	if not prevWildPosition then
		view.wild_creature_idx = 0
	else
		view.wild_creature_idx = prevWildPosition
	end
	
	announce("Added creatures to the wilderness creature list.")
end

--Reports the description of the chosen race. Used when transitioning to skills page after selecting a Generated creature
local function exoticDescription()
	--print(creatures[view.adventurer.race].caste[view.adventurer.caste].description)
	--Since most (if not maybe all) generated creatures have the same description across castes (if they even have more than one), and because until the skill page the adventurer won't be assigned an actually inbounds caste number, we'll use caste[0].
	print(creatures[view.adventurer.race].caste[0].description)
end

--Sets flags for currently selected race so that (hopefully) it'll allow the option to press g to change castes during the Background screen
local function tempAccess()
	local race = creatures[view.adventurer.race]
	for i = 0, #race.caste-1 do
		race.caste[i].flags.LOCAL_POPS_CONTROLLABLE = true
		race.caste[i].flags.OUTSIDER_CONTROLLABLE = true
		race.caste[i].flags.LOCAL_POPS_PRODUCE_HEROES = true
	end
	
	announce("Temporarily made all of adventurer's race controllable.")
end

local function tempSmart()
	local race = creatures[view.adventurer.race]
	--This ignores announcement rules
	race.caste[view.adventurer.caste].flags.CAN_LEARN = true
	print("Note that in order for skill changes to be applied, CAN_LEARN has temporarily been enabled for your caste. Save and reload after finishing to rectify this.")
end

local function anyEntity()
	local gent = df.global.world.entities.all
	
	--Clear the entity list
	view.home_entity_ids = {}
	
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
	
	announce("Updated entity list to include all* entities.")
end

local function anySkills()
	local maxSkill = 134 -- Can't work out how to find the length of skills table so this is hardcoded :P
	
	--clear skill list
	view.skill_list = {}
	for i = 0, maxSkill do
		if blacklist.skill[i] or blacklist.skill[df.job_skill[i]] then --skill is blacklisted
			--Do nothing
		else
			view.skill_list:insert("#", i)
		end
	end
	
	announce("Updated skill list to include everything.")
end

local function beOutsider()
	local alreadyOutsider = false
	for k, v in pairs(view.home_entity_ids) do
		if v == -1 then
			alreadyOutsider = true
		end
	end
	if alreadyOutsider == false then
		view.home_entity_ids:insert("#", -1)
		announce("Outsider option added.")
	end
end
------------------------------------

local repeater
local prevPage
local currentPage
local prevCaste --Used later to detect if caste has been changed to determine if the skills page should be refreshed

--The following are called any time onStep detects a page has changed

local function onStartPage() --Page 0
	--Nothing here at the moment.
end

local function onAnimalPage() --Page 1
	--A new list is generated whenever the category is opened
	if autoEveryCreature then
		anyCreature()
	end
end

local function onUnretirePage() --Page 2
	--Nothing here at the moment.
end

local function onEntityPage() --Page 3
	--The entity page technically doesn't need refreshing when returning from the Skills page, but I don't see any harm in doing so anyway
	if autoAnyEntity then
		anyEntity()
	elseif autoOutsider then
		beOutsider()
	end
	
	--If transitioning from the animal page with a generated creature, post its description into the DFhack console (unless disabled)
	if reportExotic and prevPage == 1 and creatures[view.adventurer.race].flags.GENERATED then
		exoticDescription()
	end
	
	--Remember where the cursor was last in the Intelligent Wilderness Creature table if coming from there
	if prevPage == 1 then
		prevWildPosition = view.wild_creature_idx
	end
end

local function onSkillsPage() --Page 4
	prevCaste = view.adventurer.caste
	--This is the first instance of a special case. Since nothing is changed by the game when transitioning backwards from the background page to here, we shouldn't make any changes.
	if prevPage == 7 then
		--Quick, look like you're doing something!
	else
		--I'm not sure if the following should happen on this page or the next, so I'm performing it here
		tempAccess()
		
		if autoAnySkills then
			anySkills()
		end
		
		resetSkills() --Quick cleanup just incase anything's been entered
		
		if autoNaturalSkills then
			naturalSkills()
			prompt("If you want your natural skills to properly reflect your caste (i.e. if you're playing a creature with natural skills that vary by castes), you should use adventurer-freedom to set it now. Do this before altering Skill/Attribute point pools.")
		end
		prompt("If you want to set how many Skill/Attribute points you have available to spend, you should use adventurer-freedom now.")
	end
end

local function onBackgroundPage() -- Page 7
	--Nothing here at the moment.
end

local function onAppearancePage() -- Page 5
	--Nothing here at the moment.
	prompt("Now is the earliest time you can use change-appearance to alter your appearance. Note that the description on this page won't update to reflect any changes, but they will have been made.")
end

local function onValuesPage() -- Page 6
	--Nothing here at the moment.
	if creatures[view.adventurer.race].caste[view.adventurer.caste].flags.CAN_LEARN == false then
		tempSmart()
	end
	
end

-------------------------------------


local pageCommands = {}
pageCommands[0] = onStartPage
pageCommands[1] = onAnimalPage
pageCommands[2] = onUnretirePage
pageCommands[3] = onEntityPage
pageCommands[4] = onSkillsPage
pageCommands[5] = onAppearancePage
pageCommands[6] = onValuesPage
pageCommands[7] = onBackgroundPage
pageCommands[8] = onNoPage

--All the fancy code goes in here
function onStep()
	view = df.global.gview.view.child
	--First, check we're still working on an adventurer. Otherwise exit early
	if df.viewscreen_setupadventurest:is_instance(view) then
		--The script will keep running. Why am I not just testing if it isn't true and just doing the stuff in the else part? No Idea.
	else
		--Our job here is done!
		if prevPage == 6 then --Finished creating an adventurer, probably. Technically the user might've found some way to abort on the last page but I wouldn't know how to check :P
			announce("Adventure awaits, go find it!")
		else
			announce("Adventurer creation aborted")
		end
		dfhack.timeout_active(repeater, nil)
		return
	end

	--If this is the first time running:
	--The script should only ever start on the first page, but we'll allow it to adapt to being launched on any page - nothing majorly bad should happen because of it, some things might break, though.
	if prevPage == nil and currentPage == nil then
		prevPage = view.page
		currentPage = view.page
		pageCommands[currentPage]()
	end
	
	--Set the current page
	currentPage = view.page
	
	--If the page has changed, trigger the new page's function
	if currentPage ~= prevPage then
		pageCommands[currentPage]()
		prevPage = currentPage
	end
	
	--Special doohickey. Detects if the adventurer's caste has been changed by an outside source and updates natural skills accordingly
	if currentPage == 4 and prevCaste ~= view.adventurer.caste then
		if autoNaturalSkills then
			resetSkills()
			naturalSkills()
			announce("Detected a change in caste and updated natural skills accordingly.")
			prevCaste = view.adventurer.caste
		end
	end
		
	--Make sure to keep repeating this function every frame so we can detect changes
	repeater = dfhack.timeout(1,"frames",onStep)
end