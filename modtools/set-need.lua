-- Change focus level of needs for units

local usage = [====[

modtools/set-need
=====================
This allows for modifying the focus levels for needs on units.

Arguments:

	-need id
		the id/type of the need to change. Alternatively "all" to apply the value to all.
		examples:
			1
			DrinkAlcohol
			all
	-value
		the value to set focus to. Defaults to 400 if not included (the value focus resets to when normally fulfilled in game).
		Negative values need to have a \ before the negative symbol
		examples:
			250
			\-5000
	-target id
        the unit id of the target unit. If unspecified, will check for a selected unit.
        examples:
            0
            28
	-needlist
		displays a list of need ids.

]====]

local utils = require 'utils'

validArgs = validArgs or utils.invert({
'help',
'needlist',
'need',
'value',
'target'
})

local args = utils.processArgs({...}, validArgs)

if args.help then
	print(usage)
	return
end

if args.needlist then
	for i,v in ipairs(df.need_type)do
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

--Work out the need
local doAll
if not args.need then
	error 'Specify a need'
end

if (args.need):lower() == "all" then
	doAll = true
elseif  tonumber(args.need) then
	args.need = tonumber(args.need)
elseif df.need_type[args.need] then
	args.need = df.need_type[args.need]
else
	error 'Invalid need'
end

--Set the value
args.value = tonumber(args.value) or 400

--Doing the thing
local currentNeedTableId
for i, v in ipairs(args.target.status.current_soul.personality.needs) do
	if doAll or v.id == args.need then
		v.focus_level = args.value
		if not doAll then
			return
		end
	end
end
