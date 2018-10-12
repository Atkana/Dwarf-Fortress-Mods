--Autoruns some minor tweaks to allow for playing non-standard races in adventure mode

--Settings. Edit these if you want to change how this script works.

	--If protagonist is true, the game will attempt to afflict any current adventurer not suffering from its effects with the foul Protagonist syndrome, causing them to experience the most harrowing of effects: being able to speak and learn! The effects are permanent so they should in theory effect world progression stuff post-retirement.
	local protagonist = true
	
	--If dooropen is true, the game will make it so your adventurer's caste is able to open doors. The effect lasts until you save, so there are no lasting effects beyond your adventurer's play session.
	local dooropen = true
	
	--If misunderstood is true, the game will make it so your adventurer's caste aren't considered a megabeast or semimegabeast. Having this on will probably cause some weird unforseen consequences (like maybe ending Ages and stuff?). Lasts until you save, so there are no lasting effects beyond your adventurer's play session... probably.
	local misunderstood = false
	
	--A messy way to implement protagonist that only exists as a workaround to a bug present in DF 43.05 (and probably versions before that) which prevents the [CAN_SPEAK] tag applied via syndromes from allowing the player to open the tal(k) menu. Only use this setting if you really want the effects of protagonist and the bug isn't currently fixed. messyLearn and messySpeak make it so adventurer's caste can learn and speak respectively. The effects last until you save, so there are no lasting effects beyond your adventurer's play session... probably.
	
	local messyLearn = false
	local messySpeak = false
	
--/Settings

--The script

if df.global.gamemode ~= 1 then
	--Not adventure mode, no need to run
	return
end

local adventurer = df.global.world.units.active[0]
local race = df.global.world.raws.creatures.all[adventurer.race]
local caste = race.caste[adventurer.caste]

if protagonist then
	--Give the current adventurer the protagonist syndrome
	dfhack.run_script("modtools/add-syndrome", "-syndrome", "kana_advtweaks_protagonist", "-target", adventurer.id, "-resetPolicy", "DoNothing")
end

if messyLearn then
	caste.flags.CAN_LEARN = true
end

if messySpeak then
	caste.flags.CAN_SPEAK = true
end

if dooropen then
	--Give the adventurer's race caste the ability to open doors
	caste.flags.CANOPENDOORS = true
end

if misunderstood then
	--Remove the Megabeast and Semimegabeast tags from adventurer's race caste
	caste.flags.MEGABEAST = false
	caste.flags.SEMIMEGABEAST = false
	--May also have to edit the caste-level version too
end