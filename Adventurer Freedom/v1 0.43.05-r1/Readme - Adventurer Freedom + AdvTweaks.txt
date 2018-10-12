===ADVENTURER FREEDOM===
=File Additions=
[-Dwarf Fortress Directory-]
	onMapLoad_KanaAdvtweaks.init
	onLoad_AutoFreedom.init
	[raw]
		[objects]
			inorganic_kana_advtweaks.txt
	[hack]
		[scripts]
			adventurer-freedom.lua
			kana-advtweaks.lua
			auto-adventurer-freedom.lua

=Mod Info=
+Auto Adventurer Freedom+ (auto-adventurer-freedom.lua)
The new swanky version of Adventurer Freedom I made while twiddling my thumbs waiting for my DFFD registration email to arrive so I could upload the original version of this pack. Unlike the legacy version, Auto Adventurer Freedom runs automatically during adventurer creation.

Features:
	- Start as part of any civilization
		... or at the very least, an outsider
	- Play as any creature, including world-unique generated ones
	- Have natural skills automatically added (bugfix)
	- Be able to pick from any of the skills
	
Every feature can be disabled/edited by altering the settings variables near the top of the auto-adventurer-freedom file. If you don't want the script to run automatically altogether simply remove onLoad_AutoFreedom.init

Because of the automatic nature of the script, there are a few things that can't be done. The following is a list of lacking features and potential workarounds:
	- Play as a specific caste
		Solution: Use adventurer-freedom
	- Set skill/attribute pool sizes
		Solution: Use adventurer-freedom
	- Change appearance
		Solution: Use change-appearance (not included)

+Adventurer Freedom+ (adventurer-freedom.lua)
Brief Feature Overview:
	- Play as any creature, including world-unique generated creatures (contains spoilers)
	- Start as a member of any Civilization
	- Start as an Outsider of any race
	- (Bugfix) Begin with any natural skills you should have
	- Edit the size of your attribute and skill pool
	
Quick and Dirty Guide:
> Begin creating an adventurer of any race.
> When you get to the point where you choose your civilization, pick the one you want your adventurer to belong to, or run adventurer-freedom for more options.
> When you get to skills and attributes page, run adventurer-freedom to choose the race and caste you actually want you adventurer to be. You can also use adventurer-freedom on this page to edit your points pool if you want.
> Proceed through the rest of adventurer creation as normal.
	
Usage:
adventurer-freedom is only used during adventurer creation. What it does is based on the page you run it on.

When run the script on the Skills and Attributes page:
	You'll first be asked:
	"Would you like to choose a special race for your adventurer? [Y/N]"
		If you accept then you'll be given a series of prompts to select your adventurer's race
		If you decline you'll be asked the next question.
	"Would you like to change your available Attribute and Skill points? [Y/N]"
		If you accept then you'll be given a couple of prompts to alter your remaining point levels
		If you decline then that's it for this page.

When run the script on the page where you choose your Entity:
	You'll first be asked:
	"Would you like to be able to start as part of any entity? [Y/N]"
		If you accept then the list of available entities to pick from will change to display all the entities in your world (technically, there's a setting enabled by default that hides entities without names because they're buggy). The option to be an Outsider is also included.
		If you decline you'll be presented with the next, entirely redundant, question.
	"Would you like to be able to play as an Outsider? [Y/N]"
		If you accept then the option to play as an outsider will appear, if it wasn't there already. There's not really much point to this existing, since accepting the previous question would've given you the option anyway :P
		If you decline then that's it for this page.

+AdvTweaks+
Contains a small set of tweaks to help enable a playable adventure mode when playing non-standard races, which run automatically whenever adventure mode is launched. The script's features can be toggled on/off by editing the variables at the top of "kana-advtweaks.lua" - the variables are commented with an explanation of what they do. If you want to have different options on a per-save basis, instead move "kana-advtweaks.lua" into raw/scripts (create the folder if it doesn't already exist). Here's a brief description of what the features are and what they do:
The "Perfectly Fine" Features:

	protagonist - Defaults ON
	Affects your adventurer with a special syndrome that allows them to learn and speak. It doesn't make any changes to the world beyond your character and has the bonus of affecting how your adventurer acts when retired (probably). 
	NOTE: Unfortunately, a bug in the current version of Dwarf Fortress (0.43.05) means that the player can't open the tal(k) menu even though their character can now speak. For now you should also enable messyprotagonist if you want to be able to speak while controlling your character :(
	
The "Most Likely Safe" Features:

	dooropen - Defaults ON
	Until the world is unloaded, all units that belong to your adventurer's race caste will be able to open doors.
	
The "I'm Not Sure Of The Repercussions" Features:

	messyLearn + messySpeak - Defaults OFF
	A messy version of protagonist to workaround some hard-coded limitations. Until the world is unloaded, all units that belong to your adventurer's race caste will be capable of learning/speaking.
	
	misunderstood - Defualts OFF
	Hard-coded behaviour means that any Megabeast or Semimegabeast is instantly met with no-quarter combat, but what if all that fearsome dragon wants to do is read everyone a poem it just wrote? Until the world is unloaded, all units that belong to your adventurer's race caste won't count as Megabeasts or semimegabeasts (what's the worst that could happen? :P)
	

As of now, the only feature that requires any raw changes is "protagonist". If you don't plan on using the "protagonist" feature, then you're free to not install "inorganic_kana_advtweaks.txt". Make sure to toggle "protagonist" to false in "kana-advtweaks.lua" if you do this.