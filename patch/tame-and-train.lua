-- Make creatures tameable, trainable, and/or mountable
--@ module = true

local help = [====[

patch/tame-and-train
====================
Makes creatures available to be tamed and trained.
Since patches aren't active in worldgen (?), this'll only effect gameplay.
Note that some creature tokens (like MEGABEAST) override basic behaviour and cause military to automatically target them, even if they are tamed.
Requires a target and at least 1 effect.

Targets:
:-creature <CREATURE ID>:
	A particular creature will be affected.
:-caste <CASTE ID>:
	A particular caste of the given creature will be affected.
	This is an optional extra for when using `-creature`. If not provided, the patch will be applied to all castes of the creature.
:-animals:
	All creature castes that are not intelligent will be affected.
:-all:
	All creatures will be affected, regardless of their intelligence.
	Likely to cause plenty of weirdness...
	
Effects:
:-pet:
	The creature will be available as a standard pet.
	This or `-exotic` is required for a creature to be tameable.
:-exotic:
	The creature will be available as an exotic pet.
	This or `-pet` is required for a creature to be tameable.
:-war:
	The creature can be trained for war.
:-hunt:
	The creature can be trained for hunting.
:-mount:
	The creature can be used as a mount.

Misc:
:-help:
	Shows this help info.

Example Usage:
Make unicorns trainable: `patch/tame-and-train -creature UNICORN -war -hunt`
Make all animals tameable and trainable: `patch/tame-and-train -animals -exotic -war -hunt`
]====]

local utils = require 'utils'
local validArgs = utils.invert({
	"help",
	"creature",
	"caste",
	"animals",
	"all",
	"pet",
	"exotic",
	"war",
	"hunt",
	"mount",
})

-- Makes the given creature trainable
-- Castes is an optional argument with an indexed table of castes IDs of castes to apply the changes to. If omitted, will be applied to every caste
function make_trainable(creature, hunting, war, castes)
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
			if hunting then
				caste.flags.TRAINABLE_HUNTING = true
			end
			if war then
				caste.flags.TRAINABLE_WAR = true
			end
		end
	end
end

-- Makes the given creature tameable
-- If is_exotic is true, it will be an exotic pet. Otherwise it'll be a regular one
-- Castes is an optional argument with an indexed table of castes IDs of castes to apply the changes to. If omitted, will be applied to every caste
function make_pet(creature, is_exotic, castes)
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
			if is_exotic == true then
				caste.flags.PET_EXOTIC = true
			else
				caste.flags.PET = true
			end
		end
	end
end

-- Makes the given creature mountable
-- If is_exotic is true, it will be an exotic mount. Otherwise it'll be a regular one
-- Castes is an optional argument with an indexed table of castes IDs of castes to apply the changes to. If omitted, will be applied to every caste
function make_mount(creature, is_exotic, castes)
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
			if is_exotic == true then
				caste.flags.MOUNT_EXOTIC = true
			else
				caste.flags.MOUNT = true
			end
		end
	end
end
------
-- Apply the modifiers to a creature and its castes
-- (The modifiers are provided in args)
function apply_modifiers(creature, castes, args)
	-- Taming
	if args.pet ~= nil then
		make_pet(creature, false, castes)
	elseif args.exotic ~= nil then
		make_pet(creature, true, castes)
	end

	-- Training
	if args.war ~= nil or args.hunt ~= nil then
		make_trainable(creature, (args.hunt == true), (args.war == true), castes)
	end
	
	-- Mounting
	if args.mount ~= nil then
		make_mount(creature, false, castes)
	end
end

function patch_code(args)
	for index, creature in pairs(df.global.world.raws.creatures.all) do
		if args.creature and creature.creature_id == args.creature then
			local castes
			if args.caste ~= nil then
				castes = {}
				table.insert(castes, args.caste)
			end
			
			apply_modifiers(creature, castes, args)
			break
		elseif args.animals then
			local castes = {}
			for index, caste in pairs(creature.caste) do
				if caste.flags.CAN_LEARN == false then
					table.insert(castes, caste.caste_id)
				end
			end
			
			if #castes > 0 then
				apply_modifiers(creature, castes, args)
			end
		elseif args.all then
			apply_modifiers(creature, nil, args)
		end
	end
end

function register_patch(args)
	local world_patch = dfhack.reqscript("patch/world-patch")
	
	world_patch.register_patch({
		custom_args = args,
		custom_code = patch_code,
		fortress_mode = true,
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
	
	if args.creature == nil and args.animals == nil and args.all == nil then
		qerror("Please specify a target creature or group")
	end
	
	if args.pet == nil and args.exotic == nil and args.war == nil and args.hunt == nil and args.mount == nil then
		qerror("Please specify an effect. Possible effects are: -pet, -exotic, -war, -hunt, -mount")
	end
	
	-- Cleanup args, just in case necessary
	if args.war then args.war = true end
	if args.hunt then args.hunt = true end
	if args.mount then args.mount = true end
	if args.animals then args.animals = true end
	if args.pet then args.pet = true end
	if args.exotic then args.exotic = true end
	if args.all then args.all = true end
	
	register_patch(args)
end

if not dfhack_flags.module then
	main(...)
end