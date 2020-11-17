-- Manages and applies custom code patches
--@ module = true

local help = [====[

patch/world-patch
=================
Manages and applies custom code patches in-game.
Intended as a resource for use in other scripts, rather than to be run as a script itself.
]====]

local utils = require 'utils'

local validArgs = utils.invert({
	"help"
})

---------------------------------------------------------------------
registered_patches = registered_patches or {}
next_id = next_id or 1
---------------------------------------------------------------------
function new_id()
	local id = next_id
	next_id = next_id + 1
	
	return id
end

function new_patch()
	local out = {
		patch_type = "custom",
		fort_mode = false,
		adventure_mode = false,
		arena_mode = false,
		temporary = false,
	}
	
	return out
end

-- Register a new patch to be managed by this script
function register_patch(data)
	local patch = new_patch()
	local id
	
	if data.patch_type == nil or data.patch_type == "custom" then
		-- Custom patch
		patch.patch_type = "custom"
		if data.custom_code == nil then
			qerror("Custom patches require a custom_code entry!")
		else
			patch.custom_code = data.custom_code
		end
		
		patch.custom_args = data.custom_args or nil
	elseif data.patch_type == "creature" then
		-- Creature patch
	end
	
	-- Manage ids...
	id = data.unique_id or new_id()
	
	-- Active modes...
	if data.fortress_mode ~= nil then
		patch.fortress_mode = data.fortress_mode
	end
	if data.adventure_mode ~= nil then
		patch.adventure_mode = data.adventure_mode
	end
	if data.arena_mode ~= nil then
		patch.arena_mode = data.arena_mode
	end
	
	-- Temporary...
	if data.temporary ~= nil then
		patch.temporary = data.temporary
	end
	
	-- If the world is currently loaded, this patch will be marked as temporary, and will be deleted when the world is unloaded.
	-- This is working on the assumption that any patches added in-game (via command) should only apply to that specific world or game instance.
	-- Register patches in the main menu if you don't want them removed.
	if dfhack.isWorldLoaded() then -- TODO: The check
		patch.temporary = true
	end
	
	registered_patches[id] = patch
	
	-- If the world is already loaded, run the patch immediately (if it should be run)
	if dfhack.isWorldLoaded() and should_apply_patch(patch) == true then
		apply_patch(patch)
	end
	
	-- Return the id so patch scripts can unregister themselves if they want to
	return id
end

-- Unregister a patch
-- Note that this doesn't undo anything that's already been changed by the patch
function unregister_patch(id)
	registered_patches[id] = nil
end

-- Unregisters all patches with the `temporary` flag.
-- (the flag is usually set for world-specific patches, as well as patches registered during gameplay, rather than in the menu)
function unregister_temporary_patches()
	-- First mark every patch that needs unregistering
	-- Then separately unregister them (avoids removing things from a table while we're also navigating through it).
	local unregister_list = {}
	
	for id, patch in pairs(registered_patches) do
		if patch.temporary == true then
			table.insert(unregister_list, id)
		end
	end
	
	for index, id in ipairs(unregister_list) do
		unregister_patch(id)
	end
end

-- Run this to apply a patch
-- This will work out which patch to actually run based on the patch's type
function apply_patch(patch)
	-- Handle different patches differently
	if patch.patch_type == "custom" then
		apply_custom_patch(patch)
	end
end

function apply_custom_patch(patch)
	patch.custom_code(patch.custom_args)
end

--[[
function apply_creature_patch(patch, creature)
	patch.code(creature)
end
]]

-- Returns true if the patch should be run in the current game mode
function is_correct_game_mode(patch)
	local mode
	local correct_mode = false
	
	if dfhack.world.isFortressMode() then
		mode = "fortress"
	elseif dfhack.world.isAdventureMode() then
		mode = "adventure"
	elseif dfhack.world.isArena() then
		mode = "arena"
	elseif dfhack.world.isLegends() then
		mode = "legends"
	end
	
	if mode == "adventure" and patch.adventure_mode == true then
		correct_mode = true
	elseif mode == "fortress" and patch.fortress_mode == true then
		correct_mode = true
	elseif mode == "arena" and patch.arena_mode == true then
		correct_mode = true
	end
	
	return correct_mode
end

-- Returns true if the current patch should be applied
function should_apply_patch(patch)
	local should_apply = true
	
	if is_correct_game_mode(patch) == false then
		should_apply = false
	end
	-- TODO: Option for filters
	
	return should_apply
end

-- Apply the effects of all relevant patches
function try_apply_patches()
	local creature_patches = {} -- Store of all creature patches that should be run in the current game mode
	for id, patch in pairs(registered_patches) do
		if patch.patch_type == "custom" and should_apply_patch(patch) then
			apply_patch(patch)
		end
		
		--[=[
		if is_correct_game_mode(patch) == true then
			if patch.patch_type == "custom" then -- Custom scripts have no special filters, and will just be immediately run
				apply_patch(patch)
			--[[
			elseif patch.patch_type == "creature" then
				table.insert(creature_patches)
			]]
			end
		end
		]=]
	end
	
	-- Creature patches
	--[[
	if #creature_patches > 0 then
		-- Run through every creature and attempt to apply each creature patch to it
		-- Provided it matches the patch's filters
		for index, creature in pairs(df.global.world.raws.creatures.all) do
			-- Run through every 
			for _, patch in ipairs(creature_patches) do
				if patch.filter == nil or patch.filter(creature) == true then
					apply_creature_patch(patch, creature)
				end
			end
		end
	end
	]]
	
end

dfhack.onStateChange.worldPatch = function(code)
	if code == SC_WORLD_UNLOADED then
		unregister_temporary_patches()
	elseif code == SC_WORLD_LOADED then
		try_apply_patches()
	end
end
---------------------------------------------------------------------

function main(...)
	local args = utils.processArgs({...}, validArgs)

	if args.help then
		print(help)
		return
	end
end

if not dfhack_flags.module then
	main(...)
end