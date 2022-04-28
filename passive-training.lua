-- Allows for passively training skills over time
--@ module = true
-- Release Version 1

local help = [====[

gui/passive-training
====================
Allows for passively training skills over time. Select which skills you want to be "training", and they will advance as time passes.

Notes:
- To ensure this script is always running, include ``gui/passive-training -load`` within an ``onLoad*`` init file.
- Skills are only updated when a map loads, and training units are present. In adventure mode this happens whenever you load the game, finish waiting, or finish travelling.
- While skills levels are increased, the attribute increase you'd get from training a skill are not implemented.
- Skill rust isn't updated.
- The implementation is very rudimentary, and doesn't account for a character's current state (like travelling, or sleeping), so see the rates as an average spread across a whole day.

Arguments::

-rate <value>
	How much experience points are earned per hour, which is split across all chosen skills to train.
	To put rates into perspective, most reactions give 30 experience for completing them.
	This value is saved on a per-world basis.
	The default rate is 100 per hour.
-nemesis <nemsis id>
	Use the GUI to select the provided character's trained skills rather than the active adventurer's.
-load
	Used to load the script so its features start running.
	
]====]

-- exp_rates are saved on a per-world basis
---------------------------------------------------------------------
local utils = require "utils"
local gui = require "gui"
local dialog = require "gui.dialogs"
local widgets = require 'gui.widgets'

local validArgs = utils.invert({
	"help",
	"rate",
	"nemesis",
	"load",
})
---------------------------------------------------------------------
script_data = script_data or nil
---------------------------------------------------------------------
-- Returns the currently active adventurer
function get_adventurer_unit()
	local nemesis = df.nemesis_record.find(df.global.ui_advmode.player_id)
	local unit = df.unit.find(nemesis.unit_id)
	
	return unit
end

function first_time_setup()
	script_data.training_entries = {}
	script_data.exp_rate = 100
end

function create_training_entry(id)
	local entry = {
		nemesis_id = id,
		skills = {},
		last_update = get_current_tick()
	}
	
	script_data.training_entries[tostring(id)] = entry
	
	return entry
end

-- Adds a new skill entry to
function create_skill_entry(nemesis, skill_id)
	local training_info = get_training_info(nemesis)
	
	if training_info == nil then
		training_info = create_training_entry(nemesis.id)
	end
	
	-- Check doesn't already exist
	if get_skill_training_info(nemesis, skill_id) ~= nil then
		return get_skill_training_info(nemesis, skill_id)
	end
	
	-- Make a new entry
	local skill_entry = {
		skill_id = skill_id, -- Numerical id for the skill
		active = false, -- Marks if the skill is currently being trained
		experience = 0, -- Stores accumulated experience points. Will generally be a float value, because it'll only really record
	}
	
	training_info.skills[tostring(skill_id)] = skill_entry
	
	return skill_entry
end

-- Returns the current fortress mode scale tick
function get_current_tick()
	return 1200*28*3*4*df.global.cur_year + df.global.cur_year_tick
end

-- Returns the training entry for the given nemesis, or nil if one doesn't exist
function get_training_info(nemesis)
	return script_data.training_entries[tostring(nemesis.id)] or nil
end

-- Returns the skill training entry for the given nemesis and skill, or nil if the nemesis has no training info for that skill, or that nemesis has no training info at all
function get_skill_training_info(nemesis, skill_id)
	local training_info = get_training_info(nemesis)
	
	if training_info == nil then
		return nil
	end
	
	return training_info.skills[tostring(skill_id)] or nil
end

-- Used to enable/disable training for a given skill
-- skill_id should be the numerical skill id
function set_training_skill(nemesis, skill_id, is_training)
	local training_info = get_training_info(nemesis)
	
	-- Create a basic training entry for the unit if they don't have one already
	if training_info == nil then
		training_info = create_training_entry(nemesis.id)
	end
	
	local skill_training_info = get_skill_training_info(nemesis, skill_id)
	if skill_training_info == nil and is_training == false then
		-- If they don't have a training entry for this skill already, and it's being set to false, there's no reason to even generate a new entry.
		return
	elseif skill_training_info == nil then
		skill_training_info = create_skill_entry(nemesis, skill_id)
	end
	
	skill_training_info.active = is_training
end

-- Returns true if the character is training the particular skill, or false if not
-- skill_id should be the numerical skill id
function is_training_skill(nemesis, skill_id)
	-- Check that the unit has any training data at all
	if is_training_unit(nemesis.unit) == false then
		return false
	end
	
	for training_skill_id, info in pairs(get_training_info(nemesis).skills) do
		local training_skill_id = tonumber(training_skill_id) -- ids are stored as strings, so convert for the comparison
		if skill_id == training_skill_id then
			return info.active
		end
	end
	
	-- If we get here, we didn't find a match
	return false
end

-- Sets the experience gaining rate for this world to the given value
-- Rate is in experience per hour
function set_exp_rate(value)
	script_data.exp_rate = value
end

-- Returns true if the given unit has training data
function is_training_unit(unit)
	local nemesis = dfhack.units.getNemesis(unit)
	
	if nemesis == nil then
		return false
	end
	
	if get_training_info(nemesis) ~= nil then
		return true
	else
		return false
	end
end

-- Gets the number of skills the character is actively training
function get_active_skill_num(nemesis)
	local training_info = get_training_info(nemesis)
	
	local active_skills = 0
	for skill_id, info in pairs(training_info.skills) do
		if info.active == true then
			active_skills = active_skills + 1
		end
	end
	
	return active_skills
end

-- Updates a unit's histfig entry to reflect their current skill levels
function update_unit_historical_skills(unit)
	local function update_historical_skill(histfig, skill_id, experience)
		-- Search their info to see if they've got points in the skill already
		local found_index = nil
		for index, current_skill_id in pairs(histfig.info.skills.skills) do
			if current_skill_id == skill_id then
				found_index = index
				break
			end
		end
		
		if found_index == nil then
			-- Histfig doesn't have a record for this skill, so insert one where required!
			local _, _, idx = utils.insert_sorted(histfig.info.skills.skills, skill_id)
			found_index = idx
			
			histfig.info.skills.points:insert(found_index, experience)
		end
		
		-- Set recorded skill level for the skill
		-- (Note that unlike unit skills, historical figure skills work by recording their total experience points towards the skill)
		histfig.info.skills.points[found_index] = experience
	end
	
	if unit.hist_figure_id == -1 then
		-- Unit isn't a historical figure!
		return
	end
	
	local histfig = df.historical_figure.find(unit.hist_figure_id)
	
	for index, unit_skill in pairs(unit.status.current_soul.skills) do
		local skill_id = unit_skill.id
		local total_experience = dfhack.units.getExperience(unit, skill_id, true)
		
		update_historical_skill(histfig, skill_id, total_experience)
	end
end

---------------------------------------------------------------------
-- Updates the values for experience earned for active skills
-- Note that this DOESN'T apply the actual changes to their skills. See update_skill_levels for that
function update_experience_earned(nemesis)
	local training_info = get_training_info(nemesis)
	
	-- Work out the total amount of experience accumulated since the last check
	-- There are 50 fort-scale ticks in an hour, and exp_rate is per hour
	local total_experience = ((get_current_tick() - training_info.last_update) / 50 ) * script_data.exp_rate

	-- Work out how many skills are currently active, for dividing experience between them
	local active_skills = get_active_skill_num(nemesis)
	
	-- Add the share of the experience to each active skill individually
	for skill_id, info in pairs(training_info.skills) do
		if info.active == true then
			local skill_id = tonumber(skill_id)

			-- Modify earned experience by the unit caste's learning rates for that skill when applying
			local caste_raw = df.creature_raw.find(nemesis.unit.race).caste[nemesis.unit.caste]
			local modifier = caste_raw.skill_rates[0][skill_id] / 100
			
			info.experience = info.experience + ((total_experience / active_skills) * modifier)
		end
	end
end

-- Updates a character's skill levels based on their accumulated experience from training skills
function update_skill_levels(nemesis)
	local training_info = get_training_info(nemesis)
	
	-- Apply changes to the unit's skill levels
	for skill_id, info in pairs(training_info.skills) do
		local skill_id = tonumber(skill_id)
		-- Don't worry about whether a skill is being actively trained, only if it has accumulated experience of 1 or higher!
		if info.experience >= 1 then
			-- Round down to a full number
			local exp_to_add = math.floor(info.experience)
			
			-- Add the exp to the unit
			dfhack.run_script("modtools/skill-change", table.unpack({
				"-skill", df.job_skill[skill_id],
				"-mode","add",
				"-granularity","experience",
				"-value", exp_to_add,
				"-unit", nemesis.unit_id}))
			
			-- Finally, remove the exp we added from the built up experience for the skill (leaving just the float values of how far they've progressed to earning another point)
			info.experience = info.experience - exp_to_add
		end
	end
	
	-- If the unit is also a historical figure, apply the changes to their skills in their historical figure entry (skill-change doesn't do that)
	if nemesis.figure ~= nil then
		update_unit_historical_skills(nemesis.unit)
	end
end

-- Triggers an update for a chosen character
function update_training(nemesis)
	-- Skip if the character doesn't have any skills selected to train
	if get_active_skill_num(nemesis) == 0 then
		return
	end
	-- TODO: Include safety check to ensure active?
	local training_info = get_training_info(nemesis)

	update_experience_earned(nemesis)
	update_skill_levels(nemesis)

	training_info.last_update = get_current_tick()
end

-- Triggers update checks for all currently active units
function update_training_all()
	for _, unit in pairs(df.global.world.units.active) do
		if is_training_unit(unit) == true then
			update_training(dfhack.units.getNemesis(unit))
		end
	end
end
---------------------------------------------------------------------
-- GUI
TrainingList = defclass(TrainingList, gui.FramedScreen)
TrainingList.ATTRS = {
	frame_style = gui.GREY_LINE_FRAME,
	frame_title = "Training Select",
	frame_width = 25,
	frame_height = 25,
	frame_inset = 1,
	nemesis = DEFAULT_NIL,
}

function TrainingList:update_choices(preserve_selection)
	local choices = self.subviews.skill_list:getChoices()
	
	for index, choice in pairs(choices) do
		choice.text = df.job_skill.attrs[choice.skill_id].caption_noun 
		
		-- Add markers to skills that are selected as being trained
		if choice.active then
			choice.text = choice.text .. " (*)"
		end
	end
	
	if preserve_selection ~= nil then
		self.subviews.skill_list:setChoices(choices, preserve_selection)
	else
		self.subviews.skill_list:setChoices(choices)
	end
end

function TrainingList:initial_setup()
	-- Generate the initial choices based on the unit's starting skills
	local choices = {}
	
	-- Loop through all skills
	for skill_id = 0, df.job_skill._last_item do
		local addition = {}
		
		-- Generate the text to show
		-- If the character is currently training a given skill, it'll be marked with (*) at the end of it
		addition.text = df.job_skill.attrs[skill_id].caption_noun 
		addition.search_key = addition.text:lower()

		-- Save some extra info
		addition.skill_id = skill_id -- Record the ID within the choice

		-- Setup the initial active flags based on what the character was training to start with
		addition.active = is_training_skill(self.nemesis, skill_id)
		
		-- Add markers to skills that are selected as being trained
		if addition.active then
			addition.text = addition.text .. " (*)"
		end

		table.insert(choices, addition)
	end
	
	self.subviews.skill_list:setChoices(choices)
end

function TrainingList:init(info)
	self:addviews{
		widgets.Label{
			frame = { l = 0, r = 0, t = 0},
			text = {
				{text = "Select skills to train."}
			},
		},
		widgets.Label{
			frame = { l = 0, r = 0, t = 1},
			text = {
				{text = "(*) Means training"}
			},
		},
		widgets.FilteredList{
			view_id = "skill_list",
			with_filter = true,
			frame = { l = 0, r = 0, t = 2, b = 1 },
			on_submit = function(index, choice)
				if self.subviews.skill_list:canSubmit() then
					-- Swap the "active" state of the choice
					choice.active = (not choice.active)
					-- Actually changing the data will be done when the GUI is closed
					self:update_choices(index)
				end
			end,
		},
		widgets.Label{
			frame = { b = 0 },
			text = {
				{text = ": Toggle training", key = "SELECT"} -- Note: list already handles the stuff, so no need for an on_activate callback here
			},
		}
	}
	
	-- Perform initial setup for choices
	self:initial_setup()
	
	self:update_choices()
end

function TrainingList:close()
	-- Save the training settings
	for _, choice in pairs(self.subviews.skill_list:getChoices()) do
		set_training_skill(self.nemesis, choice.skill_id, choice.active)
	end
	
	-- Close GUI
	self:dismiss()
end

function TrainingList:onInput(keys)
	if keys.LEAVESCREEN then
		self:close()
	else
		self:inputToSubviews(keys)
	end
end

function showTrainingList(nemesis)
	TrainingList{
		frame_title = "Training Select",
		nemesis = nemesis,
	}:show()
end

---------------------------------------------------------------------
local function load_script_data()
	local loader = require("script-data")
	
	script_data = loader.load_world("passive-training", true)
	
	-- If this is the first time launching this script in this world, run first time setup
	if script_data.training_entries == nil then
		first_time_setup()
	end
end

dfhack.onStateChange.passive_training = function(event)
	--[[
	-- Only want to run this code during adventure mode (even though technically it could apply to adventurers visiting a fort, etc.)
	-- Arena mode should be fine, too
	
	local supported_mode = dfhack.world.isAdventureMode() or dfhack.world.isArena() or false
	
	if not supported_mode then
		return
	end
	]]
	-- ^ Any mode can be supported, really. The map doesn't actually reload outside of arena travelling / first loads, so there will be little effect outside of adventure mode, anyway.
	
	if event == SC_WORLD_LOADED then
		-- Load up the script's data for the world
		load_script_data()
	elseif event == SC_MAP_LOADED then
		-- Rather than relying on timers for updates, we'll check for updates whenever the map is loaded
		-- (so whenever the game is loaded, the player finishes travelling, they finish resting(?), etc.)
		update_training_all()
	elseif event == SC_WORLD_UNLOADED then
		-- Unload the current world's data
		script_data = nil
		-- (The script-data utility will already automatically save the actual data)
	end
end

function main(...)
  local args = utils.processArgs({...}, validArgs)

  if args.help then
    print(help)
    return
  end
	
	if args.rate then
		if not tonumber(args.rate) then
			qerror("Please enter a number")
		end
		
		set_exp_rate(tonumber(args.rate))
		-- Exit out here, rather than attempting to open the gui
		return
	end
	
	if args.load then
		-- Only want to initialise this script, not actually run it
		return
	end
	
	-- Ensure world is actually loaded
	if not dfhack.isWorldLoaded() then
		qerror("The world needs to be loaded to use this")
	end
	
	-- Open the editor for the given nemesis
	-- If one isn't provided, will default to the currently active adventurer (if in adventure mode)
	local nemesis
	if args.nemesis then
		local nemesis_id = tonumber(args.nemesis)
		nemesis = df.nemesis_record.find(nemesis_id)
	
		if not nemesis then
			qerror("Couldn't find nemesis with the given ID")
		end
	else
		if dfhack.world.isAdventureMode() == false then
			-- df.global.ui_advmode.player_id == 0 
			qerror("Please use this with an active adventurer, or provide the nemesis ID of the character whose training you wish to edit")
		end
		
		nemesis = df.nemesis_record.find(df.global.ui_advmode.player_id)
	end
	
	-- Last minute check to ensure script data is loaded (in case this wasn't initially loaded with an init, and so the SC_WORLD_LOADED triggers won't have happened)
	if script_data == nil then
		load_script_data()
	end
	
	showTrainingList(nemesis)
end

if not dfhack_flags.module then
    main(...)
end
