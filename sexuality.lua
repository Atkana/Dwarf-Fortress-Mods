-- Edit a unit's orientation via a gui
--@ module = true
-- Created for dfhack version 0.44.12-r2

--[====[
gui/sexuality
===============
Alter a selected unit's orientation via a simple interface
]====]

local gui = require 'gui'
local widgets = require 'gui.widgets'
local rng = dfhack.random.new()

sexuality_editor = defclass(sexuality_editor, gui.FramedScreen)
sexuality_editor.ATTRS = {
	frame_style = gui.GREY_LINE_FRAME,
	frame_title = "Edit Orientation",
	frame_width = 35,
	frame_height = 4,
	frame_inset = 1,
}

-- Actually updates the unit's orientation values. Automatically updates histfig info if they're also a histfig
-- Uses the orientation values used in this script for malePref and femalePref:
-- 1 = Uninterested, 2 = Romance, 3 = Marry
function updateUnitOrientation(unit, malePref, femalePref)
	local ori = unit.status.current_soul.orientation_flags
	
	ori.indeterminate = false
	ori.romance_male = false
	ori.marry_male = false
	ori.romance_female = false
	ori.marry_female = false
	
	-- Check if unit is histfig
	local hori
	if unit.hist_figure_id ~= -1 then
		hori = df.historical_figure.find(unit.hist_figure_id).orientation_flags
		hori.indeterminate = false
		hori.romance_male = false
		hori.marry_male = false
		hori.romance_female = false
		hori.marry_female = false
	end
	
	if malePref == 2 then
		ori.romance_male = true
		if hori then hori.romance_male = true end
	elseif malePref == 3 then
		ori.marry_male = true
		if hori then hori.marry_male = true end
	end
	
	if femalePref == 2 then
		ori.romance_female = true
		if hori then hori.romance_female = true end
	elseif femalePref == 3 then
		ori.marry_female = true
		if hori then hori.marry_female = true end
	end
end

-- Gets orientation values for the given unit
-- Returns male orientation, then female orientation
-- 1 = Uninterested, 2 = Romance, 3 = Marry
function getUnitOrientations(unit)
	local malePref, femalePref = 1, 1
	
	local ori = unit.status.current_soul.orientation_flags
	
	if ori.romance_male then
		malePref = 2
	elseif ori.marry_male then
		malePref = 3
	end
	
	if ori.romance_female then
		femalePref = 2
	elseif ori.marry_female then
		femalePref = 3
	end
	
	return malePref, femalePref
end

function weightedRoll(weightedTable)
	local maxWeight = 0
	for index, result in ipairs(weightedTable) do
		maxWeight = maxWeight + result.weight
	end
	
	local roll = rng:random(maxWeight) + 1
	local currentNum = roll
	local result
	
	for index, currentResult in ipairs(weightedTable) do
		currentNum = currentNum - currentResult.weight
		if currentNum <= 0 then
			result = currentResult.id
			break
		end
	end
	
	return result
end

-- Note that this simply generates a new status value for use in this script, rather than actually changing the unit
-- Uses unit's caste's weights to generate a new value for each sex
-- Returns value for Male, then Female. 1 = Uninterested, 2 = Romance, 3 = Marry
function randomisePreference(unit)
	local caste = df.creature_raw.find(unit.race).caste[unit.caste]
	
	local maleTable = {
		{id = 1, weight = caste.orientation_male[0]}, -- Uninterested
		{id = 2, weight = caste.orientation_male[1]}, -- Romance
		{id = 3, weight = caste.orientation_male[2]}, -- Marry
	}
	
	local femaleTable = {
		{id = 1, weight = caste.orientation_female[0]}, -- Uninterested
		{id = 2, weight = caste.orientation_female[1]}, -- Romance
		{id = 3, weight = caste.orientation_female[2]}, -- Marry
	}
	
	return weightedRoll(maleTable), weightedRoll(femaleTable)
end

local status = {"Uninterested", "Romance", "Marry"}
local sexes = {"Male", "Female"}

function sexuality_editor:updateChoices()
	local choices = {}
	
	table.insert(choices, sexes[1] .. ": " .. status[self.oriValues[1]])
	table.insert(choices, sexes[2] .. ": " .. status[self.oriValues[2]])
	
	self.subviews.sex_select:setChoices(choices)
end

function sexuality_editor:toggleSelected()
	local index = self.subviews.sex_select:getSelected()
	
	self.oriValues[index] = self.oriValues[index] + 1
	if self.oriValues[index] > 3 then self.oriValues[index] = 1 end
	
	self:updateChoices()
end

function sexuality_editor:randomise()
	self.oriValues[1], self.oriValues[2] = randomisePreference(self.unit)
	self:updateChoices()
end

function sexuality_editor:close()
	-- Update unit's orientation
	updateUnitOrientation(self.unit, self.oriValues[1], self.oriValues[2])
	-- Close GUI
	self:dismiss()
end

function sexuality_editor:init(args)
	self.unit = args.unit
	
	self:addviews{
		widgets.List{
			frame = {t=0, b=1,l=1},
			view_id = "sex_select"
		},
		widgets.Label{
			frame = {b=0,l=1},
			text = {
				{text = ": Randomise ",key = "CUSTOM_R", on_activate = self:callback("randomise")},
				{text = ": Toggle ", key = "SELECT", on_activate = self:callback("toggleSelected")},
			},
		}
	}
	
	-- Setup orientation values
	local malePref, femalePref = getUnitOrientations(self.unit)
	self.oriValues = {malePref, femalePref}
	
	-- Update title
	local unitName = dfhack.TranslateName(dfhack.units.getVisibleName(self.unit))
	if unitName == "" then unitName = "(Unnamed Creature)" end
	
	self.frame_title = "Editing: " .. unitName
	self:updateChoices()
end

function sexuality_editor:onInput(keys)
	if keys.LEAVESCREEN then
		self:close()
	else
		self:inputToSubviews(keys)
	end
end

function main(...)
	local unit = dfhack.gui.getSelectedUnit(true)
	if not unit then
		qerror("Requires a selected unit")
	end

	sexuality_editor({unit = unit}):show()
end

if not dfhack_flags.module then
	main(...)
end
