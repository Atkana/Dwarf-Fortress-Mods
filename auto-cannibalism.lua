-- Makes any creature that dies cannibal-able
--@ module = true
-- Release Version: 2

--[[ Relevant notes on how butchering filters apply:
- If a corpse is for a sapient creature, your government needs to have ethics that allow eating sapients: EAT_SAPIENT_OTHER must be either ACCEPTABLE or PERSONAL_MATTER
- The dead_dwarf flag must be disabled on the corpse.
- The corpse must not belong to a unit who belongs to the same civilization as your fortress i.e. the unit's `civ_id` value must differ from `df.global.ui.civ_id`
... Two workarounds from this are either to disconnect the corpse from the unit, by changing the corpse item's `unit_id` value to `-1`, or to edit the unit so their `civ_id` is `-1`. I'm not sure what the impact of either will be on gameplay, especially when necromancy is involved.
- The corpse must not belong to a unit with the tame flag.
]]

local help = [====[

auto-cannibalism
================
Automatically implements some bugfixes / workarounds to allow sapient corpses to be butchered.
Your entity still requires the necessary ethics to butcher sapient corpses, regardless of this script
i.e. their `EAT_SAPIENT_OTHER` must be either `ACCEPTABLE` or `PERSONAL_MATTER`.
This script must be running before a creature dies for it to be affected. Ideally add this to an `onLoad*.init` file.

When you run this, you may include the following optional arguments:

:-allowOwn:
	Normally you cannot butcher the corpses of creatures belonging to your civilization.
	With this argument, the script will perform a workaround to allow you to use them.
	It does so by removing some of the information that links them to your civilization which might have unintended side-effects (I imagine necromancy may be impacted).
	One such side-effect is that it will prevent you from being able to bury their corpses (but why waste some good meat?).

:-tameFix:
	Will enable a workaround to allow the corpses of tamed animals to be butchered.
	Technically not really related to cannibalism, but why not include it here?
	Actually, it might be necessary for butchering the buggy tame sapients (like tame Trolls).

Example usage:
Allow dead sapients of others to be butchered (ethics permitting): `auto-cannibalism`
As above, but allowing creatures from your own civ: `auto-cannibalism -allowOwn`
As above, but also allowing your dead animals to be butchered: `auto-cannibalism -allowOwn -tameFix`
]====]

---------------------------------------------------------------------
local utils = require "utils"
local eventful = require "plugins.eventful"

local validArgs = utils.invert({
	"help",
	"allowOwn",
	"tameFix",
})

scrub_civ = scrub_civ or false -- Option set by allowOwn. If `true`, units will have their `civ_id` wiped when they die, so their corpses can be used even by their own civ.
fix_tame = fix_tame or false -- If enabled, will additionally fix tame animals being unbutcherable
---------------------------------------------------------------------
function remove_civ_status(unit)
	unit.civ_id = -1
end

function remove_tame(unit)
	unit.flags1.tame = false
end

function on_item_created(item_id)
	local item = df.item.find(item_id)
	
	item.flags.dead_dwarf = false
	
	-- Check if this is this is truly a corpse that has an associated creature before performing any special modifications based on settings
	if ( not df.item_body_component:is_instance(item) or not (item.unit_id > -1) ) then
		return
	end
	
	local unit = df.unit.find(item.unit_id)
	
	-- Don't scrub details if the creature is still alive!
	if ( dfhack.units.isAlive(unit) ) then
		return
	end

	if ( scrub_civ == true ) then
		remove_civ_status(unit)
	end
	
	if ( fix_tame == true ) then
		remove_tame(unit)
	end
end

---------------------------------------------------------------------
initialized = initialized or false

function init()
	-- Set up everything to default values here
	initialized = true
	
	eventful.enableEvent(eventful.eventType.ITEM_CREATED, 1)
	eventful.onItemCreated["auto-cannabalism"] = on_item_created
	scrub_civ = false
	fix_tame = false
end

function reset()
	-- Set things to nil/default here
	initialized = false
	
	eventful.onItemCreated["auto-cannabalism"] = nil
	scrub_civ = false
	fix_tame = false
end

dfhack.onStateChange["auto-cannabalism"] = function(code)
	-- Wipe / reset data whenever loaded state changes
	if code == SC_WORLD_UNLOADED then
		reset()
	end
end

function main(...)
	local args = utils.processArgs({...}, validArgs)

	if args.help then
		print(help)
		return
	end

	-- Ensure world is actually loaded
	if not dfhack.isWorldLoaded() then
		qerror("The world needs to be loaded to use this.")
	end

	-- Initialize if not already
	if not initialized then init() end
	
	-- Handle arguments...
	if ( args.allowOwn ) then
		scrub_civ = true
	end
	
	if ( args.tameFix ) then
		fix_tame = true
	end
end

if not dfhack_flags.module then
	main(...)
end
