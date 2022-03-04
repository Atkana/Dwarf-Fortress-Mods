-- Announces the skill changes of citizens
--@ module = true

local help = [====[

announce-skills
===============
Creates announcements when skills change in fort mode.
This script requires that it be called from an appropriate init, or once per game session.

Valid announcement types:

:-best:
	Make an announcement whenever a citizen is the new best at a given skill.
	Will also trigger if a new citizen joins the fort if they're the new best-in-skill.
	Deaths can make things a bit wonky.
:-skillup:
	Make an announcement whenever a citizen raises a skill.

Valid skill types:

:-normal:
	Standard skills like crafts and jobs. Basically anything that doesn't fit into another category
:-medical:
	Medical skills.
:-personal:
	Skills like crutch walking, climbing, discipline.
:-social:
	Social skills like flattery, lying.
:-cultural:
	Some artforms like writing, poetry, reading. Strangely not dance, music, or singing.
:-military:
	Combat skills.
:-all:
	Causes announcements to trigger for all skill types

Misc:

:-bestColor:
	The color to use for the new best-in-skill announcements.
:-skillupColor:
	The color to use for the skill up announcements.
:-rate:
	Set the rate (in ticks) for how often skill changes are checked for.
	Default: 500

See https://docs.dfhack.org/en/stable/docs/Lua%20API.html#global-environment for color codes

Example:

The following will announce skill increases and new best-in-skills for standard and medical skills:
``announce-skills -best -skillup -normal -medical``

]====]

local utils = require("utils")
local valid_args = utils.invert({
	"help",
	"best",
	"skillup",
	"rate",
	"combat",
	"bestColor",
	"bestColour",
	"skillupColor",
	"skillupColour",
	"normal",
	"medical",
	"personal",
	"social",
	"cultural",
	"military",
	"all",
})


---------------------------------------------------------------------
-- Configured things
do_report_best = do_report_best or false
do_report_skillup = do_report_skillup or false

do_report_type = do_report_type or {
	["normal"] = false,
	["medical"] = false,
	["personal"] = false,
	["social"] = false,
	["cultural"] = false,
	["military"] = false,
}

color_best = color_best or COLOR_LIGHTCYAN
color_skillup = color_skillup or COLOR_LIGHTCYAN

rate = rate or 500 -- Rate (in ticks) that script checks for new skill changes
---------------------------------------------------------------------
best_skills_record = best_skills_record or {}
--[[ ^ format:
skill id = {
	who = unit ID,
	level = level of the skill
}]]
skills_record = skills_record or {}
--[[ ^ format:
unit id = {
	skill id = level
	...
}]]
loop = loop or nil
---------------------------------------------------------------------

function report_new_best(unit, skill_id, skill_level)
	local unit_name = dfhack.TranslateName(dfhack.units.getVisibleName(unit))
	local profession_name = df.job_skill.attrs[skill_id].caption_noun
	local level_name = get_skill_rating_string(skill_level)
	
	local text = unit_name .. " is now the fort's best " .. profession_name .. " (" .. level_name ..")"
	
	dfhack.gui.makeAnnouncement(df.announcement_type.MASTERPIECE_CRAFTED, {D_DISPLAY = true}, {}, text, color_best)
end

function report_skill_increase(unit, skill_id, skill_level)
	local unit_name = dfhack.TranslateName(dfhack.units.getVisibleName(unit))
	local skill_name = df.job_skill.attrs[skill_id].caption
	local level_name = get_skill_rating_string(skill_level)
	
	local text = unit_name .. " has improved their " .. skill_name .. " (" .. level_name ..")"
	
	dfhack.gui.makeAnnouncement(df.announcement_type.MASTERPIECE_CRAFTED, {D_DISPLAY = true}, {}, text, color_skillup)
end

function get_skill_class(skill_id)
	local skill = df.job_skill[skill_id]
	local skill_class = skill.type
	
	if skill_class == df.job_skill_class.Normal then
		return "normal"
	elseif skill_class == df.job_skill_class.Medical then
		return "medical"
	elseif skill_class == df.job_skill_class.Personal then
		return "personal"
	elseif skill_class == df.job_skill_class.Social then
		return "social"
	elseif skill_class == df.job_skill_class.Cultural then
		return "cultural"
	else -- one of the multiple military skill classes https://github.com/DFHack/df-structures/blob/master/df.skills.xml#L1212
		return "military"
	end
end

-- (skill_class_code is string returned from get_skill_class)
function should_report_skill_class(skill_class_code)
	return do_report_type[skill_class_code]
end

function get_skill_rating_string(level)
	if level <= 15 then
		return df.skill_rating[level]
	else
		local plus_level = level - 15
		return "Legendary+" .. plus_level
	end
end

local color_lookup = {
	["COLOR_RESET"] = COLOR_RESET,
	["COLOR_BLACK"] = COLOR_BLACK,
	["COLOR_BLUE"] = COLOR_BLUE,
	["COLOR_GREEN"] = COLOR_GREEN,
	["COLOR_CYAN"] = COLOR_CYAN,
	["COLOR_RED"] = COLOR_RED,
	["COLOR_MAGENTA"] = COLOR_MAGENTA,
	["COLOR_BROWN"] = COLOR_BROWN,
	["COLOR_GREY"] = COLOR_GREY,
	["COLOR_DARKGREY"] = COLOR_DARKGREY,
	["COLOR_LIGHTBLUE"] = COLOR_LIGHTBLUE,
	["COLOR_LIGHTGREEN"] = COLOR_LIGHTGREEN,
	["COLOR_LIGHTCYAN"] = COLOR_LIGHTCYAN,
	["COLOR_LIGHTRED"] = COLOR_LIGHTRED,
	["COLOR_LIGHTMAGENTA"] = COLOR_LIGHTMAGENTA,
	["COLOR_YELLOW"] = COLOR_YELLOW,
	["COLOR_WHITE"] = COLOR_WHITE,
}
function get_color_from_code(color_code)
	if color_lookup[color_code] then
		return color_lookup[color_code]
	else -- default to black if missing
		return COLOR_BLACK
	end
end

function get_unit_skills_table(unit)
	local out = {}
	
	for skill_id = 0, df.job_skill._last_item do
		out[skill_id] = dfhack.units.getNominalSkill(unit, skill_id)
	end
	
	return out
end

function generate_best_skills_table()
	local out = {}

	for index, unit in pairs(df.global.world.units.all) do
		if dfhack.units.isCitizen(unit) and dfhack.units.isAlive(unit) then
			local unit_skills = get_unit_skills_table(unit)
			
			for skill_id, level in pairs(unit_skills) do
				-- Generate best skill entry if not already present
				if out[skill_id] == nil then
					out[skill_id] = {
						["who"] = -1,
						["level"] = -2,
					}
				end
				
				if level > out[skill_id].level then -- unit is better than the best we have recorded so far
					out[skill_id].who = unit.id
					out[skill_id].level = level
				end
			end
		end
	end
	
	return out
end

function generate_skills_records_for_citizens()
	local out = {}
	
	for index, unit in ipairs(df.global.world.units.all) do
		if dfhack.units.isCitizen(unit) and dfhack.units.isAlive(unit) then
			local unit_skills = get_unit_skills_table(unit)
			out[unit.id] = unit_skills
		end
	end
	
	return out
end


function main_loop()
	-- SKILLUP
	local old_skills = skills_record
	local new_skills = generate_skills_records_for_citizens()
	
	if do_report_skillup then
		for unit_id, skills in pairs(new_skills) do
			-- Skip if the unit is a new entry
			if old_skills[unit_id] ~= nil then
				for skill_id, level in pairs(skills) do
					-- Only report if the skill is higher level than it was previously
					if level > old_skills[unit_id][skill_id] then
						-- Only create a report if its a skill from an enabled skill class
						local skill_class = get_skill_class(skill_id)
						if should_report_skill_class(skill_class) then
							report_skill_increase(df.unit.find(unit_id), skill_id, level)
						end
					end
				end
			end
		end
	end
	
	skills_record = new_skills -- Update record
	
	-- BEST
	-- Get the new best to compare
	local old_best = best_skills_record
	local new_best = generate_best_skills_table()
	
	for skill_id, entry in pairs(new_best) do
		-- If a unit has inherited the position as best (e.g. the previous best died, best was calculated in a different order), and they're not ACTUALLY better than the best, don't make an announcement about it
		-- Also don't bother if they were already the recorded best
		local level_is_better = new_best[skill_id].level > old_best[skill_id].level
		local is_different_person = new_best[skill_id].who ~= old_best[skill_id].who
		
		if level_is_better and is_different_person then
			if do_report_best then
				report_new_best(df.unit.find(new_best[skill_id].who), skill_id, new_best[skill_id].level)
			end
		end
	end
	
	best_skills_record = new_best -- Update record to new record
	
	-- Set this loop to run again
	loop = dfhack.timeout(rate, "ticks", main_loop)
end

function init()
	-- Wipe any previous entries and replace them with starter ones
	best_skills_record = generate_best_skills_table()
	skills_record = generate_skills_records_for_citizens()
	
	-- Since we don't need to run a check right now, we'll bypass running the main loop and just start its timer
	loop = dfhack.timeout(rate, "ticks", main_loop)
end
---------------------------------------------------------------------
dfhack.onStateChange.announceSkillsStateChange = dfhack.onStateChange.announceSkillsStateChange or function(code)
	if code == SC_WORLD_UNLOADED then
		-- Wipe previously registered skills (even though we don't actually need to)
		best_skills_record = {}
		skills_record = {}
		
		loop = nil -- The loop will disable itself on unload anyway, so we just have to clear our record of it
	elseif dfhack.world.isFortressMode() and code == SC_MAP_LOADED then
		init()
	end
end

function main(...)
	local args = utils.processArgs({...}, validArgs)
	
	if args.help then
		print(help)
		return
	end
	
	-- What announcements to make
	do_report_best = (args.best ~= nil) or false
	do_report_skillup = (args.skillup ~= nil) or false
	
	-- What sort of skills to track
	if args.all then
		do_report_type.normal = true
		do_report_type.medical = true
		do_report_type.personal = true
		do_report_type.social = true
		do_report_type.cultural = true
		do_report_type.military = true
	else
		do_report_type.normal = (args.normal ~= nil) or false
		do_report_type.medical = (args.medical ~= nil) or false
		do_report_type.personal = (args.personal ~= nil) or false
		do_report_type.social = (args.social ~= nil) or false
		do_report_type.cultural = (args.cultural ~= nil) or false
		do_report_type.military = (args.military ~= nil) or false
	end
	
	-- Colors (these ones won't revert to default if omitted)
	if args.bestColor or args.bestColour then
		local color_code = args.bestColor or args.bestColour
		local color = get_color_from_code(color_code)
		
		color_best = color
	end
	if args.skillupColor or args.skillupColour then
		local color_code = args.skillupColor or args.skillupColour
		local color = get_color_from_code(color_code)
		
		color_skillup = color
	end
	
	-- Rate (also doesn't revert)
	if args.rate then
		rate = tonumber(args.rate)
	end
	
	if dfhack.isWorldLoaded() and dfhack.world.isFortressMode() then
		-- Game is already in play, so initialise right away
		init()
	end
end

if not dfhack_flags.module then
	main(...)
end