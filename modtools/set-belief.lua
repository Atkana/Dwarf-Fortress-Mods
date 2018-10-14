-- Change beliefs value of a unit
--[[ Issues/Potential changes
- Doesn't cause needs to change
- Changes don't respect creature's cultural weights (not sure how you'd model that, anyway)
- Step sets to a particular value rather than a random range
]]

local usage = [====[

modtools/set-belief
=====================
This allows for altering the beliefs of units.

Arguments:

	-belief #
		the id/token of the belief to change. Alternatively "all" to apply the value to all... if you want to do that for some reason.
		examples:
			1
			LOYALTY
			all
	-value #
		the value to set focus to. Defaults to 0
		examples:
			-15
			45
	-step #
		alternative to value. Increase/decrease along description levels by #.
		Negative values need to have a \ before the negative symbol. 
		examples:
			2
			\-1
	-add #
		alternative to value. Adds to current value.
		Negative values need to have a \ before the negative symbol. 
		examples:
			15
			\-20
	-default
		alternative to value. Resets the unit's belief to their culture's default.
	Without valid value/step/add/default, defaults to value style at 0.
	-target #
        the unit id of the target unit. If unspecified, will check for a selected unit.
        examples:
            0
            28
	-belieflist
		displays a list of need ids.

]====]

local utils = require 'utils'

validArgs = validArgs or utils.invert({
'help',
'belieflist',
'belief',
'value',
'target',
'step',
'add',
'default'
})

local args = utils.processArgs({...}, validArgs)

if args.help then
	print(usage)
	return
end

if args.belieflist then
	for i,v in ipairs(df.value_type)do
		print(i .. " (" .. v .. ")")
	end
	return
end

--Find the target
local targ
if not args.target then
	if dfhack.gui.getSelectedUnit(true) then
		targ =  dfhack.gui.getSelectedUnit(true)
	else
		error 'Specify a target'
	end
else
	if df.unit.find(tonumber(args.target)) then
		targ = df.unit.find(tonumber(args.target))
	else
		error ('Could not find target: '.. args.target)
	end
end
args.target = targ

--Checks has a soul, probably
if not targ.status.current_soul then
	error 'Unit has no soul'
end

--Store shorthand for use later
local upers = args.target.status.current_soul.personality
local beliefs = upers.values


--Work out the trait
local doAll
if not args.belief then
	error 'Specify a belief'
end

if (args.belief):lower() == "all" then
	doAll = true
elseif  tonumber(args.belief) then
	args.belief = tonumber(args.belief)
elseif df.value_type[args.belief] then
	args.belief = df.value_type[args.belief]
else
	error 'Invalid belief'
end

local ranges = {
[1] = {["low"] = -50, ["high"] = -41, ["mid"] = -45},
[2] = {["low"] = -40, ["high"] = -26, ["mid"] = -33},
[3] = {["low"] = -25, ["high"] = -11, ["mid"] = -18},
[4] = {["low"] = -10, ["high"] = 10, ["mid"] = 0},
[5] = {["low"] = 11, ["high"] = 25, ["mid"] = 18},
[6] = {["low"] = 26, ["high"] = 40, ["mid"] = 33},
[7] = {["low"] = 41, ["high"] = 50, ["mid"] = 45}
}

local function clamp(val, low, high)
	val = tonumber(val)
	if val < low then
		return low
	elseif val > high then
		return high
	end
	return val
end

local function getStep(value)
	for i,v in ipairs(ranges) do
		if (value >= v.low) and (value <= v.high) then
			return i
		end
	end
end

local pointers = {}
--[[ Structure: pointers[#1] = #2
#1 is the value's type
#2 is the index entry for unit.status.current_soul.personality.values
]]
local function buildPointers()
	for i, v in ipairs(beliefs) do
		pointers[v.type] = i
	end
end

--Returns unit's current value for given belief
local function getCurBeliefValue(unit, beliefId)
	local upers = unit.status.current_soul.personality
	if pointers[beliefId] then
		return upers.values[pointers[beliefId]].strength
	elseif upers.cultural_identity ~= -1 then
		return df.cultural_identity.find(upers.cultural_identity).values[beliefId]
	elseif upers.civ_id ~= -1 then
		return df.historical_entity.find(upers.civ_id).resources.values[beliefId]
	else
		return 0 --outsiders have no culture
	end	
end

--Ultimately changes value strength. Changes an existing entry if possible, otherwise creates a new one. Uses pointers.
local function changeBelief(beliefId, value)
	local value = clamp(value, -50, 50)
	if pointers[beliefId] then --belief already exists on unit
		upers.values[pointers[beliefId]].strength = value
		--Done!
	else --Makes new belief (assumes it's fine to have a personal value entry that's technically the same step as their culture's)
		upers.values:insert("#", {new = df.unit_personality.T_values, type = beliefId, strength = value})
		--Add this new info to pointers, in case of doAll
		pointers[beliefId] = #upers.values-1
		--Done!
	end
end

--Reverts a belief to the units culture's by removing its entry from the unit's personality.
local function defaultBelief(beliefId)
	if pointers[beliefId] then --Don't have to bother doing anything if it's already at the default
		upers.values:erase(pointers[beliefId])
		if doAll then -- Going to have to rebuild pointers if doing all
			buildPointers()
		end
	end
end

local function stepUp(beliefId)
	local curStep = getStep(getCurBeliefValue(args.target, beliefId))
	local changed = clamp(curStep + args.step, 1, 7)
	changeBelief(beliefId, ranges[changed].mid)
end

--Setup for add changes
local function doAdd(beliefId)
	changeBelief(beliefId, getCurBeliefValue(args.target, beliefId) + args.add) --No need to check if new value would be beyond range, value is clamped during changeBelief()
end

--Before making changes, make a table that records the unit's individual beliefs
buildPointers()

--Both check for a valid value/alternative and do the thing
if tonumber(args.step) then --Do steps
	if doAll then
		for i,v in ipairs(df.value_type) do
			stepUp(i)
		end
	else
		stepUp(args.belief)
	end
	return
elseif tonumber(args.add) then --Do adds
	if doAll then
		for i,v in ipairs(df.value_type) do
			doAdd(i)
		end
	else
		doAdd(args.belief)
	end
	return
elseif args.default then --Do default
	if doAll then
		if #beliefs > 0 then
			for i,v in ipairs(df.value_type) do --Fairly inefficient since there may only actually be 1 belief to default, but programming around it isn't worth the mess.
				defaultBelief(i)
			end
		end
	else
		defaultBelief(args.belief)
	end	
else --Doing value or defaulting to value
	if not tonumber(args.value) then --If value is missing or invalid, set to 0
		args.value = 0
	end
	--Do values
	if doAll then 
		for i,v in ipairs(df.value_type) do
			changeBelief(i, args.value)
		end
	else
		changeBelief(args.belief, args.value)
	end
	return
end
