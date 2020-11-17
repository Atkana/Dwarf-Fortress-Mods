-- Modifies the rate that creatures can use their web spray abilities
--@ module = true

local help = [====[

patch/web-spray-rates
=====================
Alters the wait period for creatures with natural web attacks, to make them easier (or harder) to deal with.


:-mult <NUMBER>:
	The wait period for the web spray is multiplied by the given number. Required.
:-below <NUMBER>:
	 If provided, only web spray abilities with a wait period of the given value or lower will be affected. Optional.

:-help:
	Shows this help info.

Example Usage:
Any creature with a web spray rate of 100 or below will have that wait extended to 10 times its amount:
patch/web-spray-rates -mult 10 -below 100
]====]

local utils = require 'utils'

local validArgs = utils.invert({
	"help",
	"mult",
	"below",
})

function register_patch(args)
	local world_patch = dfhack.reqscript("patch/world-patch")
	
	world_patch.register_patch({
		custom_args = args,
		custom_code = patch_code,
		unique_id = "web-spray-rates",
		fortress_mode = true,
		adventure_mode = true,
		arena_mode = true,
	})
end

function apply_to_creature(creature, multiplier, apply_below)
	for index, caste in pairs(creature.caste) do
		for index, interaction_info in pairs(caste.body_info.interactions) do
			if interaction_info.type == df.caste_body_info.T_interactions.T_type.CAN_DO_INTERACTION then
				local interaction =	interaction_info.interaction
				if (interaction.interaction_type == "MATERIAL_EMISSION" or interaction.interaction_type == "RCP_MATERIAL_EMISSION") and interaction.material_breath == df.breath_attack_type.WEB_SPRAY then -- A web spray attack
					-- In future could add some other filters, like only if the material is silk, or the creature has strong webs
					local do_modify = true
					
					if apply_below ~= nil and interaction.wait_period > apply_below then
						do_modify = false
					end
					
					if do_modify then
						local new_value = interaction.wait_period * multiplier
						-- Round the value to a whole number
						new_value = math.floor(new_value + 0.5)
						
						-- Cap at a minimum of 0
						if new_value < 0 then
							new_value = 0
						end
						
						interaction.wait_period = new_value
					end
				end
			end
		end
	end
end

function patch_code(args)
	for index, creature in pairs(df.global.world.raws.creatures.all) do
		apply_to_creature(creature, args.mult, args.below)
	end
end

function main(...)
	local args = utils.processArgs({...}, validArgs)

	if args.help then
		print(help)
		return
	end
	
	if args.mult == nil or not tonumber(args.mult) then
		qerror("Please provide a multiplier with -multi")
	end
	
	-- Cleanup just in case necessary
	if args.mult then args.mult = tonumber(args.mult) end
	if args.below then args.below = tonumber(args.below) end
	
	register_patch(args)
end

if not dfhack_flags.module then
	main(...)
end