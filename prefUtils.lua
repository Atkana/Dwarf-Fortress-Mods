local prefs = {}

--[[ Useful notes:
> For matinfo: dfhack.matinfo.find("MUSHROOM_HELMET_PLUMP:DRINK").type
> For matindex: dfhack.matinfo.find("MUSHROOM_HELMET_PLUMP:DRINK").index / matindex = dfhack.matinfo.find("STEEL").index 
> For creature index: 
-- df.creature_raw.find(index)
Structure of a preference:
	type
		0 (LikeMaterial) | 1 (LikeCreature) | 2 (LikeFood) | 3 (HateCreature) | 4 (LikeItem) | 5 (LikePlant) | 6 (LikeTree) | 7 (LikeColor) | 8 (LikeShape) | 9 (LikePoeticForm) | 10 (LikeMusicalForm) | 11 (LikeDanceForm)
	item_type
		[There's a lot, and I'm not going to list them all :P]
	creature_id
	color_id
	shape_id
	plant_id
	poetic_form_id
	musical_form_id
	dance_form_id
	item_subtype
	mattype
	matindex
	mat_state
		-1 (None) | 0 (Solid) | 1 (Liquid) | 2 (Gas) | 3 (Powder) | 4 (Paste) | 5 (Pressed)
	active
	prefstring_seed
	
	Note: item_type through to dance_form_id all share the same number (I believe they're linked to the same pointer?).
]]

local function getUnit(unit)
	local unit = unit
	if type(unit) == "userdata" then --Presume that what was given was a Unit
		return unit
	end
	
	if type(unit) == "string" then
		unit = tonumber(unit)
	end
	
	if type(unit) == "number" then
		local u = df.unit.find(unit)
		if u then
			return u
		else
			return false
		end
	end
end

--Used to check if the character has a fitting preference. If the character has a preference matching the filter, will return true, followed by the index of the preference.
prefs.hasPreference = function(unit, checks)
	local unit = getUnit(unit)
	--Assume unit is valid
	if unit.status.current_soul == nil then
		return false
	end
	
	local uprefs = unit.status.current_soul.preferences
	
	for i = 0, #uprefs-1 do
		local valid = true
		for variable, value in pairs(checks) do
			if uprefs[i][variable] ~= value then
				valid = false
				break
			end
		end
		
		if valid then
			return true, i --return true, followed by the index for that stat
		end
	end
end

--Changes the elements of an existing preference at the given index. returns true if successful
prefs.modifyPreference = function(unit, index, details)
	local unit = getUnit(unit)
	if unit.status.current_soul == nil then
		return false
	end
	
	local uprefs = unit.status.current_soul.preferences
	for k, v in pairs(details) do
		uprefs[index][k] = v
	end
	return true
end

--Creates and adds a new preference to the unit's list of preferences. Returns true if successful
prefs.addPreference = function(unit, details)
	local unit = getUnit(unit)
	if unit.status.current_soul == nil then
		return false
	end
	
	--Ensure that they don't already have the preference to begin with
	if prefs.hasPreference(unit, details) then
		--Note: This may give some false positives for different mat_states if the details don't explicitly state the mat_state
		return false
	end
	
	--The same ID is used across multiple variables. Even if only wanting to modify the creature_id, you must set all others to the same value
	local id = details.item_type or details.creature_id or details.color_id or details.shape_id or details.plant_id or details.poetic_form_id or details.musical_form_id or details.dance_form_id or -1
	
	local info = {
		new = df.unit_preference, --or df.unit_preference.T_type?
		type = details.type or 0,
		item_type = id,
		creature_id = id,
		color_id = id,
		shape_id = id,
		plant_id = id,
		poetic_form_id = id,
		musical_form_id = id,
		dance_form_id = id,
		item_subtype = details.item_subtype or -1,
		mattype = details.mattype or -1,
		matindex = details.matindex or -1,
		mat_state = details.mat_state or -1,
		active = details.active or true,
		prefstring_seed = details.prefstring_seed or 1, --?
	}
	
	--Do prefstring_seed randomisation?
	-- TODO
	
	unit.status.current_soul.preferences:insert("#", info)
	return true
end

-- Removes a preference that matches the details from the provided unit, if they have one that matches
prefs.removePreference = function(unit, details)
	local unit = getUnit(unit)
	if unit.status.current_soul == nil then
		return false
	end
	
	local has, index = prefs.hasPreference(unit, details)
	
	if has then
		unit.status.current_soul.preferences:erase(index)
		return true
	end
	return false
end

-- Wipes preferences of given unit
prefs.clearPreferences = function(unit)
	local unit = getUnit(unit)
	if unit.status.current_soul == nil then
		return false
	end
	
	--Mostly stolen from pref-adjust
	for index, pref in pairs(unit.status.current_soul.preferences) do
		pref:delete()
	end
	
	unit.status.current_soul.preferences:resize(0)
end

---------
return prefs
