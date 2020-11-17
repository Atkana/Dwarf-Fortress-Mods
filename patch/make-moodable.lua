-- Make creatures able to have strange moods
--@ module = true

-- TODO: Consider making -caste a table so multiple castes can be entered in 1 command.

local help = [====[

patch/make-moodable
===================
Makes creatures able to have strange moods (without having to edit their raws).
Since patches aren't active in worldgen (?), this'll only effect gameplay in forts you are playing.

:-creature <CREATURE ID>:
	Sets a particular creature to be able to have strange moods.
:-caste <CASTE ID>:
	The caste of a creature to be able to have strange moods.
	This is an optional extra for when using `-creature`. If not provided, the patch will be applied to all castes of the creature.
:-learner:
	All creature castes with CAN_LEARN will be able to have strange moods.
:-all:
	All creatures will be able to have strange moods.
	I'm not sure how the game determines what units to select for strange moods, so this might have a chance of making your animals also be able to go into strange moods if the game doesn't check for things like that...

:-help:
	Shows this help info.

Example Usage:
Make elves able to have strange moods: `patch/make-moodable -creature ELF`
]====]

local utils = require 'utils'
local validArgs = utils.invert({
	"help",
	"creature",
	"caste",
	"learner",
	"all",
})

-- Set the given creature to be able to have strange moods.
-- Castes is an optional argument with an indexed table of castes IDs of castes to apply the changes to. If omitted, will be applied to every caste
function make_moodable(creature, castes)
	local castes_lookup
	if castes ~= nil then
		castes_lookup = utils.invert(castes)
	end
	
	for index, caste in pairs(creature.caste) do
		if castes_lookup ~= nil and castes_lookup[caste.caste_id] ~= nil then -- Applying to specific castes mode, and is one of those castes
			caste.flags.STRANGE_MOODS = true
		elseif castes_lookup == nil then -- Applying to all castes mode
			caste.flags.STRANGE_MOODS = true
		end
	end
end

function register_patch(args)
	local world_patch = dfhack.reqscript("patch/world-patch")
	
	world_patch.register_patch({
		custom_args = args,
		custom_code = patch_code,
		fortress_mode = true,
		adventure_mode = false,
		arena_mode = false,
	})
end

function patch_code(args)
	for index, creature in pairs(df.global.world.raws.creatures.all) do
		if args.creature and creature.creature_id == args.creature then

			if args.caste ~= nil then
				local castes = {}
				table.insert(castes, args.caste)
				make_moodable(creature, castes)
			else
				make_moodable(creature)
			end

			break
		elseif args.learner then
			if creature.flags.HAS_ANY_INTELLIGENT_LEARNS == true then
				local learning_castes = {}

				for index, caste in pairs(creature.caste) do
					if caste.flags.CAN_LEARN == true then
						table.insert(learning_castes, caste.caste_id)
					end
				end

				make_moodable(creature, learning_castes)
			end
		elseif args.all then
			make_moodable(creature)
		end
	end
end

function main(...)
	local args = utils.processArgs({...}, validArgs)

	if args.help then
		print(help)
		return
	end
	
	if args.creature == nil and args.learner == nil and args.all == nil then
		qerror("Please specify a target creature or group")
	end
	
	register_patch(args)
end

if not dfhack_flags.module then
	main(...)
end