--[[pod_format="raw"]]
-- quest.lua - Quest/Mission system

-- ============================================
-- QUEST CONFIG
-- ============================================

QUEST_CONFIG = {
	-- Quest chain order
	-- talk_to_companion quests are checkpoints between main quests
	quest_chain = {
		"intro",
		"protect_city",
		"make_friends",
		"find_love",
		"talk_to_companion_1",  -- leads to fix_home
		"fix_home",
		"talk_to_companion_2",  -- leads to a_prick
		"a_prick",
		"talk_to_companion_3",  -- leads to beyond_the_sea
		"beyond_the_sea",
		"talk_to_companion_4",  -- leads to mega_race
		"mega_race",
		"talk_to_companion_5",  -- leads to car_wrecker
		"car_wrecker",
		"talk_to_companion_6",  -- leads to auditor_kathy
		"auditor_kathy",
		"talk_to_companion_7",  -- leads to speed_dating
		"speed_dating",
		"talk_to_companion_8",  -- leads to bomb_delivery
		"bomb_delivery",
		"find_missions"
	},

	-- Quest display names
	quest_names = {
		intro = "Welcome to the City",
		protect_city = "Protect The City",
		make_friends = "Make Friends",
		find_love = "Find Love",
		talk_to_companion_1 = "Talk to Companion",
		fix_home = "Fix Home",
		talk_to_companion_2 = "Talk to Companion",
		a_prick = "A Prick",
		talk_to_companion_3 = "Talk to Companion",
		beyond_the_sea = "Beyond The Sea",
		talk_to_companion_4 = "Talk to Companion",
		mega_race = "Mega Race",
		talk_to_companion_5 = "Talk to Companion",
		car_wrecker = "Insurance Fraud",
		talk_to_companion_6 = "Talk to Companion",
		auditor_kathy = "Defeat Auditor Kathy",
		talk_to_companion_7 = "Talk to Companion",
		speed_dating = "Speed Dating",
		talk_to_companion_8 = "Talk to Companion",
		bomb_delivery = "Special Delivery",
		find_missions = "Find Missions",
	},

	-- Quest-specific settings
	intro = {
		people_to_meet = 5,
		money_reward = 50,
	},

	protect_city = {
		popularity_reward = 10,
		money_reward = 100,
	},

	make_friends = {
		fans_needed = 5,
		money_reward = 75,
	},

	find_love = {
		money_reward = 100,
	},

	talk_to_companion_1 = {
		money_reward = 0,
	},

	fix_home = {
		damaged_building_sprite = 129,  -- Cracked concrete sprite
		repair_hits_needed = 10,        -- Hammer hits to fully repair
		money_reward = 150,
	},

	talk_to_companion_2 = {
		money_reward = 0,
	},

	a_prick = {
		money_reward = 200,
	},

	talk_to_companion_3 = {
		money_reward = 0,
	},

	beyond_the_sea = {
		-- Aseprite/sprite map coordinates (0,0 = top-left, 128,128 = world center)
		-- These get converted to world coords via sprite_map_to_world()
		package_sprite_x = 216,
		package_sprite_y = 116,
		package_sprite = 134,           -- Package sprite
		hermit_sprite_x = 37,
		hermit_sprite_y = 217,
		money_reward = 250,
	},

	talk_to_companion_4 = {
		money_reward = 0,
	},

	mega_race = {
		money_reward = 500,
		popularity_finish = 10,   -- +10 popularity for finishing race
		popularity_win = 50,      -- +50 popularity for winning (1st place)
	},

	talk_to_companion_5 = {
		money_reward = 0,
	},

	car_wrecker = {
		money_reward = 300,
		time_limit = 90,          -- 60 seconds to wreck cars
		cars_needed = 12,         -- need to wreck 12+ cars to win
		popularity_reward = 25,   -- bonus popularity for completing
	},

	talk_to_companion_6 = {
		money_reward = 0,
	},

	auditor_kathy = {
		money_reward = 750,
		popularity_reward = 30,   -- bonus popularity for defeating boss
	},

	talk_to_companion_7 = {
		money_reward = 0,
	},

	speed_dating = {
		-- CONFIGURABLE: Adjust these for difficulty
		time_limit = 180,         -- seconds to complete (180 = 3 minutes)
		lovers_needed = 3,        -- number of new lovers required to win
		-- Rewards
		money_reward = 400,
		popularity_reward = 40,   -- big popularity boost for TV appearance
	},

	talk_to_companion_8 = {
		money_reward = 0,
	},

	bomb_delivery = {
		time_limit = 90,          -- 90 seconds to deliver the bomb (longer route)
		max_hits = 3,             -- car explodes after 3 hits
		money_reward = 500,
		-- Checkpoint route (Aseprite coords, converted to world at runtime)
		-- Route: start -> checkpoint1 -> checkpoint2 -> end
		checkpoints = {
			{ x = 101, y = 95 },   -- Start/Pickup point
			{ x = 118, y = 154 },  -- Checkpoint 1
			{ x = 156, y = 124 },  -- Checkpoint 2
			{ x = 232, y = 203 },  -- Final delivery point
		},
		checkpoint_radius = 40,   -- radius to trigger checkpoint
	},

	find_missions = {
		money_reward = 100,
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

	-- Quest 4: Fix Home
	has_hammer = false,          -- player has obtained a hammer
	building_repair_progress = 0,-- current repair hits (0 to repair_hits_needed)
	damaged_building = nil,      -- the building that needs repair {x, y, w, h}

	-- Quest 5: A Prick (Cactus Monster)
	cactus_killed = false,       -- killed the cactus monster

	-- Quest 6: Beyond The Sea
	stole_boat = false,          -- stole a boat for the mission
	has_package = false,         -- picked up the package
	delivered_package = false,   -- delivered to hermit
	package_location = nil,      -- {x, y} world coords
	hermit_location = nil,       -- {x, y} world coords
	hermit_npc = nil,            -- reference to hermit NPC

	-- Quest 7: Mega Race
	race_started = false,        -- has the race begun?
	race_finished = false,       -- did player finish?
	race_won = false,            -- did player win (1st place)?
	race_completed_once = false, -- has player ever completed the race? (enables replay)
	player_lap = 0,              -- current lap (0 = before start, 1-3 = racing)
	player_checkpoint = 1,       -- next checkpoint to hit (1-8)
	player_position = 1,         -- current race position (1st, 2nd, etc)
	race_checkpoints = nil,      -- world coordinates of checkpoints
	race_start_time = nil,       -- when race started
	racers = nil,                -- AI racer vehicles (references)
	racer_progress = nil,        -- {lap, checkpoint} for each racer

	-- Talk to Companion checkpoints (between main quests)
	talked_to_companion_1 = false,  -- before fix_home
	talked_to_companion_2 = false,  -- before a_prick
	talked_to_companion_3 = false,  -- before beyond_the_sea
	talked_to_companion_4 = false,  -- before mega_race
	talked_to_companion_5 = false,  -- before car_wrecker
	talked_to_companion_6 = false,  -- before auditor_kathy

	-- Quest 8: Car Wrecker (Insurance Fraud)
	wrecker_active = false,      -- is the wrecker timer running?
	wrecker_start_time = nil,    -- when the timer started
	wrecker_cars_wrecked = 0,    -- cars wrecked during this mission
	wrecker_completed = false,   -- did player complete the mission?
	wrecker_failed = false,      -- did player fail (time ran out)?

	-- Quest 9: Auditor Kathy (Boss Fight)
	kathy_killed = false,        -- killed the Auditor Kathy boss
	kathy_foxes_killed = 0,      -- foxes killed during this quest
	total_kathy_foxes = 3,       -- total foxes spawned with Kathy

	-- Talk to Companion 7 & 8 checkpoints
	talked_to_companion_7 = false,  -- before speed_dating
	talked_to_companion_8 = false,  -- before bomb_delivery

	-- Quest 10: Speed Dating (TV gameshow)
	speed_dating_active = false,      -- is the speed dating timer running?
	speed_dating_start_time = nil,    -- when the timer started
	speed_dating_lovers_at_start = 0, -- lovers count when quest started
	speed_dating_new_lovers = 0,      -- new lovers made during mission
	speed_dating_completed = false,   -- completed successfully?
	speed_dating_failed = false,      -- failed (time ran out)?

	-- Quest 11: Bomb Delivery
	bomb_delivery_active = false,     -- is the bomb delivery timer running?
	bomb_delivery_start_time = nil,   -- when the timer started
	bomb_delivery_hits = 0,           -- hits taken during delivery
	bomb_delivery_completed = false,  -- completed successfully?
	bomb_delivery_failed = false,     -- failed (car exploded or time ran out)?
	bomb_delivery_checkpoints = {},   -- list of {x, y} world coords for checkpoints
	bomb_delivery_current_cp = 1,     -- current checkpoint index (1-based)

	-- Quest 12: Find Missions
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
-- HELPER FUNCTIONS
-- ============================================

-- Convert sprite map coordinates to world coordinates
-- Sprite map is 256x256 pixels, each pixel = 16 world units
-- Map center (128,128) = world origin (0,0)
function sprite_map_to_world(sx, sy)
	local tile_size = MAP_CONFIG.tile_size  -- 16
	local map_center = 128  -- center of 256x256 map
	local world_x = (sx - map_center) * tile_size
	local world_y = (sy - map_center) * tile_size
	return world_x, world_y
end

-- Get ordinal suffix for a number (1st, 2nd, 3rd, etc)
function get_ordinal_suffix(n)
	if n == 1 then return "st"
	elseif n == 2 then return "nd"
	elseif n == 3 then return "rd"
	else return "th"
	end
end

-- Check if current quest is at or after a given quest in the chain
-- Used for unlocking features after certain points in the story
function is_quest_at_or_after(quest_id)
	if not mission.current_quest then return false end

	local chain = QUEST_CONFIG.quest_chain
	local current_index = nil
	local target_index = nil

	for i, q in ipairs(chain) do
		if q == mission.current_quest then
			current_index = i
		end
		if q == quest_id then
			target_index = i
		end
	end

	if current_index and target_index then
		return current_index >= target_index
	end
	return false
end

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

	elseif mission.current_quest == "talk_to_companion_1" then
		if mission.talked_to_companion_1 then
			complete_current_quest()
		end

	elseif mission.current_quest == "fix_home" then
		-- Objective 1: Have a hammer
		if game and game.player and game.player.weapons then
			for _, w in ipairs(game.player.weapons) do
				if w == "hammer" then
					mission.has_hammer = true
					break
				end
			end
		end
		-- Objective 2: Repair the building fully
		local cfg = QUEST_CONFIG.fix_home
		if mission.has_hammer and mission.building_repair_progress >= cfg.repair_hits_needed then
			complete_current_quest()
		end

	elseif mission.current_quest == "talk_to_companion_2" then
		if mission.talked_to_companion_2 then
			complete_current_quest()
		end

	elseif mission.current_quest == "a_prick" then
		-- Defeat the cactus monster
		if mission.cactus_killed then
			complete_current_quest()
		end

	elseif mission.current_quest == "talk_to_companion_3" then
		if mission.talked_to_companion_3 then
			complete_current_quest()
		end

	elseif mission.current_quest == "beyond_the_sea" then
		-- Delivered package to hermit
		if mission.delivered_package then
			complete_current_quest()
		end

	elseif mission.current_quest == "talk_to_companion_4" then
		if mission.talked_to_companion_4 then
			complete_current_quest()
		end

	elseif mission.current_quest == "mega_race" then
		-- Race finished (player completed 3 laps)
		-- Don't complete if this is a replay (pre_race_quest is set)
		if mission.race_finished and not mission.pre_race_quest then
			complete_current_quest()
		end

	elseif mission.current_quest == "talk_to_companion_5" then
		if mission.talked_to_companion_5 then
			complete_current_quest()
		end

	elseif mission.current_quest == "car_wrecker" then
		-- Check if wrecker mission completed successfully
		if mission.wrecker_completed then
			complete_current_quest()
		end

	elseif mission.current_quest == "talk_to_companion_6" then
		if mission.talked_to_companion_6 then
			complete_current_quest()
		end

	elseif mission.current_quest == "auditor_kathy" then
		-- Defeat Kathy AND all her fox minions
		if mission.kathy_killed and mission.kathy_foxes_killed >= mission.total_kathy_foxes then
			complete_current_quest()
		end

	elseif mission.current_quest == "talk_to_companion_7" then
		if mission.talked_to_companion_7 then
			complete_current_quest()
		end

	elseif mission.current_quest == "speed_dating" then
		-- Speed dating completed successfully
		if mission.speed_dating_completed then
			complete_current_quest()
		end

	elseif mission.current_quest == "talk_to_companion_8" then
		if mission.talked_to_companion_8 then
			complete_current_quest()
		end

	elseif mission.current_quest == "bomb_delivery" then
		-- Bomb delivered successfully
		if mission.bomb_delivery_completed then
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

	-- Get quest config for rewards
	local quest_cfg = QUEST_CONFIG[mission.current_quest]

	-- Money reward (all quests)
	if quest_cfg and quest_cfg.money_reward then
		game.player.money = game.player.money + quest_cfg.money_reward
		quest_complete_visual.money_reward = quest_cfg.money_reward
		printh("Rewarded $" .. quest_cfg.money_reward .. " for completing " .. quest_name)
	else
		quest_complete_visual.money_reward = nil
	end

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

	-- Auto-assign companion for any talk_to_companion quest
	if string.find(quest_id, "talk_to_companion") then
		ensure_companion_exists()
	end

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

	elseif quest_id == "talk_to_companion_1" then
		mission.talked_to_companion_1 = false
		printh("Started quest: Talk to Companion (before Fix Home)")

	elseif quest_id == "fix_home" then
		mission.has_hammer = false
		mission.building_repair_progress = 0
		-- Select a random lover's "home" building near them
		setup_damaged_building()
		printh("Started quest: Fix Home")

	elseif quest_id == "talk_to_companion_2" then
		mission.talked_to_companion_2 = false
		printh("Started quest: Talk to Companion (before A Prick)")

	elseif quest_id == "a_prick" then
		mission.cactus_killed = false
		-- Spawn cactus monster
		spawn_cactus()
		printh("Started quest: A Prick - Cactus monster spawned!")

	elseif quest_id == "talk_to_companion_3" then
		mission.talked_to_companion_3 = false
		printh("Started quest: Talk to Companion (before Beyond The Sea)")

	elseif quest_id == "beyond_the_sea" then
		mission.stole_boat = false
		mission.has_package = false
		mission.delivered_package = false
		-- Convert Aseprite/sprite map coords to world coords
		local cfg = QUEST_CONFIG.beyond_the_sea
		printh("DEBUG: Aseprite coords - Package(" .. cfg.package_sprite_x .. "," .. cfg.package_sprite_y .. ") Hermit(" .. cfg.hermit_sprite_x .. "," .. cfg.hermit_sprite_y .. ")")
		local pkg_x, pkg_y = sprite_map_to_world(cfg.package_sprite_x, cfg.package_sprite_y)
		local hermit_x, hermit_y = sprite_map_to_world(cfg.hermit_sprite_x, cfg.hermit_sprite_y)
		printh("DEBUG: World coords - Package(" .. pkg_x .. "," .. pkg_y .. ") Hermit(" .. hermit_x .. "," .. hermit_y .. ")")
		printh("DEBUG: Player spawns at (0,0), positive X = EAST, positive Y = SOUTH")
		mission.package_location = { x = pkg_x, y = pkg_y }
		mission.hermit_location = { x = hermit_x, y = hermit_y }
		-- Spawn hermit NPC at location
		spawn_hermit(hermit_x, hermit_y)
		printh("Started quest: Beyond The Sea - Package at " .. pkg_x .. "," .. pkg_y .. " Hermit at " .. hermit_x .. "," .. hermit_y)

	elseif quest_id == "talk_to_companion_4" then
		mission.talked_to_companion_4 = false
		printh("Started quest: Talk to Companion (before Mega Race)")

	elseif quest_id == "mega_race" then
		mission.race_started = false
		mission.race_finished = false
		mission.player_lap = 0
		mission.player_checkpoint = 1
		mission.player_position = 1
		mission.racers = {}
		mission.racer_progress = {}
		-- Convert Aseprite checkpoints to world coords
		mission.race_checkpoints = {}
		for _, cp in ipairs(RACE_CONFIG.checkpoints) do
			local wx, wy = sprite_map_to_world(cp.x, cp.y)
			add(mission.race_checkpoints, {x = wx, y = wy})
		end
		printh("Started quest: Mega Race - " .. #mission.race_checkpoints .. " checkpoints")

	elseif quest_id == "talk_to_companion_5" then
		mission.talked_to_companion_5 = false
		printh("Started quest: Talk to Companion (before Car Wrecker)")

	elseif quest_id == "car_wrecker" then
		mission.wrecker_active = false
		mission.wrecker_start_time = nil
		mission.wrecker_cars_wrecked = 0
		mission.wrecker_completed = false
		mission.wrecker_failed = false
		printh("Started quest: Insurance Fraud - Wreck " .. QUEST_CONFIG.car_wrecker.cars_needed .. " cars in " .. QUEST_CONFIG.car_wrecker.time_limit .. " seconds!")

	elseif quest_id == "talk_to_companion_6" then
		mission.talked_to_companion_6 = false
		printh("Started quest: Talk to Companion (before Auditor Kathy)")

	elseif quest_id == "auditor_kathy" then
		mission.kathy_killed = false
		mission.kathy_foxes_killed = 0
		mission.total_kathy_foxes = KATHY_CONFIG.fox_minion_count
		-- Spawn Kathy boss
		spawn_kathy()
		-- Spawn fox minions with Kathy
		spawn_kathy_foxes()
		printh("Started quest: Defeat Auditor Kathy - Boss spawned with " .. mission.total_kathy_foxes .. " fox minions!")

	elseif quest_id == "talk_to_companion_7" then
		mission.talked_to_companion_7 = false
		printh("Started quest: Talk to Companion (before Speed Dating)")

	elseif quest_id == "speed_dating" then
		-- Auto-start the timer when quest begins
		mission.speed_dating_active = true
		mission.speed_dating_start_time = time()
		mission.speed_dating_lovers_at_start = #lovers
		mission.speed_dating_new_lovers = 0
		mission.speed_dating_completed = false
		mission.speed_dating_failed = false
		printh("Started quest: Speed Dating - Make " .. QUEST_CONFIG.speed_dating.lovers_needed .. " new lovers in " .. QUEST_CONFIG.speed_dating.time_limit .. " seconds!")

	elseif quest_id == "talk_to_companion_8" then
		mission.talked_to_companion_8 = false
		printh("Started quest: Talk to Companion (before Bomb Delivery)")

	elseif quest_id == "bomb_delivery" then
		mission.bomb_delivery_active = false
		mission.bomb_delivery_start_time = nil
		mission.bomb_delivery_hits = 0
		mission.bomb_delivery_completed = false
		mission.bomb_delivery_failed = false
		mission.bomb_delivery_current_cp = 1
		-- Convert checkpoint sprite coords to world coords
		local cfg = QUEST_CONFIG.bomb_delivery
		mission.bomb_delivery_checkpoints = {}
		for i, cp in ipairs(cfg.checkpoints) do
			local wx, wy = sprite_map_to_world(cp.x, cp.y)
			add(mission.bomb_delivery_checkpoints, { x = wx, y = wy })
		end
		printh("Started quest: Special Delivery - " .. #mission.bomb_delivery_checkpoints .. " checkpoints, " .. cfg.time_limit .. " seconds!")

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
		next_quest = "talk_to_companion_1"
	elseif mission.current_quest == "talk_to_companion_1" then
		next_quest = "fix_home"
	elseif mission.current_quest == "fix_home" then
		next_quest = "talk_to_companion_2"
	elseif mission.current_quest == "talk_to_companion_2" then
		next_quest = "a_prick"
	elseif mission.current_quest == "a_prick" then
		next_quest = "talk_to_companion_3"
	elseif mission.current_quest == "talk_to_companion_3" then
		next_quest = "beyond_the_sea"
	elseif mission.current_quest == "beyond_the_sea" then
		next_quest = "talk_to_companion_4"
	elseif mission.current_quest == "talk_to_companion_4" then
		next_quest = "mega_race"
	elseif mission.current_quest == "mega_race" then
		-- Clean up race
		cleanup_race()
		next_quest = "talk_to_companion_5"
	elseif mission.current_quest == "talk_to_companion_5" then
		next_quest = "car_wrecker"
	elseif mission.current_quest == "car_wrecker" then
		next_quest = "talk_to_companion_6"
	elseif mission.current_quest == "talk_to_companion_6" then
		next_quest = "auditor_kathy"
	elseif mission.current_quest == "auditor_kathy" then
		-- Clean up Kathy boss
		cleanup_kathy()
		next_quest = "talk_to_companion_7"
	elseif mission.current_quest == "talk_to_companion_7" then
		next_quest = "speed_dating"
	elseif mission.current_quest == "speed_dating" then
		next_quest = "talk_to_companion_8"
	elseif mission.current_quest == "talk_to_companion_8" then
		next_quest = "bomb_delivery"
	elseif mission.current_quest == "bomb_delivery" then
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

	elseif mission.current_quest == "fix_home" then
		-- Objective 1: Get a hammer
		local hammer_status = mission.has_hammer and "[X]" or "[ ]"
		add(objectives, hammer_status .. " Obtain a hammer")
		-- Objective 2: Repair the building (progress shown in bar)
		local fix_cfg = QUEST_CONFIG.fix_home
		local repair_status = (mission.building_repair_progress >= fix_cfg.repair_hits_needed) and "[X]" or "[ ]"
		add(objectives, repair_status .. " Repair the damaged building")

	elseif mission.current_quest == "a_prick" then
		local status = mission.cactus_killed and "[X]" or "[ ]"
		add(objectives, status .. " Defeat the cactus monster")

	elseif mission.current_quest == "talk_to_companion_1" then
		local status = mission.talked_to_companion_1 and "[X]" or "[ ]"
		add(objectives, status .. " Talk to your companion")

	elseif mission.current_quest == "talk_to_companion_2" then
		local status = mission.talked_to_companion_2 and "[X]" or "[ ]"
		add(objectives, status .. " Talk to your companion")

	elseif mission.current_quest == "talk_to_companion_3" then
		local status = mission.talked_to_companion_3 and "[X]" or "[ ]"
		add(objectives, status .. " Talk to your companion")

	elseif mission.current_quest == "talk_to_companion_4" then
		local status = mission.talked_to_companion_4 and "[X]" or "[ ]"
		add(objectives, status .. " Talk to your companion")

	elseif mission.current_quest == "talk_to_companion_5" then
		local status = mission.talked_to_companion_5 and "[X]" or "[ ]"
		add(objectives, status .. " Talk to your companion")

	elseif mission.current_quest == "talk_to_companion_6" then
		local status = mission.talked_to_companion_6 and "[X]" or "[ ]"
		add(objectives, status .. " Talk to your companion")

	elseif mission.current_quest == "beyond_the_sea" then
		-- Objective 1: Pick up package
		local pkg_status = mission.has_package and "[X]" or "[ ]"
		add(objectives, pkg_status .. " Pick up the package")
		-- Objective 2: Steal a boat (only shows after picking up package)
		if mission.has_package then
			local boat_status = mission.stole_boat and "[X]" or "[ ]"
			add(objectives, boat_status .. " Steal a boat")
		end
		-- Objective 3: Deliver to hermit (only shows after stealing boat)
		if mission.stole_boat then
			local deliver_status = mission.delivered_package and "[X]" or "[ ]"
			add(objectives, deliver_status .. " Deliver to the island hermit")
		end

	elseif mission.current_quest == "mega_race" then
		if not mission.race_started then
			-- Before race: drive to start line
			add(objectives, "[ ] Drive to the start line")
		else
			-- During race: show lap progress
			local total_laps = RACE_CONFIG.total_laps
			local lap_status = mission.race_finished and "[X]" or "[ ]"
			add(objectives, lap_status .. " Complete " .. total_laps .. " laps (" .. mission.player_lap .. "/" .. total_laps .. ")")
			-- Show position
			local pos_suffix = get_ordinal_suffix(mission.player_position)
			add(objectives, "    Position: " .. mission.player_position .. pos_suffix)
		end

	elseif mission.current_quest == "car_wrecker" then
		local cfg = QUEST_CONFIG.car_wrecker
		if not mission.wrecker_active then
			-- Before starting: tell player to steal a car
			add(objectives, "[ ] Steal a car and start wrecking!")
		elseif mission.wrecker_failed then
			-- Failed - need to talk to companion again
			add(objectives, "[X] Time's up! Talk to your companion to try again")
		elseif mission.wrecker_completed then
			-- Completed successfully
			add(objectives, "[X] Wreck " .. cfg.cars_needed .. " cars (" .. mission.wrecker_cars_wrecked .. "/" .. cfg.cars_needed .. ")")
		else
			-- Active timer - show progress
			local status = (mission.wrecker_cars_wrecked >= cfg.cars_needed) and "[X]" or "[ ]"
			add(objectives, status .. " Wreck " .. cfg.cars_needed .. " cars (" .. mission.wrecker_cars_wrecked .. "/" .. cfg.cars_needed .. ")")
		end

	elseif mission.current_quest == "auditor_kathy" then
		-- Objective 1: Defeat Kathy
		local kathy_status = mission.kathy_killed and "[X]" or "[ ]"
		add(objectives, kathy_status .. " Defeat Auditor Kathy")
		-- Objective 2: Defeat her fox minions
		local fox_status = (mission.kathy_foxes_killed >= mission.total_kathy_foxes) and "[X]" or "[ ]"
		add(objectives, fox_status .. " Defeat fox minions (" .. mission.kathy_foxes_killed .. "/" .. mission.total_kathy_foxes .. ")")

	elseif mission.current_quest == "talk_to_companion_7" then
		local status = mission.talked_to_companion_7 and "[X]" or "[ ]"
		add(objectives, status .. " Talk to your companion")

	elseif mission.current_quest == "speed_dating" then
		local cfg = QUEST_CONFIG.speed_dating
		if not mission.speed_dating_active then
			-- Before starting: tell player the mission
			add(objectives, "[ ] Talk to NPCs to find new lovers!")
		elseif mission.speed_dating_failed then
			-- Failed - need to talk to companion again
			add(objectives, "[X] Time's up! Talk to your companion to try again")
		elseif mission.speed_dating_completed then
			-- Completed successfully
			add(objectives, "[X] Make " .. cfg.lovers_needed .. " new lovers (" .. mission.speed_dating_new_lovers .. "/" .. cfg.lovers_needed .. ")")
		else
			-- Active timer - show progress
			local status = (mission.speed_dating_new_lovers >= cfg.lovers_needed) and "[X]" or "[ ]"
			add(objectives, status .. " Make " .. cfg.lovers_needed .. " new lovers (" .. mission.speed_dating_new_lovers .. "/" .. cfg.lovers_needed .. ")")
		end

	elseif mission.current_quest == "talk_to_companion_8" then
		local status = mission.talked_to_companion_8 and "[X]" or "[ ]"
		add(objectives, status .. " Talk to your companion")

	elseif mission.current_quest == "bomb_delivery" then
		local cfg = QUEST_CONFIG.bomb_delivery
		local total_cps = #mission.bomb_delivery_checkpoints
		local current_cp = mission.bomb_delivery_current_cp
		if not mission.bomb_delivery_active then
			-- Before starting: tell player to steal a car
			add(objectives, "[ ] Steal a car with the bomb!")
		elseif mission.bomb_delivery_failed then
			-- Failed - car exploded or time ran out
			add(objectives, "[X] Mission failed! Talk to your companion to try again")
		elseif mission.bomb_delivery_completed then
			-- Completed successfully
			add(objectives, "[X] Deliver the bomb (" .. total_cps .. "/" .. total_cps .. ")")
		else
			-- Active timer - show checkpoint progress
			local cp_name = current_cp == total_cps and "FINAL DROP" or "Checkpoint " .. current_cp
			add(objectives, "[ ] " .. cp_name .. " (" .. (current_cp - 1) .. "/" .. total_cps .. ")")
			local hits_left = cfg.max_hits - mission.bomb_delivery_hits
			if hits_left <= 1 then
				add(objectives, "    WARNING: " .. hits_left .. " hit" .. (hits_left == 1 and "" or "s") .. " until explosion!")
			else
				add(objectives, "    Car integrity: " .. hits_left .. "/" .. cfg.max_hits .. " hits left")
			end
		end

	elseif mission.current_quest == "find_missions" then
		local status = mission.talked_to_lover and "[X]" or "[ ]"
		add(objectives, status .. " Talk to a lover about their troubles")
	end

	return objectives
end

-- ============================================
-- CAR WRECKER QUEST FUNCTIONS
-- ============================================

-- Start the car wrecker timer (called when player steals a car during quest)
function start_wrecker_timer()
	if mission.current_quest ~= "car_wrecker" then return end
	if mission.wrecker_active then return end  -- already started
	if mission.wrecker_completed then return end  -- already completed

	mission.wrecker_active = true
	mission.wrecker_start_time = time()
	mission.wrecker_cars_wrecked = 0
	mission.wrecker_failed = false
	printh("Car Wrecker timer started! Wreck " .. QUEST_CONFIG.car_wrecker.cars_needed .. " cars in " .. QUEST_CONFIG.car_wrecker.time_limit .. " seconds!")
end

-- Track a car wreck (called when a vehicle explodes)
function track_car_wreck()
	if mission.current_quest ~= "car_wrecker" then return end
	if not mission.wrecker_active then return end
	if mission.wrecker_completed or mission.wrecker_failed then return end

	mission.wrecker_cars_wrecked = mission.wrecker_cars_wrecked + 1
	printh("Car wrecked! " .. mission.wrecker_cars_wrecked .. "/" .. QUEST_CONFIG.car_wrecker.cars_needed)

	-- Check if we've reached the goal
	if mission.wrecker_cars_wrecked >= QUEST_CONFIG.car_wrecker.cars_needed then
		mission.wrecker_completed = true
		mission.wrecker_active = false
		-- Award bonus popularity
		change_popularity(QUEST_CONFIG.car_wrecker.popularity_reward)
		printh("Car Wrecker complete! +" .. QUEST_CONFIG.car_wrecker.popularity_reward .. " popularity!")
	end
end

-- Update car wrecker timer (call from main update)
function update_car_wrecker()
	if mission.current_quest ~= "car_wrecker" then return end
	if not mission.wrecker_active then return end
	if mission.wrecker_completed or mission.wrecker_failed then return end

	local elapsed = time() - mission.wrecker_start_time
	local time_limit = QUEST_CONFIG.car_wrecker.time_limit

	-- Check if time ran out
	if elapsed >= time_limit then
		if mission.wrecker_cars_wrecked >= QUEST_CONFIG.car_wrecker.cars_needed then
			-- Made it just in time!
			mission.wrecker_completed = true
			mission.wrecker_active = false
			change_popularity(QUEST_CONFIG.car_wrecker.popularity_reward)
			printh("Car Wrecker complete! +" .. QUEST_CONFIG.car_wrecker.popularity_reward .. " popularity!")
		else
			-- Failed - time ran out, revert to talk_to_companion_5
			fail_car_wrecker()
		end
	end
end

-- Fail car wrecker mission and revert to talk_to_companion_5
function fail_car_wrecker()
	mission.wrecker_failed = true
	mission.wrecker_active = false
	printh("Car Wrecker failed! Only wrecked " .. mission.wrecker_cars_wrecked .. "/" .. QUEST_CONFIG.car_wrecker.cars_needed .. " cars")

	-- Show failure message briefly, then revert quest
	mission.wrecker_fail_timer = time() + 3  -- 3 seconds to show failure message
end

-- Check if we need to revert quest after failure (call from main update)
function update_car_wrecker_failure()
	if not mission.wrecker_fail_timer then return end

	if time() >= mission.wrecker_fail_timer then
		-- Revert to talk_to_companion_5
		mission.wrecker_fail_timer = nil
		mission.talked_to_companion_5 = false  -- Reset so player can accept again
		mission.current_quest = "talk_to_companion_5"
		mission.quest_complete = false

		-- Reset wrecker state for retry
		mission.wrecker_active = false
		mission.wrecker_start_time = nil
		mission.wrecker_cars_wrecked = 0
		mission.wrecker_completed = false
		mission.wrecker_failed = false

		printh("Reverted to talk_to_companion_5 - try again!")
	end
end

-- Retry car wrecker mission (called from companion dialog)
function retry_car_wrecker()
	mission.wrecker_active = false
	mission.wrecker_start_time = nil
	mission.wrecker_cars_wrecked = 0
	mission.wrecker_completed = false
	mission.wrecker_failed = false
	printh("Car Wrecker reset - ready to try again!")
end

-- Get remaining time for car wrecker (returns seconds, or nil if not active)
function get_wrecker_time_remaining()
	if mission.current_quest ~= "car_wrecker" then return nil end
	if not mission.wrecker_active then return nil end

	local elapsed = time() - mission.wrecker_start_time
	local remaining = QUEST_CONFIG.car_wrecker.time_limit - elapsed
	return max(0, remaining)
end

-- Draw car wrecker HUD (timer only - wreck count is in mission objectives)
function draw_wrecker_hud()
	if mission.current_quest ~= "car_wrecker" then return end
	if not mission.wrecker_active then return end
	if mission.wrecker_completed or mission.wrecker_failed then return end

	-- Position on right side, below quest objectives
	local x = SCREEN_W - 180
	local y = 75  -- Below mission objectives

	-- Get remaining time
	local remaining = get_wrecker_time_remaining()
	local secs = flr(remaining)

	-- Draw timer (big, urgent)
	local timer_color = remaining < 10 and 12 or 22  -- red if < 10s, yellow otherwise
	print_shadow("TIME: " .. secs .. "s", x, y, timer_color)
end

-- Draw car wrecker failure message
function draw_wrecker_failure()
	if not mission.wrecker_failed then return end
	if not mission.wrecker_fail_timer then return end

	-- Show failure message in center of screen
	local msg = "TOO SLOW!"
	local msg2 = "Talk to your companion to try again."
	local x = SCREEN_W / 2
	local y = SCREEN_H / 2 - 20

	-- Draw semi-transparent background
	rectfill(x - 120, y - 10, x + 120, y + 30, 1)
	rect(x - 120, y - 10, x + 120, y + 30, 8)

	-- Draw text centered
	local tw1 = print(msg, 0, -100)
	local tw2 = print(msg2, 0, -100)
	print_shadow(msg, x - tw1/2, y, 8)  -- red
	print_shadow(msg2, x - tw2/2, y + 14, 7)  -- white
end

-- ============================================
-- FIX HOME QUEST FUNCTIONS
-- ============================================

-- Set up a damaged building for the fix_home quest
function setup_damaged_building()
	-- Find a building near a lover (or pick a random one if no lovers)
	local target_x, target_y = 0, 0
	if lovers and #lovers > 0 then
		local lover = lovers[1]
		target_x, target_y = lover.x, lover.y
	elseif game and game.player then
		target_x, target_y = game.player.x, game.player.y
	end

	-- Find closest building to target
	local closest_building = nil
	local closest_dist = 999999
	if buildings then
		for _, b in ipairs(buildings) do
			local bx = b.x + b.w / 2
			local by = b.y + b.h / 2
			local dx = bx - target_x
			local dy = by - target_y
			local dist = sqrt(dx * dx + dy * dy)
			if dist < closest_dist then
				closest_dist = dist
				closest_building = b
			end
		end
	end

	if closest_building then
		mission.damaged_building = {
			x = closest_building.x,
			y = closest_building.y,
			w = closest_building.w,
			h = closest_building.h,
			original_sprite = closest_building.wall_sprite,
		}
		-- Change building to damaged sprite
		closest_building.wall_sprite = QUEST_CONFIG.fix_home.damaged_building_sprite
		printh("Damaged building set up at " .. closest_building.x .. "," .. closest_building.y)
	end
end

-- Check if player is hitting the damaged building with hammer
-- Called from weapon.lua when melee attack connects
function check_building_repair(hit_x, hit_y, weapon_key)
	if mission.current_quest ~= "fix_home" then return false end
	if weapon_key ~= "hammer" then return false end
	if not mission.damaged_building then return false end

	local b = mission.damaged_building
	-- Check if hit is near the building
	if hit_x >= b.x - 16 and hit_x <= b.x + b.w + 16 and
	   hit_y >= b.y - 16 and hit_y <= b.y + b.h + 16 then
		mission.building_repair_progress = mission.building_repair_progress + 1
		printh("Building repair progress: " .. mission.building_repair_progress)

		-- Check if fully repaired
		local cfg = QUEST_CONFIG.fix_home
		if mission.building_repair_progress >= cfg.repair_hits_needed then
			-- Restore original sprite
			if buildings then
				for _, building in ipairs(buildings) do
					if building.x == b.x and building.y == b.y then
						building.wall_sprite = b.original_sprite
						break
					end
				end
			end
			printh("Building fully repaired!")
		end
		return true
	end
	return false
end

-- Draw repair progress bar (called from main.lua when fix_home quest active)
function draw_repair_progress_bar()
	if mission.current_quest ~= "fix_home" then return end
	if not mission.has_hammer then return end
	if not mission.damaged_building then return end

	local cfg = QUEST_CONFIG.fix_home
	local progress = mission.building_repair_progress / cfg.repair_hits_needed
	progress = min(1, max(0, progress))

	-- Draw at top center of screen
	local bar_w = 150
	local bar_h = 10
	local bar_x = (SCREEN_W - bar_w) / 2
	local bar_y = 20

	-- Draw label
	local label = "Repair Progress"
	local label_w = print(label, 0, -100)
	print_shadow(label, (SCREEN_W - label_w) / 2, bar_y - 12, 21)  -- Gold

	-- Draw border
	rect(bar_x - 1, bar_y - 1, bar_x + bar_w, bar_y + bar_h, 21)
	-- Draw background
	rectfill(bar_x, bar_y, bar_x + bar_w - 1, bar_y + bar_h - 1, 1)
	-- Draw fill
	local fill_w = flr(bar_w * progress)
	if fill_w > 0 then
		rectfill(bar_x, bar_y, bar_x + fill_w - 1, bar_y + bar_h - 1, 19)  -- Green
	end
end

-- ============================================
-- COMPANION ASSIGNMENT FUNCTIONS
-- ============================================

-- Find and assign a random nearby NPC as a companion (lover)
-- Used when starting talk_to_companion quests via debug start_quest
function assign_random_companion()
	if not game or not game.player then return nil end
	if not npcs or #npcs == 0 then return nil end

	local px, py = game.player.x, game.player.y
	local max_distance = 200  -- Look for NPCs within this range

	-- Collect nearby NPCs that aren't already fans/lovers
	local candidates = {}
	for _, npc in ipairs(npcs) do
		-- Skip hermits and special NPCs
		if npc.is_hermit then goto continue end

		-- Skip NPCs that are already fans
		local is_fan = false
		for _, fan_data in ipairs(fans) do
			if fan_data.npc == npc then
				is_fan = true
				break
			end
		end
		if is_fan then goto continue end

		-- Calculate distance
		local dx = npc.x - px
		local dy = npc.y - py
		local dist = sqrt(dx * dx + dy * dy)

		if dist <= max_distance then
			add(candidates, { npc = npc, dist = dist })
		end

		::continue::
	end

	-- If no candidates nearby, expand search to all NPCs
	if #candidates == 0 then
		for _, npc in ipairs(npcs) do
			if not npc.is_hermit then
				local is_fan = false
				for _, fan_data in ipairs(fans) do
					if fan_data.npc == npc then
						is_fan = true
						break
					end
				end
				if not is_fan then
					local dx = npc.x - px
					local dy = npc.y - py
					local dist = sqrt(dx * dx + dy * dy)
					add(candidates, { npc = npc, dist = dist })
				end
			end
		end
	end

	if #candidates == 0 then
		printh("No NPCs available to assign as companion!")
		return nil
	end

	-- Sort by distance (closest first)
	for i = 1, #candidates - 1 do
		for j = i + 1, #candidates do
			if candidates[j].dist < candidates[i].dist then
				candidates[i], candidates[j] = candidates[j], candidates[i]
			end
		end
	end

	-- Pick one of the closest NPCs (prefer closest, but add some randomness)
	local pick_range = min(5, #candidates)  -- Pick from closest 5
	local picked = candidates[flr(rnd(pick_range)) + 1]
	local npc = picked.npc

	-- Assign a random archetype
	local archetypes = PLAYER_CONFIG.archetypes
	local archetype = archetypes[flr(rnd(#archetypes)) + 1]

	-- Create fan data with max love (instant lover)
	local fan_data = {
		npc = npc,
		is_lover = true,
		love = PLAYER_CONFIG.love_meter_max,
		archetype = archetype,
	}
	add(fans, fan_data)
	add(lovers, npc)

	-- Mark the NPC as already checked for fan status
	npc.fan_checked = true

	printh("Assigned companion: NPC at " .. flr(npc.x) .. "," .. flr(npc.y) .. " (dist=" .. flr(picked.dist) .. ")")

	return npc
end

-- Ensure at least one companion exists for talk_to_companion quests
function ensure_companion_exists()
	if #lovers == 0 then
		local companion = assign_random_companion()
		if companion then
			printh("Created random companion for talk_to_companion quest")
		end
	else
		printh("Companion already exists (" .. #lovers .. " lovers)")
	end
end

-- ============================================
-- BEYOND THE SEA QUEST FUNCTIONS
-- ============================================

-- Spawn hermit NPC at island location
function spawn_hermit(x, y)
	if not npcs then return end

	-- Create hermit NPC using create_npc for proper field initialization
	local hermit = create_npc(x, y, 1)
	hermit.is_hermit = true  -- Special flag for hermit behavior
	hermit.name = "Hermit"

	add(npcs, hermit)
	mission.hermit_npc = hermit
	printh("Hermit spawned at " .. x .. "," .. y)
end

-- Update beyond the sea quest (check for package pickup and delivery)
function update_beyond_the_sea()
	if mission.current_quest ~= "beyond_the_sea" then return end
	if not game or not game.player then return end

	local p = game.player
	local interact_pressed = keyp("e")  -- E key to interact

	-- Check for package pickup
	if not mission.has_package and mission.package_location then
		local pkg = mission.package_location
		local dx = p.x - pkg.x
		local dy = p.y - pkg.y
		local dist = sqrt(dx * dx + dy * dy)
		if dist < 24 and interact_pressed then
			mission.has_package = true
			printh("Package picked up!")
		end
	end

	-- Check for delivery to hermit
	if mission.has_package and not mission.delivered_package and mission.hermit_npc then
		local hermit = mission.hermit_npc
		local dx = p.x - hermit.x
		local dy = p.y - hermit.y
		local dist = sqrt(dx * dx + dy * dy)
		if dist < 24 and interact_pressed then
			mission.delivered_package = true
			printh("Package delivered to hermit!")
		end
	end
end

-- Add package to visible list for depth sorting (if not picked up)
function add_package_to_visible(visible)
	if mission.current_quest ~= "beyond_the_sea" then return end
	if mission.has_package then return end
	if not mission.package_location then return end

	local pkg = mission.package_location
	local sx, sy = world_to_screen(pkg.x, pkg.y)

	-- Only add if on screen
	if sx > -32 and sx < SCREEN_W + 32 and sy > -32 and sy < SCREEN_H + 32 then
		-- Depth sort by bottom of 32x32 sprite (feet position = y + 16)
		local package_feet_y = pkg.y + 16
		add(visible, {
			type = "package",
			y = package_feet_y,
			cx = pkg.x,
			cy = pkg.y,
			sx = sx,
			sy = sy,
		})
	end
end

-- Draw package sprite (called from building.lua during depth-sorted render)
function draw_package_sprite(sx, sy)
	local sprite_id = QUEST_CONFIG.beyond_the_sea.package_sprite
	spr(sprite_id, sx - 16, sy - 16, 2, 2)
end

-- Draw pickup/talk prompts for beyond the sea quest
function draw_beyond_the_sea_prompts()
	if mission.current_quest ~= "beyond_the_sea" then return end
	if not game or not game.player then return end

	local p = game.player

	-- Package pickup prompt
	if not mission.has_package and mission.package_location then
		local pkg = mission.package_location
		local dx = p.x - pkg.x
		local dy = p.y - pkg.y
		local dist = sqrt(dx * dx + dy * dy)
		if dist < 24 then
			local sx, sy = world_to_screen(pkg.x, pkg.y)
			print_shadow("E: Pick up", sx - 20, sy - 20, 21)
		end
	end

	-- Hermit talk prompt
	if mission.has_package and not mission.delivered_package and mission.hermit_npc then
		local hermit = mission.hermit_npc
		local dx = p.x - hermit.x
		local dy = p.y - hermit.y
		local dist = sqrt(dx * dx + dy * dy)
		if dist < 24 then
			local sx, sy = world_to_screen(hermit.x, hermit.y)
			print_shadow("E: Talk", sx - 15, sy - 20, 21)
		end
	end
end

-- Draw package/hermit on minimap
-- Parameters match the NPC/building drawing convention:
-- cfg = MINIMAP_CONFIG, mx/my = minimap top-left, half_mw/half_mh = minimap half-size
-- px/py = player position in map coords, tile_size, half_map_w/half_map_h
function draw_beyond_the_sea_minimap(cfg, mx, my, half_mw, half_mh, px, py, tile_size, half_map_w, half_map_h)
	if mission.current_quest ~= "beyond_the_sea" then return end

	-- Draw package location (if not picked up)
	if not mission.has_package and mission.package_location then
		local pkg = mission.package_location
		-- Use same formula as NPCs/buildings: mx + (world_x / tile_size + half_map_w - px + half_mw)
		local marker_x = mx + (pkg.x / tile_size + half_map_w - px + half_mw)
		local marker_y = my + (pkg.y / tile_size + half_map_h - py + half_mh)
		-- Clamp to minimap bounds
		marker_x = max(cfg.x, min(cfg.x + cfg.width - 1, marker_x))
		marker_y = max(cfg.y, min(cfg.y + cfg.height - 1, marker_y))
		-- Blink the marker
		local blink = flr(time() * 3) % 2 == 0
		if blink then
			circfill(marker_x, marker_y, 2, 21)  -- Gold dot
		end
	end

	-- Draw hermit location (if package picked up)
	if mission.has_package and not mission.delivered_package and mission.hermit_location then
		local h = mission.hermit_location
		local marker_x = mx + (h.x / tile_size + half_map_w - px + half_mh)
		local marker_y = my + (h.y / tile_size + half_map_h - py + half_mh)
		-- Clamp to minimap bounds
		marker_x = max(cfg.x, min(cfg.x + cfg.width - 1, marker_x))
		marker_y = max(cfg.y, min(cfg.y + cfg.height - 1, marker_y))
		-- Blink the marker
		local blink = flr(time() * 3) % 2 == 0
		if blink then
			circfill(marker_x, marker_y, 2, 27)  -- Light green dot
		end
	end
end

-- ============================================
-- SPEED DATING QUEST FUNCTIONS
-- ============================================

-- Start the speed dating timer (called when speed_dating quest starts)
function start_speed_dating_timer()
	-- Only start during speed_dating quest (not talk_to_companion_7)
	if mission.current_quest ~= "speed_dating" then return end
	if mission.speed_dating_active then return end  -- already started
	if mission.speed_dating_completed then return end  -- already completed

	mission.speed_dating_active = true
	mission.speed_dating_start_time = time()
	mission.speed_dating_lovers_at_start = #lovers
	mission.speed_dating_new_lovers = 0
	mission.speed_dating_failed = false
	printh("Speed Dating timer started! Make " .. QUEST_CONFIG.speed_dating.lovers_needed .. " new lovers in " .. QUEST_CONFIG.speed_dating.time_limit .. " seconds!")
end

-- Track a new lover (called when a new lover is made during the quest)
function track_speed_dating_lover()
	-- Only works during speed_dating quest
	if mission.current_quest ~= "speed_dating" then return end
	if not mission.speed_dating_active then return end
	if mission.speed_dating_completed or mission.speed_dating_failed then return end

	-- Count new lovers since quest started
	mission.speed_dating_new_lovers = #lovers - mission.speed_dating_lovers_at_start
	printh("Speed Dating progress: " .. mission.speed_dating_new_lovers .. "/" .. QUEST_CONFIG.speed_dating.lovers_needed)

	-- Check if we've reached the goal
	if mission.speed_dating_new_lovers >= QUEST_CONFIG.speed_dating.lovers_needed then
		mission.speed_dating_completed = true
		mission.speed_dating_active = false
		-- Award bonus popularity for TV appearance
		change_popularity(QUEST_CONFIG.speed_dating.popularity_reward)
		printh("Speed Dating complete! +" .. QUEST_CONFIG.speed_dating.popularity_reward .. " popularity!")
	end
end

-- Update speed dating timer (call from main update)
function update_speed_dating()
	-- Only works during speed_dating quest
	if mission.current_quest ~= "speed_dating" then return end
	if not mission.speed_dating_active then return end
	if mission.speed_dating_completed or mission.speed_dating_failed then return end

	local elapsed = time() - mission.speed_dating_start_time
	local time_limit = QUEST_CONFIG.speed_dating.time_limit

	-- Continuously check for new lovers
	mission.speed_dating_new_lovers = #lovers - mission.speed_dating_lovers_at_start
	if mission.speed_dating_new_lovers >= QUEST_CONFIG.speed_dating.lovers_needed then
		mission.speed_dating_completed = true
		mission.speed_dating_active = false
		-- Freeze the timer at completion time
		mission.speed_dating_completion_time = max(0, time_limit - elapsed)
		change_popularity(QUEST_CONFIG.speed_dating.popularity_reward)
		printh("Speed Dating complete! +" .. QUEST_CONFIG.speed_dating.popularity_reward .. " popularity!")
		return
	end

	-- Check if time ran out
	if elapsed >= time_limit then
		-- Failed - time ran out
		fail_speed_dating()
	end
end

-- Fail speed dating mission and revert to talk_to_companion_7
function fail_speed_dating()
	mission.speed_dating_failed = true
	mission.speed_dating_active = false
	printh("Speed Dating failed! Only made " .. mission.speed_dating_new_lovers .. "/" .. QUEST_CONFIG.speed_dating.lovers_needed .. " lovers")

	-- Show failure message briefly, then revert quest
	mission.speed_dating_fail_timer = time() + 3  -- 3 seconds to show failure message
end

-- Check if we need to revert quest after failure (call from main update)
function update_speed_dating_failure()
	if not mission.speed_dating_fail_timer then return end

	if time() >= mission.speed_dating_fail_timer then
		-- Revert to talk_to_companion_7
		mission.speed_dating_fail_timer = nil
		mission.talked_to_companion_7 = false  -- Reset so player can accept again
		mission.current_quest = "talk_to_companion_7"
		mission.quest_complete = false

		-- Reset speed dating state for retry
		mission.speed_dating_active = false
		mission.speed_dating_start_time = nil
		mission.speed_dating_lovers_at_start = #lovers
		mission.speed_dating_new_lovers = 0
		mission.speed_dating_completed = false
		mission.speed_dating_failed = false

		printh("Reverted to talk_to_companion_7 - try again!")
	end
end

-- Get remaining time for speed dating (returns seconds, or nil if not active)
function get_speed_dating_time_remaining()
	-- Only works during speed_dating quest
	if mission.current_quest ~= "speed_dating" then return nil end
	-- Return time remaining if active, or frozen time if completed
	if not mission.speed_dating_active and not mission.speed_dating_completed then return nil end
	if not mission.speed_dating_start_time then return nil end

	-- If completed, return the frozen completion time
	if mission.speed_dating_completed and mission.speed_dating_completion_time then
		return mission.speed_dating_completion_time
	end

	local elapsed = time() - mission.speed_dating_start_time
	local remaining = QUEST_CONFIG.speed_dating.time_limit - elapsed
	return max(0, remaining)
end

-- Draw speed dating HUD (timer and progress) - prominent center-top position
function draw_speed_dating_hud()
	-- Only show HUD during speed_dating quest
	if mission.current_quest ~= "speed_dating" then return end
	-- Show HUD if active OR if just completed (to show success state briefly)
	if not mission.speed_dating_active and not mission.speed_dating_completed then return end
	-- Don't show if failed (failure message takes over)
	if mission.speed_dating_failed then return end

	local cfg = QUEST_CONFIG.speed_dating

	-- Get remaining time
	local remaining = get_speed_dating_time_remaining()
	local mins = flr(remaining / 60)
	local secs = flr(remaining % 60)

	-- Draw prominent timer at top-center of screen
	local time_text = mins .. ":" .. (secs < 10 and "0" or "") .. secs
	local date_text = "DATES: " .. mission.speed_dating_new_lovers .. "/" .. cfg.lovers_needed

	-- Measure text widths for centering
	local time_w = print(time_text, 0, -100)
	local date_w = print(date_text, 0, -100)

	local cx = SCREEN_W / 2
	local y = 8  -- Top of screen

	-- Draw background box
	local box_w = max(time_w, date_w) + 16
	rectfill(cx - box_w/2, y - 2, cx + box_w/2, y + 22, 1)
	rect(cx - box_w/2, y - 2, cx + box_w/2, y + 22, 6)

	-- Draw timer (white, red if < 30s)
	local timer_color = remaining < 30 and 12 or 33  -- red (12) if < 30s, white (33) otherwise
	print_shadow(time_text, cx - time_w/2, y, timer_color)

	-- Draw progress (pink/bright_red for dates/love theme)
	local progress_color = mission.speed_dating_new_lovers >= cfg.lovers_needed and 19 or 14  -- green (19) if complete, bright_red (14) otherwise
	print_shadow(date_text, cx - date_w/2, y + 12, progress_color)
end

-- Draw speed dating failure message
function draw_speed_dating_failure()
	if not mission.speed_dating_failed then return end
	if not mission.speed_dating_fail_timer then return end

	-- Show failure message in center of screen
	local msg = "NO CHEMISTRY!"
	local msg2 = "Talk to your companion to try again."
	local x = SCREEN_W / 2
	local y = SCREEN_H / 2 - 20

	-- Draw semi-transparent background
	rectfill(x - 120, y - 10, x + 120, y + 30, 1)
	rect(x - 120, y - 10, x + 120, y + 30, 8)

	-- Draw text centered
	local tw1 = print(msg, 0, -100)
	local tw2 = print(msg2, 0, -100)
	print_shadow(msg, x - tw1/2, y, 8)  -- red
	print_shadow(msg2, x - tw2/2, y + 14, 7)  -- white
end

-- ============================================
-- BOMB DELIVERY QUEST FUNCTIONS
-- ============================================

-- Start the bomb delivery timer (called when player steals a car during quest)
function start_bomb_delivery_timer()
	if mission.current_quest ~= "bomb_delivery" then return end
	if mission.bomb_delivery_active then return end  -- already started
	if mission.bomb_delivery_completed then return end  -- already completed

	mission.bomb_delivery_active = true
	mission.bomb_delivery_start_time = time()
	mission.bomb_delivery_hits = 0
	mission.bomb_delivery_failed = false
	printh("Bomb Delivery timer started! Deliver in " .. QUEST_CONFIG.bomb_delivery.time_limit .. " seconds, don't get hit more than " .. QUEST_CONFIG.bomb_delivery.max_hits .. " times!")
end

-- Track a hit on the bomb car (called when vehicle takes damage during quest)
function track_bomb_delivery_hit()
	if mission.current_quest ~= "bomb_delivery" then return false end
	if not mission.bomb_delivery_active then return false end
	if mission.bomb_delivery_completed or mission.bomb_delivery_failed then return false end

	mission.bomb_delivery_hits = mission.bomb_delivery_hits + 1
	printh("Bomb car hit! " .. mission.bomb_delivery_hits .. "/" .. QUEST_CONFIG.bomb_delivery.max_hits)

	-- Check if car explodes
	if mission.bomb_delivery_hits >= QUEST_CONFIG.bomb_delivery.max_hits then
		fail_bomb_delivery("KABOOM!")
		return true  -- Indicates car should explode
	end
	return false
end

-- Check if player reached current checkpoint (call from main update)
function update_bomb_delivery()
	if mission.current_quest ~= "bomb_delivery" then return end
	if not mission.bomb_delivery_active then return end
	if mission.bomb_delivery_completed or mission.bomb_delivery_failed then return end

	-- Must be in a vehicle to deliver
	if not player_vehicle then return end

	-- Check distance to current checkpoint
	local checkpoints = mission.bomb_delivery_checkpoints
	local cp_idx = mission.bomb_delivery_current_cp
	if not checkpoints or #checkpoints == 0 or cp_idx > #checkpoints then return end

	local target = checkpoints[cp_idx]
	local dx = player_vehicle.x - target.x
	local dy = player_vehicle.y - target.y
	local dist = sqrt(dx * dx + dy * dy)

	-- Checkpoint radius
	local radius = QUEST_CONFIG.bomb_delivery.checkpoint_radius
	if dist < radius then
		-- Reached checkpoint!
		if cp_idx >= #checkpoints then
			-- Final checkpoint - mission complete!
			mission.bomb_delivery_completed = true
			mission.bomb_delivery_active = false
			printh("Bomb delivered successfully! All " .. #checkpoints .. " checkpoints cleared!")
		else
			-- Advance to next checkpoint
			mission.bomb_delivery_current_cp = cp_idx + 1
			printh("Checkpoint " .. cp_idx .. " reached! Next: " .. mission.bomb_delivery_current_cp .. "/" .. #checkpoints)
		end
	end

	-- Check if time ran out
	local elapsed = time() - mission.bomb_delivery_start_time
	local time_limit = QUEST_CONFIG.bomb_delivery.time_limit
	if elapsed >= time_limit then
		fail_bomb_delivery("TOO SLOW!")
	end
end

-- Fail bomb delivery mission
function fail_bomb_delivery(reason)
	mission.bomb_delivery_failed = true
	mission.bomb_delivery_active = false
	mission.bomb_delivery_fail_reason = reason or "MISSION FAILED!"
	printh("Bomb Delivery failed: " .. mission.bomb_delivery_fail_reason)

	-- Show failure message briefly, then revert quest
	mission.bomb_delivery_fail_timer = time() + 3  -- 3 seconds to show failure message
end

-- Check if we need to revert quest after failure (call from main update)
function update_bomb_delivery_failure()
	if not mission.bomb_delivery_fail_timer then return end

	if time() >= mission.bomb_delivery_fail_timer then
		-- Revert to talk_to_companion_8
		mission.bomb_delivery_fail_timer = nil
		mission.talked_to_companion_8 = false  -- Reset so player can accept again
		mission.current_quest = "talk_to_companion_8"
		mission.quest_complete = false

		-- Reset bomb delivery state for retry
		mission.bomb_delivery_active = false
		mission.bomb_delivery_start_time = nil
		mission.bomb_delivery_hits = 0
		mission.bomb_delivery_completed = false
		mission.bomb_delivery_failed = false
		mission.bomb_delivery_current_cp = 1  -- Reset checkpoint progress

		printh("Reverted to talk_to_companion_8 - try again!")
	end
end

-- Get remaining time for bomb delivery (returns seconds, or nil if not active)
function get_bomb_delivery_time_remaining()
	if mission.current_quest ~= "bomb_delivery" then return nil end
	if not mission.bomb_delivery_active then return nil end

	local elapsed = time() - mission.bomb_delivery_start_time
	local remaining = QUEST_CONFIG.bomb_delivery.time_limit - elapsed
	return max(0, remaining)
end

-- Draw bomb delivery HUD (timer and checkpoint progress) - prominent center-top position
function draw_bomb_delivery_hud()
	if mission.current_quest ~= "bomb_delivery" then return end
	if not mission.bomb_delivery_active then return end
	if mission.bomb_delivery_completed or mission.bomb_delivery_failed then return end

	local cfg = QUEST_CONFIG.bomb_delivery
	local total_cps = #mission.bomb_delivery_checkpoints
	local current_cp = mission.bomb_delivery_current_cp

	-- Get remaining time
	local remaining = get_bomb_delivery_time_remaining()
	local secs = flr(remaining)

	-- Draw prominent timer at top-center of screen
	local time_text = secs .. "s"
	local cp_text = "CP: " .. (current_cp - 1) .. "/" .. total_cps
	local hits_left = cfg.max_hits - mission.bomb_delivery_hits
	local hits_text = "HITS: " .. hits_left .. "/" .. cfg.max_hits

	-- Measure text widths for centering
	local time_w = print(time_text, 0, -100)
	local cp_w = print(cp_text, 0, -100)
	local hits_w = print(hits_text, 0, -100)

	local cx = SCREEN_W / 2
	local y = 8  -- Top of screen

	-- Draw background box
	local box_w = max(time_w, max(cp_w, hits_w)) + 16
	rectfill(cx - box_w/2, y - 2, cx + box_w/2, y + 34, 1)
	rect(cx - box_w/2, y - 2, cx + box_w/2, y + 34, 6)

	-- Draw timer (big, urgent)
	local timer_color = remaining < 15 and 8 or 11  -- red if < 15s, green otherwise
	print_shadow(time_text, cx - time_w/2, y, timer_color)

	-- Draw checkpoint progress
	print_shadow(cp_text, cx - cp_w/2, y + 12, 7)

	-- Draw hits remaining (red warning if low)
	local hits_color = hits_left <= 1 and 8 or 7
	print_shadow(hits_text, cx - hits_w/2, y + 24, hits_color)
end

-- Draw bomb delivery failure message
function draw_bomb_delivery_failure()
	if not mission.bomb_delivery_failed then return end
	if not mission.bomb_delivery_fail_timer then return end

	-- Show failure message in center of screen
	local msg = mission.bomb_delivery_fail_reason or "MISSION FAILED!"
	local msg2 = "Talk to your companion to try again."
	local x = SCREEN_W / 2
	local y = SCREEN_H / 2 - 20

	-- Draw semi-transparent background
	rectfill(x - 120, y - 10, x + 120, y + 30, 1)
	rect(x - 120, y - 10, x + 120, y + 30, 8)

	-- Draw text centered
	local tw1 = print(msg, 0, -100)
	local tw2 = print(msg2, 0, -100)
	print_shadow(msg, x - tw1/2, y, 8)  -- red
	print_shadow(msg2, x - tw2/2, y + 14, 7)  -- white
end

-- Add bomb delivery current checkpoint to visible list for depth sorting
function add_bomb_target_to_visible(visible)
	if mission.current_quest ~= "bomb_delivery" then return end
	if not mission.bomb_delivery_active then return end

	local checkpoints = mission.bomb_delivery_checkpoints
	local cp_idx = mission.bomb_delivery_current_cp
	if not checkpoints or #checkpoints == 0 or cp_idx > #checkpoints then return end

	local target = checkpoints[cp_idx]
	local sx, sy = world_to_screen(target.x, target.y)

	-- Only add if on screen
	if sx > -32 and sx < SCREEN_W + 32 and sy > -32 and sy < SCREEN_H + 32 then
		-- Depth sort by bottom of 32x32 sprite
		local target_feet_y = target.y + 16
		add(visible, {
			type = "bomb_target",
			y = target_feet_y,
			cx = target.x,
			cy = target.y,
			sx = sx,
			sy = sy,
			is_final = (cp_idx == #checkpoints),  -- mark if final checkpoint
		})
	end
end

-- Draw bomb target sprite (uses package sprite - same as beyond_the_sea)
function draw_bomb_target_sprite(sx, sy)
	local sprite_id = QUEST_CONFIG.beyond_the_sea.package_sprite  -- Reuse package sprite
	spr(sprite_id, sx - 16, sy - 16, 2, 2)
end

-- Draw bomb delivery current checkpoint on minimap
function draw_bomb_delivery_minimap(cfg, mx, my, half_mw, half_mh, px, py, tile_size, half_map_w, half_map_h)
	if mission.current_quest ~= "bomb_delivery" then return end
	if not mission.bomb_delivery_active then return end

	local checkpoints = mission.bomb_delivery_checkpoints
	local cp_idx = mission.bomb_delivery_current_cp
	if not checkpoints or #checkpoints == 0 or cp_idx > #checkpoints then return end

	local target = checkpoints[cp_idx]
	local marker_x = mx + (target.x / tile_size + half_map_w - px + half_mw)
	local marker_y = my + (target.y / tile_size + half_map_h - py + half_mh)
	-- Clamp to minimap bounds
	marker_x = max(cfg.x, min(cfg.x + cfg.width - 1, marker_x))
	marker_y = max(cfg.y, min(cfg.y + cfg.height - 1, marker_y))
	-- Blink the marker (red for danger, yellow for intermediate)
	local blink = flr(time() * 4) % 2 == 0  -- Faster blink for urgency
	if blink then
		local color = (cp_idx == #checkpoints) and 8 or 10  -- Red for final, yellow for intermediate
		circfill(marker_x, marker_y, 2, color)
	end
end
