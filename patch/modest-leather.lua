-- Replicates Modest mod's leather alterations in patch form
--@ module = true

local help = [====[

patch/modest-leather
====================
Replicates Modest Mod's changes to leathermaking, allowing the alterations to butcher skinning amounts and
tanning of scales without having to edit any files (note that as such, the effects won't be available in worldgen).
Note that this is limited to only applying to creatures that use the traditional naming scheme for materials
(i.e. their skin has the ID `SKIN`, their leather has the ID `LEATHER`, their scales have the ID `SCALES`).

Targets:
:``-all``:
	Will try to apply the modifications to all creatures.
:``-creature <CREATURE ID>``:
	Will try to apply the modifications to the given creature.

Modifications:
:``-skin``:
	If the creature also has a LEATHER material, extra units of skin are acquired when butchering.
:``-scales``:
	The creature's scales can be tanned, and extra units of scales are acquired when butchering.

Misc:
:``-help``:
	Shows this help info.
:``-amount <ITEM DIMENSION>``:
	Size of a glob required to tan a hide. 1 unit of glob = 150 item dimension.
	This number will apply to all tan attempts (you can't configure different amounts for each leather type).
	The most recent value given will be the one that is used.
	
	Defaults to the value used in Modest Mod: 600.

Example Usage:
The following will make all creatures follow the Modest Mod rules:
`patch/modest-leather -all -skin -scales`
]====]

-- Amount of glob consumed by the TAN_A_HIDE reaction (when it's edited)
glob_size = glob_size or 600

-- Record if the TAN_A_HIDE reaction has been edited since the world has been loaded
-- Will reset back to false when a world is unloaded
has_edited_reaction = has_edited_reaction or false

local utils = require 'utils'
local validArgs = utils.invert({
	"help",
	"all",
	"creature",
	"skin",
	"scales",
	"amount",
})

function get_creature_mat_info(creature, material_id)
	return dfhack.matinfo.find("CREATURE:" .. creature.creature_id .. ":" .. material_id)
end

-- Returns the creature_raw material entry if a creature has a material with the matching id (e.g. "LEATHER")
function find_creature_material(creature, material_id)
	for index, material in pairs(creature.material) do
		if material.id == material_id then
			return material
		end
	end
	
	-- If we got here, it doesn't have a material by that ID
	return nil
end

-- Attempt to modify a creature's skin to use the altered method
-- Will be skipped if the creature is lacking materials with id SKIN or LEATHER
function mod_creature_skin(creature)
	local skin = find_creature_material(creature, "SKIN") 
	local leather = find_creature_material(creature, "LEATHER")
	
	if skin == nil or leather == nil then
		return
	end
	-- Skin edits
	skin.flags.STOCKPILE_GLOB = true
	skin.flags.DO_NOT_CLEAN_GLOB = true
	
	skin.butcher_special_type = df.item_type.GLOB

	skin.reaction_class:insert("#", {new = true, value = "SKIN"})
end

-- As mod_creature_skin, but for scales
function mod_creature_scales(creature)
	local scales = find_creature_material(creature, "SCALE")
	
	if scales == nil then
		return
	end
	
	scales.flags.STOCKPILE_GLOB = true
	scales.flags.DO_NOT_CLEAN_GLOB = true
	scales.flags.ITEMS_LEATHER = true
	scales.flags.LEATHER = true
	
	scales.butcher_special_type = df.item_type.GLOB
	
	scales.reaction_class:insert("#", {new = true, value = "SKIN"})
	
	scales.reaction_product.id:insert("#", {new = true, value = "TAN_MAT"})
	scales.reaction_product.item_type:insert("#", -1)
	scales.reaction_product.item_subtype:insert("#", -1)
	
	local scale_mat_info = get_creature_mat_info(creature, "SCALE")
	scales.reaction_product.material.mat_type:insert("#", scale_mat_info.type)
	scales.reaction_product.material.mat_index:insert("#", scale_mat_info.index)
end

-- Alter the tan hide reaction to use globs instead of the default.
-- Based on the edits made by Modest Mod
function edit_tan_reaction()
	local tan_reaction
	
	for index, reaction in pairs(df.global.world.raws.reactions.reactions) do
		if reaction.code == "TAN_A_HIDE" then
			tan_reaction = reaction
			break
		end
	end
	
	if tan_reaction == nil then
		qerror("TAN_A_HIDE reaction is missing!")
	end
	
	-- ATM this is hardcoded assuming the vanilla TAN_A_HIDE is active!
	-- If the reaction has otherwise already been altered, this could cause problems.
	-- TODO: De-hardcode stuff
	local reagent =	tan_reaction.reagents[0]
	reagent.quantity = glob_size
	reagent.reaction_class = "SKIN"
	reagent.item_type = df.item_type.GLOB
	reagent.flags2.body_part = false
	
	has_edited_reaction = true
end

function register_patch(args)
	local world_patch = dfhack.reqscript("patch/world-patch")
	
	world_patch.register_patch({
		custom_args = args,
		custom_code = patch_code,
		fortress_mode = true,
		adventure_mode = false, -- For potential compatibility with adventure mode tanning reactions, disabled in that mode
		arena_mode = false,
	})
end

-- Function to be run by world-patch:
function patch_code(args)
	-- Apply edits to TAN_A_HIDE reaction if they haven't been made this session
	if has_edited_reaction == false then
		edit_tan_reaction()
	end
	
	if args.all == true then
		for index, creature in pairs(df.global.world.raws.creatures.all) do
			if args.skin == true then
				mod_creature_skin(creature)
			end
			if args.scales == true then
				mod_creature_scales(creature)
			end
		end
	elseif args.creature ~= nil then
		local creature
		
		for index, creature_raw in pairs(df.global.world.raws.creatures.all) do
			if creature_id == args.creature then
				creature = creature_raw
				break
			end
		end
		
		if creature == nil then
			qerror("Couldn't find creature with id: " .. args.creature)
		end
		
		if args.skin == true then
			mod_creature_skin(creature)
		end
		if args.scales == true then
			mod_creature_scales(creature)
		end
	end
end

dfhack.onStateChange.moreLeatherPatch = function(code)
	if code == SC_WORLD_UNLOADED then
		has_edited_reaction = false
	end
end

---------------------------------------------------------------------
function main(...)
	local args = utils.processArgs({...}, validArgs)

	if args.help then
		print(help)
		return
	end
	
	if args.amount and tonumber(args.amount) then
		glob_size = tonumber(args.amount)
	end
	
	if not args.skin and not args.scales then
		qerror("Please provide a modification to make")
	end
	
	if not args.creature and not args.all then
		qerror("Please provide a creature to modify")
	end
	
	-- Cleanup args, just in case necessary
	if args.skin then args.skin = true end
	if args.scales then args.scales = true end
	if args.all then args.all = true end
	
	register_patch(args)
end

if not dfhack_flags.module then
	main(...)
end