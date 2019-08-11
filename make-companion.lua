-- Add a target unit as an adventuring companion
-- Created for dfhack version 0.44.12-r2

-- TODO: Relationships?
-- TODO: Agreements - Without an agreement to take the made companion on an adventure, there isn't the traditional chat option to dismiss. You must use gui/companion-order's Leave command to get them to leave.

local help = [====[

make-companion
==============
Tries to turn the targeted unit into a companion for the current adventurer. Because the unit 
didn't join as part of an agreement, you'll have to use `gui/companion-order` to get them to 
leave.

Use ``-unit <UNIT ID>`` to specify a unit, otherwise the currently selected unit will be used.

The script can't make a unit who doesn't have historical figure and a nemesis record into a
companion. Use the option ``-create`` to force the script to fake these records, but be warned 
that this is experimental and could corrupt saves!

]====]

local utils = require 'utils'
local config_agreement = false -- If true, will attempt (and largely fail) to create an adventuring agreement for the made companion

local validArgs = utils.invert({
    'help',
    'unit',
	'create',
	'pet' -- I don't think this one really accomplishes anything, so it's never listed :b
})

--[[
function linkCompanionsByAgreement(agreement)
	local companionHistfig = df.historical_figure.find(agreement.parties[0].histfig_ids[0])
	local adventurerHistfig = df.historical_figure.find(agreement.parties[1].histfig_ids[0])
	
	local agreementId = agreement.id
	
	-- Note: for histfig_hf_link_companionst, anon_1 is the agreement ID, and anon_2 is the
	-- party that the histfig the link is being added to was a part of
	companionHistfig.histfig_links:insert("#", {new = df.histfig_hf_link_companionst, target_hf = adventurerHistfig.id, link_strength = 100, anon_1 = agreementId, anon_2 = 0})
	
	adventurerHistfig.histfig_links:insert("#", {new = df.histfig_hf_link_companionst, target_hf = companionHistfig.id, link_strength = 100, anon_1 = agreementId, anon_2 = 1})
end
]]

function linkCompanions(adventurerHistfig, companionHistfig, agreementId)
	-- Note: for histfig_hf_link_companionst, anon_1 is the agreement ID, and anon_2 is the
	-- party that the histfig the link is being added to was a part of
	companionHistfig.histfig_links:insert("#", {new = df.histfig_hf_link_companionst, target_hf = adventurerHistfig.id, link_strength = 100, anon_1 = agreementId, anon_2 = 0})
	
	adventurerHistfig.histfig_links:insert("#", {new = df.histfig_hf_link_companionst, target_hf = companionHistfig.id, link_strength = 100, anon_1 = agreementId, anon_2 = 1})
end

-- Creates a historical event for the given agreement
function makeAgreementEvent(agreement)
	local id = df.global.hist_event_next_id
	local event = df.history_event_agreement_formedst:new()
	
	event.id = id
	event.year = agreement.details[0].year
	event.seconds = agreement.details[0].year_tick
	event.agreement_id = agreement.id
	
	event.flags:resize(8)
	event.flags[0] = false
	event.flags[1] = false
	event.flags[2] = false
	event.flags[3] = false
	event.flags[4] = false
	event.flags[5] = false
	event.flags[6] = false
	event.flags[7] = false
	
	df.global.world.history.events:insert("#", event)
	df.global.hist_event_next_id = id + 1
end

-- Creates an agreement to go adventuring between the two historical figures
-- An agreement is needed for the dismiss dialogue to appear in the talk menu
function makeAdventureAgreement(adventurerHistfig, companionHistfig)
	local id = df.global.agreement_next_id
	local agreement = df.agreement:new()
	
	-- Misc.
	agreement.id = id
	-- anon_1-3 are the coords that the agreement took place.
	-- I don't know how they're calculated, so we'll just use the adventurer's army's last position
	agreement.anon_1 = df.global.ui_advmode.unk_1
	agreement.anon_2 = df.global.ui_advmode.unk_2
	agreement.anon_3 = df.global.ui_advmode.unk_3
	
	-- Party 0 is the companion
	local companionParty = df.agreement.T_parties:new()
	companionParty.histfig_ids:insert("#", companionHistfig.id)
	
	agreement.parties:insert("#", companionParty)
	-- Party 1 is the player
	local playerParty = df.agreement.T_parties:new()
	playerParty.id = 1
	playerParty.histfig_ids:insert("#", adventurerHistfig.id)
	
	agreement.parties:insert("#", playerParty)
	agreement.next_party_id = 2
	
	-- Details
	local detail = df.agreement.T_details:new()
	detail.year = df.global.cur_year
	detail.year_tick = df.global.cur_year_tick
	
	--[[
	detail.data.data1.reason = 1
	detail.data.data1.anon_1 = 0
	detail.data.data1.anon_2 = 1
	detail.data.data1.site = -1
	detail.data.data1.artifact = -1
	detail.data.data1.anon_3 = -1
	]]
	--detail.data = df.agreement.T_details.T_data:new()
	detail.data = {new = true}
	detail.data.data0 = {new = true}
	detail.data.data1 = {new = true}
	
	detail.data.data0.anon_1 = 1
	detail.data.data0.anon_2 = 0
	detail.data.data0.anon_3 = 1
	detail.data.data0.anon_4 = -1
	detail.data.data0.anon_5 = -1
	detail.data.data0.anon_6 = -1
	
	detail.data.data1.reason = 1
	detail.data.data1.anon_1 = 0
	detail.data.data1.anon_2 = 1
	detail.data.data1.site = -1
	detail.data.data1.artifact = -1
	detail.data.data1.anon_3 = -1
	
	agreement.details:insert("#", detail)
	agreement.next_details_id = 1
	
	-- Add the agreements to the game
	df.global.world.agreements.all:insert("#", agreement)
	df.global.agreement_next_id = id + 1
	
	-- Create the historic event for the creation of the agreement
	makeAgreementEvent(agreement)
	
	return agreement
end

-- 
-- This isn't actually used by this script, and was intended to be added to companion-order, but it still fails to properly end an agreement
function concludeAdventure(adventurerHistfig, companionHistfig)
	local adventurerNemesis = dfhack.units.getNemesis(df.unit.find(adventurerHistfig.unit_id))
	
	-- Remove the companion from the adventurer's companion list
	for index, nemesisId in pairs(adventurerNemesis.companions) do
		if nemesisId == companionHistfig.unit_id2 then
			adventurerNemesis.companions:erase(index)
			break
		end
	end
	
	local agreementId
	
	-- Remove hist figure link between both adventurer and companion
	for index, link in pairs(adventurerHistfig.histfig_links) do
		if df.histfig_hf_link_companionst:is_instance(link) and link.target_hf == companionHistfig.id then
			agreementId = link.anon_1
			adventurerHistfig.histfig_links:erase(index)
			break
		end
	end
	
	for index, link in pairs(companionHistfig.histfig_links) do
		if df.histfig_hf_link_companionst:is_instance(link) and link.target_hf == adventurerHistfig.id then
			agreementId = link.anon_1 -- for redundancy
			companionHistfig.histfig_links:erase(index)
			break
		end
	end
	
	-- Remove from ui companions
	for index, histfigId in pairs(df.global.ui_advmode.companions.all_histfigs) do
		if histfigId == companionHistfig.id then
			df.global.ui_advmode.companions.all_histfigs:erase(index)
			break
		end
	end
	
	-- Generate a historical event of the agreement ending
	if agreementId ~= nil and agreementId ~= -1 then
		local id = df.global.hist_event_next_id
		local event = df.history_event_agreement_concludedst:new()
	
		event.id = id
		event.year = df.global.cur_year
		event.seconds = df.global.cur_year_tick
		event.agreement_id = agreementId
		event.reason = df.history_event_reason.whim
		event.concluder_hf = adventurerHistfig.id
		event.subject_id = -1
		
		event.flags:resize(8)
		event.flags[0] = false
		event.flags[1] = false
		event.flags[2] = false
		event.flags[3] = false
		event.flags[4] = false
		event.flags[5] = false
		event.flags[6] = false
		event.flags[7] = false
		
		df.global.world.history.events:insert("#", event)
		df.global.hist_event_next_id = id + 1
	end
	
	-- TODO: Actually set the agreement as ended
end

-- Does all the necessary steps to make the targeted unit a companion of the player 
-- Note: companion unit needs a historical figure entry and a nemesis record!
function makeCompanion(adventurerUnit, companionUnit)
	-- I'm not sure how many of these edits are vital
	local adventurerHistfig = df.historical_figure.find(adventurerUnit.hist_figure_id)
	local adventurerNemesis = dfhack.units.getNemesis(adventurerUnit)
	
	local companionHistfig = df.historical_figure.find(companionUnit.hist_figure_id)
	local companionNemesis = dfhack.units.getNemesis(companionUnit)
	
	local agreementId = -1
	if config_agreement then
		-- Generate an adventuring agreement between the two
		-- (The function also creates a historical event about its creation)
		agreementId = makeAdventureAgreement(adventurerHistfig, companionHistfig).id
	end
	
	-- Link the two as historic companions
	linkCompanions(adventurerHistfig, companionHistfig, agreementId)
	
	-- Update the player's companion list
	adventurerNemesis.companions:insert("#", companionNemesis.id)
	
	-- Update the companion's group leader
	companionNemesis.group_leader_id = adventurerNemesis.id
	-- (^This nemesis edit is required to make the unit follow the adventurer when they travel)
	companionUnit.relationship_ids.GroupLeader = adventurerUnit.id
	-- (^This edit is require to make the unit follow the adventurer while in the world (not travelling))
end

-- Makes the unit a pet belonging to the adventurer
function makePet(adventurerUnit, petUnit)
	petUnit.relationship_ids.Pet = adventurerUnit.id
	petUnit.training_level = df.animal_training_level.Domesticated
	petUnit.civ_id = adventurerUnit.civ_id
	if petUnit.status.current_soul ~= nil then
		petUnit.status.current_soul.personality.civ_id = adventurerUnit.civ_id
	end
	-- Might need to change the idle type and + player unit as following target?
end

function main(...)
	local args = utils.processArgs({...}, validArgs)
	
	if args.help then
		print(help)
		return
	end
	
	local adventurerUnit = df.global.world.units.active[0]
	local targetUnit
	
	if args.unit then
		targetUnit = df.unit.find(tonumber(args.unit))
	else
		targetUnit = dfhack.gui.getSelectedUnit(true)
	end
	
	if targetUnit == nil then
		qerror("Couldn't find unit!")
	end
	
	-- Check for histfig
	if targetUnit.hist_figure_id == -1 and not args.create then
		qerror("Target isn't a historical figure and so can't be made into a companion.")
	end
	
	-- Check for nemesis
	if dfhack.units.getNemesis(targetUnit) == nil and not args.create then
		qerror("Target doesn't have a nemesis entry and so can't be made into a companion.")
	end
	
	-- Create a nemesis and historical figure entry if missing and create is enabled...
	if args.create and dfhack.units.getNemesis(targetUnit) == nil then
		local civId
		local groupId
		
		-- This might not be vital, but we'll make sure this unit is added to a civ
		if targetUnit.civ_id ~= -1 then
			civId = targetUnit.civ_id
		else
			-- We'll add them to the adventurer's civ
			civId = adventurerUnit.civ_id
			targetUnit.civ_id = civId
			if targetUnit.status.current_soul ~= nil then
				targetUnit.status.current_soul.personality.civ_id = civId
			end
		end
		-- Won't bother with groupId atm
		
		-- Create the nemesis + historical figure entry
		-- Why do it yourself when someone's already done it for you? ;P
		dfhack.reqscript("modtools/create-unit").createNemesis(targetUnit, civId, groupId)
		
		-- Temp fix since there's an error in create-unit:
		df.historical_figure.find(targetUnit.hist_figure_id).unit_id2 = dfhack.units.getNemesis(targetUnit).id
	end
	
	-- Make the target a companion of the player
	makeCompanion(adventurerUnit, targetUnit)
	
	if args.pet then
		makePet(adventurerUnit, targetUnit)
	end
end


if not dfhack.world.isAdventureMode() then
	qerror("This script can only be used in adventure mode!")
end

if not dfhack_flags.module then
    main(...)
end
