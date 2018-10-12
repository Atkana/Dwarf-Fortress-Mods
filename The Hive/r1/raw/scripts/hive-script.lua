--Script used by The Hive mod to manage the hivemind

--[[ TODO:
- Make it so creating a new queen while one is already present causes the hive to try and kill it
- Something important I forgot
- Any of the TODOs listed in the script
- Adapt script so the stuff like races and civ types aren't hardcoded, and can be loaded from a config file.
- Fix units being afflicted with every effect of the syndrome regardless of probability
	Requires altering of syndrome-util. I tried patching in the support but the game just crashes.

]]

if not dfhack.world.isFortressMode(df.global.gametype) then
	--Script should only run in fortress mode
	print("DEBUG: Not in fortress mode")
	return
end

local hiveRaceId --Race id for hive creatures in this world. 

for k, v in pairs(df.global.world.raws.creatures.all) do
	if v.creature_id == "THE_HIVE" then
		hiveRaceId = k
		break
	end
end

if df.global.ui.race_id ~= hiveRaceId then
	--Script should only run in a Hive fortress
	print("DEBUG: Not a hive race")
	return
end

local eventful = require 'plugins.eventful'
local synutil = require 'syndrome-util'
local utils = require 'utils'

-----------------------
local tuning = {}
tuning.mindUpdateRate = 1200 --Time in ticks between loops (1200 ticks in a day)

-----------------------
eventful.enableEvent(eventful.eventType.UNIT_DEATH, 1)
eventful.enableEvent(eventful.eventType.JOB_COMPLETED, 0) --Might not be required, don't fully understand eventful
local mindUpdateTimer
-----------------------
local indoctrites = {} --Table of indoctrinated drones. No, I don't think "indoctrites" is an actual word. First assigned by onLoad(), then updated as new drones are indoctrinated.
--[[ Structure:
	indoctrites
		unit id	=	true
]]
local droneCasteId = 0
local queenCasteId = 1
local fortGroupId = df.global.ui.group_id
local fortGroup = df.historical_entity.find(fortGroupId)

------------------------
--Position names for every rank of hive queen:
local validPositionCodes = {
["QUEEN_5"] = true,
["QUEEN_4"] = true,
["QUEEN_3"] = true,
["QUEEN_2"] = true,
["QUEEN_1"] = true,
["QUEEN_0"] = true,
}
local queenId -- Unit id of current queen
local queenUnit -- Unit of current queen
local noQueen -- If true, there's no current queen
local queenMind --Soul of the queen
------------------------
local joinSynName = "kana_the_hive_indoctrinate"
local severSynName = "being severed from the queen"

local joinSyndrome --Syndrome given to units when indoctrinated
local joinSyndromeId --Id of above
local severSyndrome --Syndrome given to units when the queen they're linked to dies
local severSyndromeId --Id of above
------------------------


local showDebug = true
local function hiveDebug(s)
	if showDebug then
		print("Hive Debug: " .. s)
	end
end

local function updateSyndromes()
	hiveDebug("updateSyndromes: Start")
	for k, v in pairs(df.global.world.raws.syndromes.all) do
		if joinSyndrome and severSyndrome then
			break
		end
		if v.syn_name == joinSynName then
			joinSyndrome = v
			joinSyndromeId = v.id
		elseif v.syn_name == severSynName then
			severSyndrome = v
			severSyndromeId = v.id	
		end
	end
end

--Remove all drones from queen's influence. If severed is true it also inflicts them with the appropriate syndrome
local function undoctrinateAll(severed)
	for k, v in pairs(indoctrites) do
		local u = df.unit.find(k)
		--Remove the indoctrinated syndrome
		synutil.eraseSyndromes(u, joinSyndromeId)
		--Give them the severed syndrome
		if severed then
			synutil.infectWithSyndrome(u, severSyndrome, "DoNothing", false)
		end
	end
	--I could also remove all the changes that the queen made to the drones here (e.g. clear skills, wipe personality, etc.), but I like the idea of her leaving an imprint until they're joined to a new queen.
	
	--Clear the indoctrites table
	
	indoctrites = {}
end

local function updateQueenInfo()
	hiveDebug("updateQueenInfo: Start")
	local positionNonsense = {} --I hate having to work out positions =.=
	for k, v in pairs(fortGroup.positions.own) do
		positionNonsense[v.id] = v
	end
	
	--First assume there is no queen, then do the checks
	noQueen = true
	for k,v in pairs(fortGroup.positions.assignments) do
		if positionNonsense[v.position_id] and validPositionCodes[positionNonsense[v.position_id].code] then
			if v.histfig ~= -1 then --Queen Position is filled
				noQueen = false
				local queenHistFig = df.historical_figure.find(v.histfig)
				queenUnit = df.unit.find(queenHistFig.unit_id)
				local newId = queenUnit.id
				if queenId and newId ~= queenId then
					--There's a new queen assigned
					--Make sure that indoctrites is cleaned
					undoctrinateAll(false)
				end
				queenId = newId
				queenMind = queenUnit.status.current_soul
				break
			end
		end
	end
end

local function onQueenDeath()
	hiveDebug("onQueenDeath: Start")
	--OHGOD PANIC
	--Clear all the queen data. I think this won't break things?
	dfhack.gui.makeAnnouncement(df.announcement_type.SOMEBODY_GROWS_UP, {D_DISPLAY = true}, {}, "The Queen has fallen! Our bodies are naught without The Mind.", COLOR_RED, true)

	queenId = false
	queenUnit = false
	noQueen = true
	queenMind = false

	undoctrinateAll(true)
end

local function indoctrinate(unitId)
	hiveDebug("indoctrinate() - Indoctrinating " .. unitId)
	local u = df.unit.find(unitId)
	local usoul = u.status.current_soul
	local upers = usoul.personality
	--Erase skills
	hiveDebug("... erasing skills")
	usoul.skills = {}
	
	--Erase needs?
	hiveDebug("... erasing needs")
	upers.needs ={}
	
	--Give indoctrinated syndrome
	hiveDebug("... giving indoctrinated syndrome")
	synutil.infectWithSyndrome(u, joinSyndrome, "DoNothing")
	
	--Add some of the queen's traits that shouldn't update at all (to my knowledge)
	--Preferences
	--Erase preferences
	hiveDebug("... erasing preferences")
	usoul.preferences = {}
	--Set preferences to queen's
	hiveDebug("... setting preferences to queen's")
	for k, v in pairs(queenMind.preferences) do
		usoul.preferences:insert("#", {new = df.unit_preference, type = v.type, item_type = v.item_type, creature_id = v.creature_id, color_id = v.color_id, shape_id = v.shape_id, plant_id = v.plant_id, poetic_form_id = v.poetic_form_id, musical_form_id = v.musical_form_id, dance_form_id = v.dance_form_id, item_subtype = v.item_subtype, mattype = v.mattype, matindex = v.matindex, mat_state = v.mat_state, active = v.active, prefstring_seed = v.prefstring_seed})
	end
	
	--Dreams
	--Eh, dreams aren't very well mapped out in dfhack yet. For now, they'll just have no dreams whatsoever (probably won't break anything)
	hiveDebug("... erasing dreams")
	upers.dreams = {}
	
	--Add to indoctrites
	hiveDebug("... adding to indoctrites table")
	indoctrites[unitId] = true
end

--Gets changes to the unit's skill experience and adds it to the queen's. The function is run before the drone's skills are wiped and set to the queen's
local function updateFirst(unitId)
	hiveDebug("updateFirst: Start")
	local u = df.unit.find(unitId)
	local usoul = u.status.current_soul
	local upers = usoul.personality
	--Add any gained experience to the queen's skills
	--Start by iterating through unit's skills
	for k, v in pairs(usoul.skills) do
		local skill = v.id
		local totalExp = dfhack.units.getExperience(u, skill, true)
		local queenExp = dfhack.units.getExperience(queenUnit, skill, true)
		--Get the difference
		local dif = totalExp - queenExp
		
		if dif > 0 then
			local skillName = df.job_skill[skill]
			dfhack.run_script("modtools/skill-change", table.unpack({"-skill", tostring(skillName),"-mode","add","-granularity","experience","-unit",queenId,"-value",tostring(dif)}))
		end
	end
	
	--Do the same for mental attributes?
	--TODO: ^ That, if I decide to do it
end

--Updates the unit's soul to reflect the Queen's
local function updateSecond(unitId)
	hiveDebug("updateSecond() for " .. unitId)
	local u = df.unit.find(unitId)
	local usoul = u.status.current_soul
	local upers = usoul.personality
	
	--First, the skills.
	--There is probably a more efficient way to design this. For now I'll do it this way, and look into optimising it later if there's a problem
	--Clear the unit's skills
	usoul.skills = {}
	
	for k, v in pairs(queenMind.skills) do
		usoul.skills:insert("#", {new = df.unit_skill, id = v.id, rating = v.rating, experience = v.experience, unused_counter = v.unused_counter, rusty = v.rusty, rust_counter = v.rust_counter, demotion_counter = v.demotion_counter, natural_skill_lvl = v.natural_skill_lvl})
	end
	
	--Mental attributes
	--Set all the unit's mental attribute stats to match the queen's
	for k, v in pairs(queenMind.mental_attrs) do
		usoul.mental_attrs[k].value = v.value
		usoul.mental_attrs[k].max_value = v.max_value
		usoul.mental_attrs[k].improve_counter = v.improve_counter
		usoul.mental_attrs[k].unused_counter = v.unused_counter
		usoul.mental_attrs[k].soft_demotion = v.soft_demotion
		usoul.mental_attrs[k].rust_counter = v.rust_counter
		usoul.mental_attrs[k].demotion_counter = v.demotion_counter
	end
	
	--Personality stuff
	local qpers = queenMind.personality
	
	--Values
	--Clear unit's values
	upers.values = {}
	--Add queen's values
	for k, v in pairs(qpers.values) do
		upers.values:insert("#", {new = df.unit_personality.T_values, type = v.type, strength = v.strength}) --I think that's the right way to do it
	end
	--Emotions
	--Not sure if necessary?
	--Clear unit's emotions
	upers.emotions = {}
	--Not sure if needed, but the flavour is nice, so why not?
	for k, v in pairs(qpers.emotions) do
		local qflags = copyall(v.flags) --Haven't been using copyall because I don't know how well it'll work. Hopefully the fact it screws with the ordering doesn't matter
		upers.emotions:insert("#", {new = df.unit_personality.T_emotions, type = v.type, unk2 = v.unk2, strength = v.strength, thought = v.thought, subthought = v.subthought, severity = v.severity, flags = qflags, unk7 = v.unk7, year = v.year, year_tick = v.year_tick})
	end
	
	--Traits
	for k, v in pairs(qpers.traits) do
		upers.traits[k] = v
	end
	
	--Stress level
	upers.stress_level = qpers.stress_level
	
	--Current focus
	--May go weird when calculations are done for the unit
	upers.current_focus = qpers.current_focus
	--Undistracted focus.
	--Not entirely sure what it is but copying anyway. Same potential problem as above
	upers.undistracted_focus = qpers.undistracted_focus
	
	--Anything else not copied is because I'm not sure what they do :P
end

----------------------------
local function createDrone(reaction,reaction_product,unit,input_items,input_reagents,output_items,call_native)
	hiveDebug("createDrone: Start")
	--local pos = ("[ " .. unit.pos.x .. " " .. unit.pos.y .. " " .. unit.pos.z .. " ]") ----Ultimately nil, nil, nil in create-unit
	--local pos = copyall(unit.pos)
	--local pos = {unit.pos.x, unit.pos.y, unit.pos.z} --causes different error when passing plain pos. What about when passing table.unpack(pos)? Error with passing arg 10.
	--local pos = unit.pos.x .. " " .. unit.pos.y .. " " .. unit.pos.z. --Ultimately nil, nil, nil in create-unit
	--local pos = "[" .. unit.pos.x .. " " .. unit.pos.y .. " " .. unit.pos.z .. "]"
	--local pos = " [ " .. unit.pos.x .. " " .. unit.pos.y .. " " .. unit.pos.z .. " ] "
	--local pos = "[ "  .. unit.pos.x .. "," .. unit.pos.y .. "," .. unit.pos.z .. " ]"
	--local pos = tostring(copyall(unit.pos))
	--local pos = "[ " .. unit.pos.x .. " " .. unit.pos.y .. " " .. unit.pos.z .. " ]" 
	--local pos = (unit.pos.x .. " " .. unit.pos.y .. " " .. unit.pos.z)
	--local pos = "{" .. unit.pos.x .. "," .. unit.pos.y .. "," .. unit.pos.z .. "}"
	--local pos = " \\[ 1 2 3 \\] "
	
	--print(unit.pos)
	--print(pos)
	
	--[[
	dfhack.run_script("modtools/create-unit", table.unpack({
	"-race", "THE_HIVE",
	"-caste", "DRONE",
	"-setUnitToFort",
	"-name", "THE_HIVE",
	"-location", pos}))]]
	--[[
	dfhack.run_script("modtools/create-unit", table.unpack({"-race", "THE_HIVE","-caste", "DRONE","-setUnitToFort","-name", "THE_HIVE","-location", {unit.pos.x, unit.pos.y, unit.pos.z}}))]]
	--dfhack.run_script("modtools/create-unit","-race THE_HIVE -caste DRONE -setUnitToFort -name THE_HIVE -location " .. pos)
	dfhack.run_script("modtools/create-unit", table.unpack({
	"-race", "THE_HIVE",
	"-caste", "DRONE",
	"-setUnitToFort",
	"-name", "THE_HIVE",
	"-location", "[", unit.pos.x, unit.pos.y, unit.pos.z, "]",
	"-age", "0"}))
	--... so all I had to do was add the square brackets separately!? Y'know what? I'm going to leave in ALL that commented out code so anyone looking at this code can see how long it took to figure that out. There's an hour of my life I'll never get back (not that you can technically ever get any time back because it's always moving forward but that's not the point!)
	
	call_native.value = false --Should prevent the dummy product from being created
	
	dfhack.gui.makeAnnouncement(df.announcement_type.SOMEBODY_GROWS_UP, {D_DISPLAY = true}, unit.pos, "Another drone is spawned. We grow.", COLOR_CYAN, true)
end

local function createQueen(reaction,reaction_product,unit,input_items,input_reagents,output_items,call_native)
	hiveDebug("createQueen: Start")
	local flags = {D_DISPLAY = true}
	
	dfhack.run_script("modtools/create-unit", table.unpack({
	"-race", "THE_HIVE",
	"-caste", "QUEEN",
	"-setUnitToFort",
	"-name", "THE_HIVE",
	"-location", "[", unit.pos.x, unit.pos.y, unit.pos.z, "]",
	"-age", "0"}))
	
	call_native.value = false --Should prevent the dummy product from being created
	
	--If there isn't already a queen
	dfhack.gui.makeAnnouncement(df.announcement_type.SOMEBODY_GROWS_UP, flags, unit.pos, "A queen is spawned. May she guide us.", COLOR_CYAN, true)
	
	--Queens are eventually elected, so shouldn't force an update here.
	--^ That was changed because elections don't respect ALLOWED_CREATUREs, should the stance be changed?
	--TODO: Check if usurper and punish accordingly
end

eventful.registerReaction("THE_HIVE_SPAWN_DRONE", createDrone)
eventful.registerReaction("THE_HIVE_SPAWN_QUEEN", createQueen)

eventful.onUnitDeath.hiveScript = function(unit_id)
	hiveDebug("A unit died")
	if not noQueen and unit_id == queenId then
		--THE QUEEN IS DEAD, EVERYBODY PANIC
		hiveDebug("... that unit was the queen")
		onQueenDeath()
	end
end

---------------------------

local function hiveScriptLoop()
	hiveDebug("hiveScriptLoop: Beginning loop")
	--First get the info on the queen
	hiveDebug("hiveScriptLoop: Updating Queen Info")
	updateQueenInfo()
	
	--Only want to do this part if there's actually a queen
	if not noQueen then
		hiveDebug("hiveScriptLoop: There's a queen")
		--Find those who need to be joined to the hive mind
		for k, v in pairs(df.global.world.units.active) do
			if dfhack.units.isCitizen(v) then
				if not indoctrites[v.id] and v.race == hiveRaceId and v.caste == droneCasteId then
					indoctrinate(v.id)
				end
			end
		end
		--Do the first pass
		for k, v in pairs(indoctrites) do
			updateFirst(k)
		end	
		--Followed by the second
		for k, v in pairs(indoctrites) do
			updateSecond(k)
		end
	else
		hiveDebug("hiveScriptLoop: No queen, skipping queen stuff")
	end
	
	--Restart the loop
	hiveDebug("hiveScriptLoop: Resetting loop")
	mindUpdateTimer = dfhack.timeout(tuning.mindUpdateRate, "ticks", hiveScriptLoop)
end

local function onLoad()
	hiveDebug("onLoad: Starting Load")
	--Get Queen info
	updateQueenInfo()
	
	--Get the mod's syndromes
	updateSyndromes()
	
	--create indoctrites
	hiveDebug("onLoad: Building indoctrites table")
	for k, v in pairs(df.global.world.units.active) do
		if dfhack.units.isCitizen(v) then
			hiveDebug("... Found citizen")
			--If is a hive and drone caste
			if v.race == hiveRaceId and v.caste == droneCasteId then
				hiveDebug("... Citizen is hive race + drone caste")
				--THEN if they have the indoctrination syndrome...
				if synutil.findUnitSyndrome(v, joinSyndromeId) then
					hiveDebug("... Citizen has indoctrinated syndrome")
					indoctrites[v.id] = true
				end
			end
		end	
	end
	
	--Start Timers?
	hiveDebug("onLoad: Starting loop timer")
	mindUpdateTimer = dfhack.timeout(tuning.mindUpdateRate, "ticks", hiveScriptLoop)
end

onLoad()