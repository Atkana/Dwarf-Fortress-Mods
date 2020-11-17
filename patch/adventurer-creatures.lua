-- Makes additional creatures available as outsiders when playing adventure mode
--@ module = true

local help = [====[

patch/adventurer-creatures
==========================
Makes additional creatures available as outsiders when playing adventure mode.
Note that creatures without CAN_LEARN won't be able to have skills, creatures without CAN_SPEAK won't be able to speak, and creatures without CANOPENDOORS won't be able to open doors.

:-creature <CREATURE ID>:
	A particular creature to be made available.
:-caste <CASTE ID>:
	A particular caste of the given creature will be affected.
	This is an optional extra for when using `-creature`. If not provided, the patch will be applied to all castes of the creature.
:-learners:
	All creature castes that are capable of learning are made available.
:-all:
	All creatures be made available, regardless of their intelligence.

Example Usage:
Make kobold outsiders playable: `patch/adventurer-creatures -creature KOBOLD`
]====]

local utils = require 'utils'
local validArgs = utils.invert({
	"help",
	"creature",
	"caste",
	"learners",
	"all",
})

-- Makes the given creature available as an outsider
-- Castes is an optional argument with an indexed table of castes IDs of castes to apply the changes to. If omitted, will be applied to every caste
function make_outsider_controllable(creature, castes)
	local castes_lookup
	if castes ~= nil then
		castes_lookup = utils.invert(castes)
	end
	
	for index, caste in pairs(creature.caste) do
		local do_changes = false

		if castes_lookup ~= nil and castes_lookup[caste.caste_id] ~= nil then -- Applying to specific castes mode, and is one of those castes
			do_changes = true
		elseif castes_lookup == nil then -- Applying to all castes mode
			do_changes = true
		end
		
		if do_changes == true then
			caste.flags.OUTSIDER_CONTROLLABLE = true
		end
	end
	-- Edit the creature-level flag, too
	creature.flags.HAS_ANY_OUTSIDER_CONTROLLABLE = true
end
------
function patch_code(args)
	for index, creature in pairs(df.global.world.raws.creatures.all) do
		if args.creature and creature.creature_id == args.creature then
			local castes
			if args.caste ~= nil then
				castes = {}
				table.insert(castes, args.caste)
			end
			
			make_outsider_controllable(creature, castes)
			break
		elseif args.learners then
			local castes = {}
			for index, caste in pairs(creature.caste) do
				if caste.flags.CAN_LEARN == true then
					table.insert(castes, caste.caste_id)
				end
			end
			
			if #castes > 0 then
				make_outsider_controllable(creature, castes)
			end
		elseif args.all then
			if creature.flags.DOES_NOT_EXIST == false then
				make_outsider_controllable(creature)
			end
		end
	end
end

function register_patch(args)
	local world_patch = dfhack.reqscript("patch/world-patch")
	
	world_patch.register_patch({
		custom_args = args,
		custom_code = patch_code,
		fortress_mode = false, -- It doesn't really matter if this is available in other modes, but we'll disable fort mode anyway
		adventure_mode = true,
		arena_mode = true,
	})
end
------
function main(...)
	local args = utils.processArgs({...}, validArgs)

	if args.help then
		print(help)
		return
	end
	
	if args.creature == nil and args.learners == nil and args.all == nil then
		qerror("Please specify a target creature or group")
	end
	
	register_patch(args)
end

if not dfhack_flags.module then
	main(...)
end