-- Disables flying from intelligent creatures during fort mode
--@ module = true
--^ Not really much of a point to it for this script, but whatever :p

local help = [====[

patch/no-fort-fliers
====================
In fort mode, disables flight on any creature caste that can learn and can fly to avoid pathfinding problems.
It's probably best not to run when there are intelligent creatures currently flying in the air.

:-help:
	Shows this help info.
]====]

local utils = require 'utils'
local validArgs = utils.invert({
	"help",
})

function register_patch(args)
	local world_patch = dfhack.reqscript("patch/world-patch")
	
	world_patch.register_patch({
		custom_args = args,
		custom_code = patch_code,
		fortress_mode = true,
		adventure_mode = false,
		arena_mode = false,
		unique_id = "no-fort-fliers",
	})
end

function patch_code(args)
	for index, creature in pairs(df.global.world.raws.creatures.all) do
		-- We could use checks for the creature flags HAS_ANY_FLIER and HAS_ANY_INTELLIGENT learns to work out if the creature is worth checking, but there's a small chance another script may only alter a caste's flier flags, so we'll just check every creature + caste
		for index, caste in pairs(creature.caste) do
			if caste.flags.CAN_LEARN == true and caste.flags.FLIER == true then
				caste.flags.FLIER = false
				-- Should the creature's HAS_ANY_FLIER flag be changed, too?
			end
		end
	end
end

function main(...)
	local args = utils.processArgs({...}, validArgs)

	if args.help then
		print(help)
		return
	end

	register_patch(args)
end

if not dfhack_flags.module then
	main(...)
end