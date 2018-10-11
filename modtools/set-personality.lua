-- Change personality trait value of a unit
--[[ Issues/Potential changes
- Doesn't cause needs to change
- Changes don't respect target creature's natural limits
- Step sets to a particular value rather than a random range
]]


local usage = [====[

modtools/set-personality
=====================
This allows for altering the personality of units.

Arguments:

	-trait #
		the id/token of the trait to change. Alternatively "all" to apply the value to all... if you want to do that for some reason.
		examples:
			1
			HATE_PROPENSITY
			all
	-value #
		the value to set focus to. Defaults to 50
		examples:
			0
			75
	-step #
		alternative to value. Increase/decrease along description levels by #. 
		Negative values need to have a \ before the negative symbol
		examples:
			2
			\-1
	-add #
		alternative to value. Adds to current value.
		Negative values need to have a \ before the negative symbol. 
		examples:
			15
			\-20
	-average
		alternative to value. Sets the unit's trait to their caste's average.
	Without valid value/step/add/average, defaults to value style at 50.
	-target #
        the unit id of the target unit. If unspecified, will check for a selected unit.
        examples:
            0
            28
	-traitlist
		displays a list of need ids.

]====]

local utils = require 'utils'

validArgs = validArgs or utils.invert({
'help',
'traitlist',
'trait',
'value',
'target',
'step',
'add',
'average'
})

local args = utils.processArgs({...}, validArgs)

if args.help then
	print(usage)
	return
end

if args.traitlist then
	for i,v in ipairs(df.personality_facet_type)do
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
local traits = args.target.status.current_soul.personality.traits

--Work out the trait
local doAll
if not args.trait then
	error 'Specify a trait'
end

if (args.trait):lower() == "all" then
	doAll = true
elseif  tonumber(args.trait) then
	args.trait = tonumber(args.trait)
elseif df.personality_facet_type[args.trait] then
	args.trait = df.personality_facet_type[args.trait]
else
	error 'Invalid trait'
end

local ranges = {
[1] = {["low"] = 0, ["high"] = 9, ["mid"] = 5},
[2] = {["low"] = 10, ["high"] = 24, ["mid"] = 17},
[3] = {["low"] = 25, ["high"] = 39, ["mid"] = 32},
[4] = {["low"] = 40, ["high"] = 60, ["mid"] = 50},
[5] = {["low"] = 61, ["high"] = 75, ["mid"] = 68},
[6] = {["low"] = 76, ["high"] = 90, ["mid"] = 83},
[7] = {["low"] = 91, ["high"] = 100, ["mid"] = 95}
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

--Ultimately change the trait
local function setValue(traitId, value)
	traits[traitId] = clamp(value, 0, 100)
end

--Changes the trait value using step style
local function stepUp(traitId)
	local curStep = getStep(traits[traitId])
	local changed = clamp(curStep + args.step, 1, 7)
	setValue(traitId, ranges[changed].mid) --In theory could instead have a random number between low and high
end

local function doAdd(traitId)
	setValue(traitId, traits[traitId] + args.add)
end

--Gets the caste's average value for provided trait, then passes it on  to setValue
local function averageTrait(traitId)
	local caste = df.creature_raw.find(args.target.race).caste[args.target.caste]
	--local average = caste.personality.b[df.personality_facet_type[traitId]]
	local average = caste.personality.b[traitId]
	setValue(traitId, average)
end

--Both check for a valid value/alternative and do the thing
if tonumber(args.step) then
	--Do step
	if doAll then
		for i,v in ipairs(traits) do
			stepUp(i)
		end
	else
		stepUp(args.trait)
	end
	return
elseif tonumber(args.add) then
	--Do add
	if doAll then
		for i,v in ipairs(traits) do
			doAdd(i)
		end
	else
		doAdd(args.trait)
	end
	return
elseif args.average then
	if doAll then
		for i,v in ipairs(traits) do
			averageTrait(i)
		end
	else
		averageTrait(args.trait)
	end
else --Doing value or defaulting to value
	if not tonumber(args.value) then
		args.value = 50
	end
	if doAll then
		for i,v in ipairs(traits) do
			setValue(i, args.value)
		end
	else
		setValue(args.trait, args.value)
	end
	return
end
