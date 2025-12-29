--[[pod_format="raw"]]
-- quest.lua - Quest/Mission system

-- ============================================
-- QUEST CONFIG
-- ============================================

QUEST_CONFIG = {
	-- Quest chain order
	quest_chain = { "intro", "protect_city", "make_friends", "find_love", "a_prick", "find_missions" },

	-- Quest display names
	quest_names = {
		intro = "Welcome to the City",
		protect_city = "Protect The City",
		make_friends = "Make Friends",
		find_love = "Find Love",
		a_prick = "A Prick",
		find_missions = "Find Missions",
	},

	-- Quest-specific settings
	intro = {
		people_to_meet = 5,
	},

	protect_city = {
		popularity_reward = 10,
	},

	make_friends = {
		fans_needed = 5,
	},

	-- Visual settings
	completion_linger_duration = 5,  -- seconds to show completion before next quest
}

-- ============================================
-- QUEST STATE
-- ============================================

-- Mission/Quest system state
mission = {
	-- Current quest tracking
	current_quest = nil,         -- "intro", "protect_city", "make_friends", "find_love", "find_missions"
	quest_complete = false,      -- is current quest complete?

	-- Intro quest (two phases: meet people, then talk to dealer)
	intro_npc = nil,             -- the intro NPC who approaches player after meeting 5 people
	intro_npc_spawned = false,   -- has the intro NPC been spawned yet?
	talked_to_dealer = false,    -- objective 2: talked to arms dealer
	npcs_encountered = 0,        -- NPCs encountered (5th becomes intro NPC)

	-- Quest 1: Protect the City
	fox_quest_offered = false,   -- has the fox quest been offered?
	fox_quest_accepted = false,  -- did player accept the quest?
	has_weapon = false,          -- objective 1: bought a weapon
	foxes_killed = 0,            -- objective 2: kill all foxes
	total_foxes = 0,             -- total foxes spawned

	-- Quest 2: Make Friends
	fans_at_quest_start = 0,     -- fans when quest started
	new_fans_needed = 5,         -- need 5 new fans

	-- Quest 3: Find Love
	had_lover_before_quest = false,  -- had a lover before this quest started
	lover_asked_troubles = false,    -- asked lover about their troubles (objective 2)

	-- Quest 4: A Prick (Cactus Monster)
	cactus_killed = false,       -- killed the cactus monster

	-- Quest 5: Find Missions
	talked_to_lover = false,     -- talked to a lover about troubles

	-- General tracking
	total_fans_met = 0,          -- count of fans met (5th triggers quest)
	quest_npc = nil,             -- NPC who gave the quest
}

-- Quest completion visual state
quest_complete_visual = {
	active = false,              -- showing completion animation
	start_time = 0,              -- when completion started
	linger_duration = QUEST_CONFIG.completion_linger_duration,
	completed_quest_name = "",   -- name of the completed quest
}

-- ============================================
-- QUEST FUNCTIONS
-- ============================================

-- Get display name for quest
function get_quest_name(quest_id)
	return QUEST_CONFIG.quest_names[quest_id] or "Unknown Quest"
end

-- Check if current quest objectives are complete
function check_quest_completion()
	-- Don't check completion while dialog or shop is active
	if dialog and dialog.active then return end
	if shop and shop.active then return end

	if mission.current_quest == "intro" then
		-- Intro quest has two objectives:
		-- 1. Meet 5 people (npcs_encountered >= 5)
		-- 2. Talk to an arms dealer (talked_to_dealer)
		-- Both must be complete
		if mission.npcs_encountered >= QUEST_CONFIG.intro.people_to_meet and mission.talked_to_dealer then
			complete_current_quest()
		end

	elseif mission.current_quest == "protect_city" then
		-- Objective 1: Have a weapon (auto-complete in debug mode or after buying)
		if DEBUG_CONFIG.debug_weapons then
			mission.has_weapon = true
		elseif #game.player.weapons > 0 then
			mission.has_weapon = true
		end

		-- Objective 2: Kill all foxes
		local foxes_done = mission.foxes_killed >= mission.total_foxes and mission.total_foxes > 0

		-- Quest complete when both objectives done
		if mission.has_weapon and foxes_done then
			complete_current_quest()
		end

	elseif mission.current_quest == "make_friends" then
		-- Need 5 new fans since quest started
		local new_fans = #fans - mission.fans_at_quest_start
		if new_fans >= mission.new_fans_needed then
			complete_current_quest()
		end

	elseif mission.current_quest == "find_love" then
		-- Need at least 1 lover AND must have talked to them about troubles
		if #lovers > 0 and mission.lover_asked_troubles then
			complete_current_quest()
		end

	elseif mission.current_quest == "a_prick" then
		-- Defeat the cactus monster
		if mission.cactus_killed then
			complete_current_quest()
		end

	elseif mission.current_quest == "find_missions" then
		-- Talked to a lover about troubles
		if mission.talked_to_lover then
			complete_current_quest()
		end
	end
end

-- Complete current quest and start next one
function complete_current_quest()
	if mission.quest_complete then return end  -- already completed
	mission.quest_complete = true

	-- Store quest name and start visual feedback
	local quest_name = get_quest_name(mission.current_quest)
	quest_complete_visual.active = true
	quest_complete_visual.start_time = time()
	quest_complete_visual.completed_quest_name = quest_name

	-- Quest-specific rewards
	if mission.current_quest == "protect_city" then
		-- Fox mission rewards popularity
		change_popularity(QUEST_CONFIG.protect_city.popularity_reward)
		printh("Rewarded " .. QUEST_CONFIG.protect_city.popularity_reward .. " popularity for completing fox mission!")
	end

	printh("Quest complete: " .. quest_name)
end

-- Update quest completion visual (call from _update)
function update_quest_complete_visual()
	if not quest_complete_visual.active then return end

	local elapsed = time() - quest_complete_visual.start_time

	-- After linger duration, advance to next quest
	if elapsed >= quest_complete_visual.linger_duration then
		printh("Quest completion linger done, advancing to next quest...")
		printh("Current quest before advance: " .. tostring(mission.current_quest))
		quest_complete_visual.active = false
		advance_to_next_quest()
		printh("Current quest after advance: " .. tostring(mission.current_quest))
		printh("foxes_spawned after advance: " .. tostring(foxes_spawned))
		printh("#foxes after advance: " .. #foxes)
	end
end

-- Start a new quest
function start_quest(quest_id)
	mission.current_quest = quest_id
	mission.quest_complete = false

	if quest_id == "intro" then
		-- Intro quest - meet 5 people, then talk to dealer
		mission.npcs_encountered = 0
		mission.intro_npc_spawned = false
		mission.talked_to_dealer = false
		printh("Started quest: Welcome to the City")

	elseif quest_id == "protect_city" then
		-- Already set up when accepting quest
		printh("Started quest: Protect The City")

	elseif quest_id == "make_friends" then
		mission.fans_at_quest_start = #fans
		mission.new_fans_needed = QUEST_CONFIG.make_friends.fans_needed
		printh("Started quest: Make Friends (need " .. mission.new_fans_needed .. " new fans)")

	elseif quest_id == "find_love" then
		mission.had_lover_before_quest = false  -- Reset so quest can complete
		mission.lover_asked_troubles = false
		printh("Started quest: Find Love")

	elseif quest_id == "a_prick" then
		mission.cactus_killed = false
		-- Spawn cactus monster
		spawn_cactus()
		printh("Started quest: A Prick - Cactus monster spawned!")

	elseif quest_id == "find_missions" then
		mission.talked_to_lover = false
		printh("Started quest: Find Missions")
	end
end

-- Advance to next quest in chain
function advance_to_next_quest()
	local next_quest = nil

	if mission.current_quest == "intro" then
		-- After intro, start the protect the city quest
		next_quest = "protect_city"
		-- Mark quest as offered/accepted so foxes spawn
		mission.fox_quest_offered = true
		mission.fox_quest_accepted = true
		printh("Calling spawn_foxes() from advance_to_next_quest...")
		spawn_foxes()
		printh("After spawn_foxes: foxes_spawned=" .. tostring(foxes_spawned) .. " #foxes=" .. #foxes)
	elseif mission.current_quest == "protect_city" then
		next_quest = "make_friends"
	elseif mission.current_quest == "make_friends" then
		next_quest = "find_love"
	elseif mission.current_quest == "find_love" then
		next_quest = "a_prick"
	elseif mission.current_quest == "a_prick" then
		next_quest = "find_missions"
	elseif mission.current_quest == "find_missions" then
		-- Quest chain complete - can add more later
		printh("All quests complete! More coming soon...")
		mission.current_quest = nil
		return
	end

	if next_quest then
		start_quest(next_quest)
	end
end

-- Get quest objectives for HUD display
function get_quest_objectives()
	local objectives = {}
	local cfg = QUEST_CONFIG

	if mission.current_quest == "intro" then
		-- Objective 1: Meet 5 people
		local people_needed = cfg.intro.people_to_meet
		local meet_status = (mission.npcs_encountered >= people_needed) and "[X]" or "[ ]"
		add(objectives, meet_status .. " Meet people (" .. mission.npcs_encountered .. "/" .. people_needed .. ")")
		-- Objective 2: Talk to arms dealer (only shows after meeting 5 people)
		if mission.npcs_encountered >= people_needed then
			local dealer_status = mission.talked_to_dealer and "[X]" or "[ ]"
			add(objectives, dealer_status .. " Talk to the arms dealer")
		end

	elseif mission.current_quest == "protect_city" then
		local weapon_status = mission.has_weapon and "[X]" or "[ ]"
		add(objectives, weapon_status .. " Buy a weapon")

		local living = get_living_fox_count()
		local fox_status = (living == 0 and mission.total_foxes > 0) and "[X]" or "[ ]"
		add(objectives, fox_status .. " Get rid of all foxes (" .. mission.foxes_killed .. "/" .. mission.total_foxes .. ")")

	elseif mission.current_quest == "make_friends" then
		local new_fans = #fans - mission.fans_at_quest_start
		local status = (new_fans >= mission.new_fans_needed) and "[X]" or "[ ]"
		add(objectives, status .. " Make " .. mission.new_fans_needed .. " new fans (" .. new_fans .. "/" .. mission.new_fans_needed .. ")")

	elseif mission.current_quest == "find_love" then
		-- Objective 1: Get a lover
		local lover_status = (#lovers > 0) and "[X]" or "[ ]"
		add(objectives, lover_status .. " Convince someone to date you")
		-- Objective 2: Talk to lover about troubles (only shows after having lover)
		if #lovers > 0 then
			local troubles_status = mission.lover_asked_troubles and "[X]" or "[ ]"
			add(objectives, troubles_status .. " Ask your lover about their troubles")
		end

	elseif mission.current_quest == "a_prick" then
		local status = mission.cactus_killed and "[X]" or "[ ]"
		add(objectives, status .. " Get rid of the cactus monster terrorizing downtown")

	elseif mission.current_quest == "find_missions" then
		local status = mission.talked_to_lover and "[X]" or "[ ]"
		add(objectives, status .. " Talk to a lover about their troubles")
	end

	return objectives
end
