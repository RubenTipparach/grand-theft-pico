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
		"talk_to_companion_0",  -- leads to a_prick (fallback if die from cactus)
		"a_prick",              -- cactus monster
		"talk_to_companion_1",  -- leads to fix_home
		"fix_home",
		"talk_to_companion_2",  -- leads to beyond_the_sea
		"beyond_the_sea",
		"talk_to_companion_3",  -- leads to mega_race
		"mega_race",
		"talk_to_companion_4",  -- leads to car_wrecker
		"car_wrecker",
		"talk_to_companion_5",  -- leads to auditor_kathy
		"auditor_kathy",
		"talk_to_companion_6",  -- leads to speed_dating
		"speed_dating",
		"talk_to_companion_7",  -- leads to bomb_delivery
		"bomb_delivery",
		"talk_to_companion_8",  -- leads to alien_invasion
		"alien_invasion",
	},

	-- Quest display names
	quest_names = {
		intro = "Welcome to the City",
		protect_city = "Protect The City",
		make_friends = "Make Friends",
		find_love = "Find Love",
		talk_to_companion_0 = "Talk to Companion",
		a_prick = "A Prick",
		talk_to_companion_1 = "Talk to Companion",
		fix_home = "Fix Home",
		talk_to_companion_2 = "Talk to Companion",
		beyond_the_sea = "Beyond The Sea",
		talk_to_companion_3 = "Talk to Companion",
		mega_race = "Mega Race",
		talk_to_companion_4 = "Talk to Companion",
		car_wrecker = "Insurance Fraud",
		talk_to_companion_5 = "Talk to Companion",
		auditor_kathy = "Defeat Auditor Kathy",
		talk_to_companion_6 = "Talk to Companion",
		speed_dating = "Speed Dating",
		talk_to_companion_7 = "Talk to Companion",
		bomb_delivery = "Special Delivery",
		talk_to_companion_8 = "Talk to Companion",
		alien_invasion = "Alien Invasion",
	},

	-- Quest-specific settings
	intro = {
		people_to_meet = 5,
		money_reward = 50,
	},

	protect_city = {
		popularity_reward = 10,
		money_reward = 200,
	},

	make_friends = {
		fans_needed = 5,
		money_reward = 175,
	},

	find_love = {
		money_reward = 300,
	},

	talk_to_companion_0 = {
		money_reward = 0,
	},

	a_prick = {
		money_reward = 400,
	},

	talk_to_companion_1 = {
		money_reward = 0,
	},

	fix_home = {
		damaged_building_sprite = 129,  -- Cracked concrete sprite
		repair_hits_needed = 10,        -- Hammer hits to fully repair
		money_reward = 250,
	},

	talk_to_companion_2 = {
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
		money_reward = 350,
	},

	talk_to_companion_3 = {
		money_reward = 0,
	},

	mega_race = {
		money_reward = 500,
		popularity_finish = 10,   -- +10 popularity for finishing race
		popularity_win = 50,      -- +50 popularity for winning (1st place)
	},

	talk_to_companion_4 = {
		money_reward = 0,
	},

	car_wrecker = {
		money_reward = 1000,
		time_limit = 90,          -- 60 seconds to wreck cars
		cars_needed = 12,         -- need to wreck 12+ cars to win
		popularity_reward = 25,   -- bonus popularity for completing
	},

	talk_to_companion_5 = {
		money_reward = 0,
	},

	auditor_kathy = {
		money_reward = 1250,
		popularity_reward = 30,   -- bonus popularity for defeating boss
	},

	talk_to_companion_6 = {
		money_reward = 0,
	},

	speed_dating = {
		-- CONFIGURABLE: Adjust these for difficulty
		time_limit = 120,         -- seconds to complete (180 = 3 minutes)
		lovers_needed = 3,        -- number of new lovers required to win
		-- Rewards
		money_reward = 600,
		popularity_reward = 40,   -- big popularity boost for TV appearance
	},

	talk_to_companion_7 = {
		money_reward = 0,
	},

	bomb_delivery = {
		time_limit = 90,          -- 90 seconds to deliver the bomb (longer route)
		max_hits = 3,             -- car explodes after 3 hits
		money_reward = 1000,
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

	talk_to_companion_8 = {
		money_reward = 0,
	},

	alien_invasion = {
		money_reward = 1000,      -- Big reward for final boss
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
	current_quest = nil,         -- "intro", "protect_city", ..., "alien_invasion"
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
	talked_to_companion_0 = false,  -- before a_prick
	talked_to_companion_1 = false,  -- before fix_home
	talked_to_companion_2 = false,  -- before beyond_the_sea
	talked_to_companion_3 = false,  -- before mega_race
	talked_to_companion_4 = false,  -- before car_wrecker
	talked_to_companion_5 = false,  -- before auditor_kathy

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

	-- Talk to Companion 6, 7 & 8 checkpoints
	talked_to_companion_6 = false,  -- before speed_dating
	talked_to_companion_7 = false,  -- before bomb_delivery
	talked_to_companion_8 = false,  -- before alien_invasion

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
	bomb_picked_up = false,           -- has player picked up the bomb?
	bomb_car = nil,                   -- the specific car with the bomb (only this car counts)
	-- Explosion countdown (after reaching final checkpoint)
	bomb_countdown_active = false,    -- is the countdown running?
	bomb_countdown_start = nil,       -- when countdown started
	bomb_countdown_duration = 10,     -- seconds until explosion
	bomb_exploded = false,            -- has the bomb exploded?
	bomb_target_building = nil,       -- building to demolish

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
		-- Just need at least 1 lover
		if #lovers > 0 then
			complete_current_quest()
		end

	elseif mission.current_quest == "talk_to_companion_0" then
		if mission.talked_to_companion_0 then
			complete_current_quest()
		end

	elseif mission.current_quest == "a_prick" then
		-- Defeat the cactus monster
		if mission.cactus_killed then
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

	elseif mission.current_quest == "beyond_the_sea" then
		-- Delivered package to hermit
		if mission.delivered_package then
			complete_current_quest()
		end

	elseif mission.current_quest == "talk_to_companion_3" then
		if mission.talked_to_companion_3 then
			complete_current_quest()
		end

	elseif mission.current_quest == "mega_race" then
		-- Race finished (player completed 3 laps)
		-- Don't complete if this is a replay (pre_race_quest is set)
		if mission.race_finished and not mission.pre_race_quest then
			complete_current_quest()
		end

	elseif mission.current_quest == "talk_to_companion_4" then
		if mission.talked_to_companion_4 then
			complete_current_quest()
		end

	elseif mission.current_quest == "car_wrecker" then
		-- Check if wrecker mission completed successfully
		if mission.wrecker_completed then
			complete_current_quest()
		end

	elseif mission.current_quest == "talk_to_companion_5" then
		if mission.talked_to_companion_5 then
			complete_current_quest()
		end

	elseif mission.current_quest == "auditor_kathy" then
		-- Defeat Kathy AND all her fox minions
		if mission.kathy_killed and mission.kathy_foxes_killed >= mission.total_kathy_foxes then
			complete_current_quest()
		end

	elseif mission.current_quest == "talk_to_companion_6" then
		if mission.talked_to_companion_6 then
			complete_current_quest()
		end

	elseif mission.current_quest == "speed_dating" then
		-- Speed dating completed successfully
		if mission.speed_dating_completed then
			complete_current_quest()
		end

	elseif mission.current_quest == "talk_to_companion_7" then
		if mission.talked_to_companion_7 then
			complete_current_quest()
		end

	elseif mission.current_quest == "bomb_delivery" then
		-- Bomb delivered successfully
		if mission.bomb_delivery_completed then
			complete_current_quest()
		end

	elseif mission.current_quest == "talk_to_companion_8" then
		if mission.talked_to_companion_8 then
			complete_current_quest()
		end

	elseif mission.current_quest == "alien_invasion" then
		-- Mothership destroyed
		if mission.mothership_killed then
			complete_current_quest()
		end
	end
end

-- Complete current quest and start next one
function complete_current_quest()
	if mission.quest_complete then return end  -- already completed
	mission.quest_complete = true

	sfx(SFX.mission_complete)  -- mission complete sound

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

	-- Auto-save on quest completion
	save_game()
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
		printh("Started quest: Find Love")

	elseif quest_id == "talk_to_companion_0" then
		mission.talked_to_companion_0 = false
		printh("Started quest: Talk to Companion (before A Prick)")

	elseif quest_id == "a_prick" then
		mission.cactus_killed = false
		-- Spawn cactus monster
		spawn_cactus()
		printh("Started quest: A Prick - Cactus monster spawned!")

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

	elseif quest_id == "talk_to_companion_3" then
		mission.talked_to_companion_3 = false
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

	elseif quest_id == "talk_to_companion_4" then
		mission.talked_to_companion_4 = false
		printh("Started quest: Talk to Companion (before Car Wrecker)")

	elseif quest_id == "car_wrecker" then
		mission.wrecker_active = false
		mission.wrecker_start_time = nil
		mission.wrecker_cars_wrecked = 0
		mission.wrecker_completed = false
		mission.wrecker_failed = false
		printh("Started quest: Insurance Fraud - Wreck " .. QUEST_CONFIG.car_wrecker.cars_needed .. " cars in " .. QUEST_CONFIG.car_wrecker.time_limit .. " seconds!")

	elseif quest_id == "talk_to_companion_5" then
		mission.talked_to_companion_5 = false
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

	elseif quest_id == "talk_to_companion_6" then
		mission.talked_to_companion_6 = false
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

	elseif quest_id == "talk_to_companion_7" then
		mission.talked_to_companion_7 = false
		printh("Started quest: Talk to Companion (before Bomb Delivery)")

	elseif quest_id == "bomb_delivery" then
		mission.bomb_delivery_active = false
		mission.bomb_delivery_start_time = nil
		mission.bomb_delivery_hits = 0
		mission.bomb_delivery_completed = false
		mission.bomb_delivery_failed = false
		mission.bomb_delivery_current_cp = 1
		mission.bomb_picked_up = false
		mission.bomb_car = nil
		-- Convert checkpoint sprite coords to world coords
		local cfg = QUEST_CONFIG.bomb_delivery
		mission.bomb_delivery_checkpoints = {}
		for i, cp in ipairs(cfg.checkpoints) do
			local wx, wy = sprite_map_to_world(cp.x, cp.y)
			add(mission.bomb_delivery_checkpoints, { x = wx, y = wy })
		end
		-- Car will spawn when player picks up the bomb (not at quest start)
		printh("Started quest: Special Delivery - " .. #mission.bomb_delivery_checkpoints .. " checkpoints, " .. cfg.time_limit .. " seconds!")

	elseif quest_id == "talk_to_companion_8" then
		mission.talked_to_companion_8 = false
		printh("Started quest: Talk to Companion (before Alien Invasion)")

	elseif quest_id == "alien_invasion" then
		mission.mothership_killed = false
		mission.alien_invasion_started = false
		mission.game_complete = false
		-- Spawn mothership and minions
		spawn_mothership()
		spawn_initial_minions()
		mission.alien_invasion_started = true
		printh("Started quest: Alien Invasion - Mothership spawned!")

	end

	-- Auto-save on quest start
	save_game()
end

-- Get the previous talk_to_companion quest for the current quest
-- Returns the talk_to_companion quest that precedes the current main quest
-- For early quests (intro through find_love), returns "find_love" as checkpoint
-- For talk_to_companion quests themselves, returns that same quest
function get_previous_checkpoint_quest()
	local current = mission.current_quest
	if not current then return "find_love" end

	-- If already on a talk_to_companion quest, just restart it
	if string.find(current, "talk_to_companion") then
		return current
	end

	-- Map main quests to their preceding talk_to_companion checkpoint
	local checkpoint_map = {
		-- Early quests restart themselves to preserve progress
		intro = "intro",  -- restart from beginning
		protect_city = "protect_city",  -- restart mission, preserve kill count
		make_friends = "make_friends",  -- restart mission, preserve fan count
		find_love = "find_love",  -- restart mission
		-- a_prick now has talk_to_companion_0 as checkpoint
		a_prick = "talk_to_companion_0",
		-- Main quests with checkpoints
		fix_home = "talk_to_companion_1",
		beyond_the_sea = "talk_to_companion_2",
		mega_race = "talk_to_companion_3",
		car_wrecker = "talk_to_companion_4",
		auditor_kathy = "talk_to_companion_5",
		speed_dating = "talk_to_companion_6",
		bomb_delivery = "talk_to_companion_7",
		alien_invasion = "talk_to_companion_8",
	}

	return checkpoint_map[current] or "talk_to_companion_0"
end

-- Reset quest to previous checkpoint on death
-- Cleans up any active quest state and restarts from checkpoint
function reset_quest_on_death()
	local checkpoint = get_previous_checkpoint_quest()
	local current = mission.current_quest

	printh("[DEATH] Resetting quest from '" .. tostring(current) .. "' to checkpoint '" .. checkpoint .. "'")

	-- Clean up active quest state based on current quest
	if current == "protect_city" then
		-- Full reset: cleanup foxes and respawn all of them
		if cleanup_foxes then cleanup_foxes() end
		-- Reset kill counter and spawn fresh foxes
		mission.foxes_killed = 0
		foxes_spawned = false  -- allow spawn_foxes to run again
		if spawn_foxes then spawn_foxes() end
	elseif current == "a_prick" then
		-- Clean up cactus
		if cleanup_cactus then cleanup_cactus() end
	elseif current == "mega_race" then
		-- Clean up race
		if cleanup_race then cleanup_race() end
	elseif current == "car_wrecker" then
		-- Clean up demolition derby
		if cleanup_derby then cleanup_derby() end
	elseif current == "auditor_kathy" then
		-- Clean up Kathy boss
		if cleanup_kathy then cleanup_kathy() end
	elseif current == "speed_dating" then
		-- Reset speed dating state
		mission.speed_dating_active = false
		mission.speed_dating_completed = false
		mission.speed_dating_failed = false
	elseif current == "bomb_delivery" then
		-- Reset bomb delivery state
		mission.bomb_delivery_active = false
		mission.bomb_delivery_completed = false
		mission.bomb_delivery_failed = false
		mission.bomb_picked_up = false
		mission.bomb_car = nil
	elseif current == "alien_invasion" then
		-- Clean up mothership and alien minions
		if cleanup_mothership then cleanup_mothership() end
		if cleanup_alien_minions then cleanup_alien_minions() end
	end

	-- Start the checkpoint quest
	start_quest(checkpoint)

	printh("[DEATH] Quest reset complete, now on: " .. tostring(mission.current_quest))
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
		next_quest = "talk_to_companion_0"
	elseif mission.current_quest == "talk_to_companion_0" then
		next_quest = "a_prick"
	elseif mission.current_quest == "a_prick" then
		next_quest = "talk_to_companion_1"
	elseif mission.current_quest == "talk_to_companion_1" then
		next_quest = "fix_home"
	elseif mission.current_quest == "fix_home" then
		next_quest = "talk_to_companion_2"
	elseif mission.current_quest == "talk_to_companion_2" then
		next_quest = "beyond_the_sea"
	elseif mission.current_quest == "beyond_the_sea" then
		next_quest = "talk_to_companion_3"
	elseif mission.current_quest == "talk_to_companion_3" then
		next_quest = "mega_race"
	elseif mission.current_quest == "mega_race" then
		-- Clean up race
		cleanup_race()
		next_quest = "talk_to_companion_4"
	elseif mission.current_quest == "talk_to_companion_4" then
		next_quest = "car_wrecker"
	elseif mission.current_quest == "car_wrecker" then
		next_quest = "talk_to_companion_5"
	elseif mission.current_quest == "talk_to_companion_5" then
		next_quest = "auditor_kathy"
	elseif mission.current_quest == "auditor_kathy" then
		-- Clean up Kathy boss
		cleanup_kathy()
		next_quest = "talk_to_companion_6"
	elseif mission.current_quest == "talk_to_companion_6" then
		next_quest = "speed_dating"
	elseif mission.current_quest == "speed_dating" then
		next_quest = "talk_to_companion_7"
	elseif mission.current_quest == "talk_to_companion_7" then
		next_quest = "bomb_delivery"
	elseif mission.current_quest == "bomb_delivery" then
		next_quest = "talk_to_companion_8"
	elseif mission.current_quest == "talk_to_companion_8" then
		next_quest = "alien_invasion"
	elseif mission.current_quest == "alien_invasion" then
		-- Clean up mothership and minions
		cleanup_mothership()
		cleanup_alien_minions()
		-- Game complete! No more quests after alien invasion
		printh("All quests complete! Game finished!")
		mission.current_quest = nil
		mission.game_complete = true
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

		-- Add attack hint if player has a weapon but foxes remain
		if mission.has_weapon and living > 0 then
			add(objectives, "    [Z] to attack")
		end

	elseif mission.current_quest == "make_friends" then
		local new_fans = #fans - mission.fans_at_quest_start
		local status = (new_fans >= mission.new_fans_needed) and "[X]" or "[ ]"
		add(objectives, status .. " Make " .. mission.new_fans_needed .. " new fans (" .. new_fans .. "/" .. mission.new_fans_needed .. ")")

	elseif mission.current_quest == "find_love" then
		-- Just need a lover
		local lover_status = (#lovers > 0) and "[X]" or "[ ]"
		add(objectives, lover_status .. " Convince someone to date you")

	elseif mission.current_quest == "talk_to_companion_0" then
		local status = mission.talked_to_companion_0 and "[X]" or "[ ]"
		add(objectives, status .. " Talk to your companion about the monster")

	elseif mission.current_quest == "a_prick" then
		local status = mission.cactus_killed and "[X]" or "[ ]"
		add(objectives, status .. " Defeat the cactus monster")

	elseif mission.current_quest == "talk_to_companion_1" then
		local status = mission.talked_to_companion_1 and "[X]" or "[ ]"
		add(objectives, status .. " Talk to your companion")

	elseif mission.current_quest == "fix_home" then
		-- Objective 1: Get a hammer
		local hammer_status = mission.has_hammer and "[X]" or "[ ]"
		add(objectives, hammer_status .. " Obtain a hammer")
		-- Objective 2: Repair the building (progress shown in bar)
		local fix_cfg = QUEST_CONFIG.fix_home
		local repair_status = (mission.building_repair_progress >= fix_cfg.repair_hits_needed) and "[X]" or "[ ]"
		add(objectives, repair_status .. " Repair the damaged building")

	elseif mission.current_quest == "talk_to_companion_2" then
		local status = mission.talked_to_companion_2 and "[X]" or "[ ]"
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

	elseif mission.current_quest == "talk_to_companion_3" then
		local status = mission.talked_to_companion_3 and "[X]" or "[ ]"
		add(objectives, status .. " Talk to your companion")

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

	elseif mission.current_quest == "talk_to_companion_4" then
		local status = mission.talked_to_companion_4 and "[X]" or "[ ]"
		add(objectives, status .. " Talk to your companion")

	elseif mission.current_quest == "car_wrecker" then
		local cfg = QUEST_CONFIG.car_wrecker
		if mission.wrecker_completed then
			-- Completed successfully - show final status
			add(objectives, "[X] Wreck " .. cfg.cars_needed .. " cars (" .. mission.wrecker_cars_wrecked .. "/" .. cfg.cars_needed .. ")")
		elseif mission.wrecker_failed then
			-- Failed - need to talk to companion again
			add(objectives, "[X] Time's up! Talk to your companion to try again")
		elseif mission.wrecker_active then
			-- Active timer - show progress
			local status = (mission.wrecker_cars_wrecked >= cfg.cars_needed) and "[X]" or "[ ]"
			add(objectives, status .. " Wreck " .. cfg.cars_needed .. " cars (" .. mission.wrecker_cars_wrecked .. "/" .. cfg.cars_needed .. ")")
		else
			-- Before starting: tell player to steal a car
			add(objectives, "[ ] Steal a car and start wrecking!")
		end

	elseif mission.current_quest == "talk_to_companion_5" then
		local status = mission.talked_to_companion_5 and "[X]" or "[ ]"
		add(objectives, status .. " Talk to your companion")

	elseif mission.current_quest == "auditor_kathy" then
		-- Objective 1: Defeat Kathy
		local kathy_status = mission.kathy_killed and "[X]" or "[ ]"
		add(objectives, kathy_status .. " Defeat Auditor Kathy")
		-- Objective 2: Defeat her fox minions
		local fox_status = (mission.kathy_foxes_killed >= mission.total_kathy_foxes) and "[X]" or "[ ]"
		add(objectives, fox_status .. " Defeat fox minions (" .. mission.kathy_foxes_killed .. "/" .. mission.total_kathy_foxes .. ")")

	elseif mission.current_quest == "talk_to_companion_6" then
		local status = mission.talked_to_companion_6 and "[X]" or "[ ]"
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

	elseif mission.current_quest == "talk_to_companion_7" then
		local status = mission.talked_to_companion_7 and "[X]" or "[ ]"
		add(objectives, status .. " Talk to your companion")

	elseif mission.current_quest == "bomb_delivery" then
		local cfg = QUEST_CONFIG.bomb_delivery
		local total_cps = #mission.bomb_delivery_checkpoints
		local current_cp = mission.bomb_delivery_current_cp
		if not mission.bomb_delivery_active then
			-- Before starting: pick up bomb, then get in car
			if not mission.bomb_picked_up then
				add(objectives, "[ ] Pick up the bomb")
			else
				add(objectives, "[X] Pick up the bomb")
				add(objectives, "[ ] Get in the car")
			end
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

	elseif mission.current_quest == "talk_to_companion_8" then
		local status = mission.talked_to_companion_8 and "[X]" or "[ ]"
		add(objectives, status .. " Talk to your companion")

	elseif mission.current_quest == "alien_invasion" then
		if mission.mothership_killed then
			add(objectives, "[X] Defeat the Alien Mothership")
		else
			add(objectives, "[ ] Defeat the Alien Mothership")
			-- Show mothership health
			if mothership and mothership.state ~= "dead" then
				local health_pct = flr((mothership.health / mothership.max_health) * 100)
				add(objectives, "    Mothership Health: " .. health_pct .. "%")
			end
			-- Show minion count
			local minion_count = #alien_minions
			if minion_count > 0 then
				add(objectives, "    Alien Minions: " .. minion_count)
			end
		end

	end

	return objectives
end

-- Get world positions of current quest objectives for on-screen arrows
-- Returns a table of {x, y, color} for each active objective
function get_quest_target_positions()
	local targets = {}
	local cfg = OBJECTIVE_ARROW_CONFIG

	if not mission.current_quest then return targets end

	-- INTRO: Arms dealer location after meeting 5 people
	if mission.current_quest == "intro" then
		if mission.npcs_encountered >= 5 and not mission.talked_to_dealer then
			-- Point to nearest arms dealer
			if arms_dealers and #arms_dealers > 0 then
				local nearest = nil
				local nearest_dist = 99999
				for _, dealer in ipairs(arms_dealers) do
					local dx = dealer.x - game.player.x
					local dy = dealer.y - game.player.y
					local dist = sqrt(dx*dx + dy*dy)
					if dist < nearest_dist then
						nearest = dealer
						nearest_dist = dist
					end
				end
				if nearest then
					add(targets, {x = nearest.x, y = nearest.y, color = cfg.arrow_color})
				end
			end
		end

	-- PROTECT_CITY: Point to foxes
	elseif mission.current_quest == "protect_city" then
		-- Point to arms dealer if player needs a weapon
		if not mission.has_weapon then
			if arms_dealers and #arms_dealers > 0 then
				local nearest = nil
				local nearest_dist = 99999
				for _, dealer in ipairs(arms_dealers) do
					local dx = dealer.x - game.player.x
					local dy = dealer.y - game.player.y
					local dist = sqrt(dx*dx + dy*dy)
					if dist < nearest_dist then
						nearest = dealer
						nearest_dist = dist
					end
				end
				if nearest then
					add(targets, {x = nearest.x, y = nearest.y, color = cfg.arrow_color})
				end
			end
		else
			-- Point to living foxes
			if foxes then
				for _, fox in ipairs(foxes) do
					if fox.state ~= "dead" then
						add(targets, {x = fox.x, y = fox.y, color = 12})  -- red for enemies
					end
				end
			end
		end

	-- TALK_TO_COMPANION quests: Point to first lover
	elseif sub(mission.current_quest, 1, 18) == "talk_to_companion_" then
		if lovers and #lovers > 0 then
			local lover = lovers[1]
			if lover and lover.npc then
				add(targets, {x = lover.npc.x, y = lover.npc.y, color = 18})  -- salmon for lovers
			end
		end

	-- A_PRICK: Point to cactus boss
	elseif mission.current_quest == "a_prick" then
		if cactus and cactus.state ~= "dead" then
			add(targets, {x = cactus.x, y = cactus.y, color = 12})  -- red for boss
		end

	-- FIX_HOME: Point to damaged building
	elseif mission.current_quest == "fix_home" then
		if not mission.has_hammer then
			-- Point to arms dealer for hammer
			if arms_dealers and #arms_dealers > 0 then
				local nearest = nil
				local nearest_dist = 99999
				for _, dealer in ipairs(arms_dealers) do
					local dx = dealer.x - game.player.x
					local dy = dealer.y - game.player.y
					local dist = sqrt(dx*dx + dy*dy)
					if dist < nearest_dist then
						nearest = dealer
						nearest_dist = dist
					end
				end
				if nearest then
					add(targets, {x = nearest.x, y = nearest.y, color = cfg.arrow_color})
				end
			end
		elseif mission.damaged_building then
			-- Point to damaged building center
			local b = mission.damaged_building
			add(targets, {x = b.x + b.w/2, y = b.y + b.h/2, color = cfg.arrow_color})
		end

	-- BEYOND_THE_SEA: Package pickup, boat, or hermit
	elseif mission.current_quest == "beyond_the_sea" then
		if not mission.has_package and mission.package_location then
			add(targets, {x = mission.package_location.x, y = mission.package_location.y, color = cfg.arrow_color})
		elseif mission.has_package and not mission.delivered_package and mission.hermit_location then
			add(targets, {x = mission.hermit_location.x, y = mission.hermit_location.y, color = cfg.arrow_color})
		end

	-- MEGA_RACE: Point to next checkpoint
	elseif mission.current_quest == "mega_race" then
		if not mission.race_started and mission.race_checkpoints and #mission.race_checkpoints > 0 then
			-- Point to start line
			local start = mission.race_checkpoints[1]
			add(targets, {x = start.x, y = start.y, color = cfg.arrow_color})
		elseif mission.race_started and not mission.race_finished and mission.race_checkpoints then
			-- Point to current checkpoint
			local cp_idx = mission.player_checkpoint or 1
			if cp_idx <= #mission.race_checkpoints then
				local cp = mission.race_checkpoints[cp_idx]
				add(targets, {x = cp.x, y = cp.y, color = cfg.arrow_color})
			end
		end

	-- AUDITOR_KATHY: Point to Kathy and her foxes
	elseif mission.current_quest == "auditor_kathy" then
		if kathy and kathy.state ~= "dead" then
			add(targets, {x = kathy.x, y = kathy.y, color = 12})  -- red for boss
		end
		-- Point to kathy's fox minions
		if kathy_foxes then
			for _, fox in ipairs(kathy_foxes) do
				if fox.state ~= "dead" then
					add(targets, {x = fox.x, y = fox.y, color = 12})  -- red for enemies
				end
			end
		end

	-- BOMB_DELIVERY: Point to current checkpoint
	elseif mission.current_quest == "bomb_delivery" then
		if not mission.bomb_picked_up and mission.bomb_delivery_checkpoints and #mission.bomb_delivery_checkpoints > 0 then
			-- Point to bomb pickup
			local pickup = mission.bomb_delivery_checkpoints[1]
			add(targets, {x = pickup.x, y = pickup.y, color = cfg.arrow_color})
		elseif mission.bomb_delivery_active and not mission.bomb_delivery_completed and not mission.bomb_delivery_failed then
			-- Point to current checkpoint
			local cp_idx = mission.bomb_delivery_current_cp
			if mission.bomb_delivery_checkpoints and cp_idx and cp_idx <= #mission.bomb_delivery_checkpoints then
				local cp = mission.bomb_delivery_checkpoints[cp_idx]
				add(targets, {x = cp.x, y = cp.y, color = cfg.arrow_color})
			end
		end

	-- ALIEN_INVASION: Point to mothership
	elseif mission.current_quest == "alien_invasion" then
		if mothership and mothership.state ~= "dead" then
			add(targets, {x = mothership.x, y = mothership.y, color = 12})  -- red for boss
		end
	end

	return targets
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

	sfx(SFX.death_or_fail)  -- mission failure sound

	-- Show failure message briefly, then revert quest
	mission.wrecker_fail_timer = time() + 3  -- 3 seconds to show failure message
end

-- Check if we need to revert quest after failure (call from main update)
function update_car_wrecker_failure()
	if not mission.wrecker_fail_timer then return end

	if time() >= mission.wrecker_fail_timer then
		-- Revert to talk_to_companion_4
		mission.wrecker_fail_timer = nil
		mission.talked_to_companion_4 = false  -- Reset so player can accept again
		mission.current_quest = "talk_to_companion_4"
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

	sfx(SFX.death_or_fail)  -- mission failure sound

	-- Show failure message briefly, then revert quest
	mission.speed_dating_fail_timer = time() + 3  -- 3 seconds to show failure message
end

-- Check if we need to revert quest after failure (call from main update)
function update_speed_dating_failure()
	if not mission.speed_dating_fail_timer then return end

	if time() >= mission.speed_dating_fail_timer then
		-- Revert to talk_to_companion_6
		mission.speed_dating_fail_timer = nil
		mission.talked_to_companion_6 = false  -- Reset so player can accept again
		mission.current_quest = "talk_to_companion_6"
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

-- Check if player is in the bomb car
function is_in_bomb_car()
	return player_vehicle and mission.bomb_car and player_vehicle == mission.bomb_car
end

-- Check if player is near the bomb pickup location (first checkpoint)
function is_near_bomb_pickup()
	if not mission.bomb_delivery_checkpoints or #mission.bomb_delivery_checkpoints == 0 then
		return false
	end

	local pickup = mission.bomb_delivery_checkpoints[1]
	local px, py = game.player.x, game.player.y
	local dx = px - pickup.x
	local dy = py - pickup.y
	local dist = sqrt(dx * dx + dy * dy)

	-- Use same radius as checkpoint detection
	return dist < QUEST_CONFIG.bomb_delivery.checkpoint_radius
end

-- Spawn the bomb car (called when player picks up the bomb)
function spawn_bomb_car()
	if mission.bomb_car then return end  -- already spawned

	local pickup = mission.bomb_delivery_checkpoints[1]
	if not pickup then return end

	-- Spawn car slightly offset from pickup location
	local car_x = pickup.x + 30
	local car_y = pickup.y
	mission.bomb_car = create_vehicle(car_x, car_y, "sedan", "south")
	mission.bomb_car.is_bomb_car = true  -- mark it as the bomb car
	mission.bomb_car.is_parked = true    -- make it parked (no AI)
	add(vehicles, mission.bomb_car)
	printh("Spawned bomb car near pickup location: " .. car_x .. ", " .. car_y)
end

-- Check if player should pick up the bomb (call from main update)
-- Works like the Beyond The Sea package pickup - requires E key
function update_bomb_pickup()
	if mission.current_quest ~= "bomb_delivery" then return end
	if mission.bomb_picked_up then return end  -- already picked up
	if mission.bomb_delivery_active then return end  -- already started
	if not game or not game.player then return end

	-- Require E key press when near pickup (like hermit quest)
	local interact_pressed = keyp("e")
	if is_near_bomb_pickup() and not player_vehicle and interact_pressed then
		mission.bomb_picked_up = true
		spawn_bomb_car()
		printh("Bomb picked up! Get in the car!")
	end
end

-- Add bomb package to visible list for depth sorting (if not picked up)
-- Works like add_package_to_visible for beyond_the_sea quest
function add_bomb_package_to_visible(visible)
	if mission.current_quest ~= "bomb_delivery" then return end
	if mission.bomb_picked_up then return end  -- already picked up
	if not mission.bomb_delivery_checkpoints or #mission.bomb_delivery_checkpoints == 0 then return end

	local pickup = mission.bomb_delivery_checkpoints[1]
	local sx, sy = world_to_screen(pickup.x, pickup.y)

	-- Only add if on screen
	if sx > -32 and sx < SCREEN_W + 32 and sy > -32 and sy < SCREEN_H + 32 then
		-- Depth sort by bottom of 32x32 sprite (feet position = y + 16)
		local package_feet_y = pickup.y + 16
		add(visible, {
			type = "bomb_package",
			y = package_feet_y,
			cx = pickup.x,
			cy = pickup.y,
			sx = sx,
			sy = sy,
		})
	end
end

-- Draw bomb package sprite (called from building.lua during depth-sorted render)
function draw_bomb_package_sprite(sx, sy)
	-- Use same package sprite as beyond_the_sea
	local sprite_id = QUEST_CONFIG.beyond_the_sea.package_sprite
	spr(sprite_id, sx - 16, sy - 16, 2, 2)
end

-- Draw pickup prompt for bomb delivery quest
function draw_bomb_pickup_prompt()
	if mission.current_quest ~= "bomb_delivery" then return end
	if mission.bomb_picked_up then return end
	if not game or not game.player then return end
	if not mission.bomb_delivery_checkpoints or #mission.bomb_delivery_checkpoints == 0 then return end

	local p = game.player
	local pickup = mission.bomb_delivery_checkpoints[1]
	local dx = p.x - pickup.x
	local dy = p.y - pickup.y
	local dist = sqrt(dx * dx + dy * dy)

	-- Show prompt when near (same radius as checkpoint)
	if dist < QUEST_CONFIG.bomb_delivery.checkpoint_radius then
		local sx, sy = world_to_screen(pickup.x, pickup.y)
		print_shadow("E: Pick up bomb", sx - 30, sy - 20, 21)
	end
end

-- Start the bomb delivery timer (called when player enters the bomb car)
function start_bomb_delivery_timer()
	if mission.current_quest ~= "bomb_delivery" then return end
	if mission.bomb_delivery_active then return end  -- already started
	if mission.bomb_delivery_completed then return end  -- already completed

	-- Must be in the bomb car specifically
	if not is_in_bomb_car() then
		printh("Can't start bomb delivery - not in the bomb car!")
		return
	end

	mission.bomb_delivery_active = true
	mission.bomb_delivery_start_time = time()
	mission.bomb_delivery_hits = 0
	mission.bomb_delivery_failed = false
	-- Skip first checkpoint since we're starting from there
	mission.bomb_delivery_current_cp = 2
	printh("Bomb Delivery timer started! Deliver in " .. QUEST_CONFIG.bomb_delivery.time_limit .. " seconds, don't get hit more than " .. QUEST_CONFIG.bomb_delivery.max_hits .. " times!")
end

-- Track a hit on the bomb car (called when vehicle takes damage during quest)
-- Only counts if the damaged vehicle IS the bomb car
function track_bomb_delivery_hit(vehicle)
	if mission.current_quest ~= "bomb_delivery" then return false end
	if not mission.bomb_delivery_active then return false end
	if mission.bomb_delivery_completed or mission.bomb_delivery_failed then return false end

	-- Only track hits on the actual bomb car
	if not vehicle or not vehicle.is_bomb_car then return false end

	mission.bomb_delivery_hits = mission.bomb_delivery_hits + 1
	printh("Bomb car hit! " .. mission.bomb_delivery_hits .. "/" .. QUEST_CONFIG.bomb_delivery.max_hits)

	-- Check if car explodes (3 hits = KABOOM!)
	if mission.bomb_delivery_hits >= QUEST_CONFIG.bomb_delivery.max_hits then
		-- Explode the bomb car
		vehicle.health = 0
		vehicle.state = "exploding"
		vehicle.explosion_frame = 1
		vehicle.explosion_timer = time()

		-- Eject player from vehicle if inside
		if player_vehicle and player_vehicle == vehicle then
			player_vehicle.is_player_vehicle = false
			player_vehicle = nil
		end

		-- Kill the player (max damage)
		game.player.health = 0
		game.player.armor = 0

		-- Spawn explosion effects around the car
		local now = time()
		add(collision_effects, { x = vehicle.x, y = vehicle.y, end_time = now + 1.0, is_bomb_explosion = true })
		add(collision_effects, { x = vehicle.x - 20, y = vehicle.y - 15, end_time = now + 1.2, is_bomb_explosion = true, start_time = now + 0.1 })
		add(collision_effects, { x = vehicle.x + 20, y = vehicle.y + 15, end_time = now + 1.2, is_bomb_explosion = true, start_time = now + 0.2 })

		-- Fail the mission
		fail_bomb_delivery("KABOOM!")
		return true  -- Indicates car exploded
	end
	return false
end

-- Check if player reached current checkpoint (call from main update)
function update_bomb_delivery()
	if mission.current_quest ~= "bomb_delivery" then return end
	if not mission.bomb_delivery_active then return end
	if mission.bomb_delivery_completed or mission.bomb_delivery_failed then return end

	-- Must be in the bomb car specifically (not just any vehicle)
	if not is_in_bomb_car() then return end

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
			-- Final checkpoint - start countdown sequence!
			start_bomb_countdown()
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

-- Start the bomb countdown sequence (player reached final checkpoint)
function start_bomb_countdown()
	if mission.bomb_countdown_active then return end

	mission.bomb_countdown_active = true
	mission.bomb_countdown_start = time()
	mission.bomb_delivery_active = false  -- stop the delivery timer

	-- Find nearest building to target location for demolition
	local checkpoints = mission.bomb_delivery_checkpoints
	local final_cp = checkpoints[#checkpoints]
	mission.bomb_target_building = find_nearest_building(final_cp.x, final_cp.y)

	-- Eject player from the bomb car
	if player_vehicle and player_vehicle == mission.bomb_car then
		-- Force exit the vehicle
		local car = mission.bomb_car
		game.player.x = car.x + 40  -- Move player away from car
		game.player.y = car.y
		player_vehicle.is_player_vehicle = false
		player_vehicle = nil
		printh("Player ejected from bomb car! RUN!")
	end

	printh("Bomb countdown started! 10 seconds until explosion!")
end

-- Find nearest building to a position
function find_nearest_building(x, y)
	if not buildings then return nil end

	local closest = nil
	local closest_dist = 999999

	for _, b in ipairs(buildings) do
		local bx = b.x + b.w / 2
		local by = b.y + b.h / 2
		local dx = bx - x
		local dy = by - y
		local dist = sqrt(dx * dx + dy * dy)
		if dist < closest_dist then
			closest_dist = dist
			closest = b
		end
	end

	return closest
end

-- Update bomb countdown (call from main update)
function update_bomb_countdown()
	if mission.current_quest ~= "bomb_delivery" then return end
	if not mission.bomb_countdown_active then return end
	if mission.bomb_exploded then return end

	local elapsed = time() - mission.bomb_countdown_start

	-- Check if countdown finished
	if elapsed >= mission.bomb_countdown_duration then
		trigger_bomb_explosion()
	end
end

-- Get remaining countdown time
function get_bomb_countdown_remaining()
	if not mission.bomb_countdown_active then return nil end
	if mission.bomb_exploded then return nil end

	local elapsed = time() - mission.bomb_countdown_start
	return max(0, mission.bomb_countdown_duration - elapsed)
end

-- Trigger the bomb explosion
function trigger_bomb_explosion()
	if mission.bomb_exploded then return end
	mission.bomb_exploded = true

	printh("KABOOM! Bomb exploded!")

	local checkpoints = mission.bomb_delivery_checkpoints
	local final_cp = checkpoints[#checkpoints]
	local explosion_x = final_cp.x
	local explosion_y = final_cp.y

	-- Explode the bomb car
	if mission.bomb_car then
		mission.bomb_car.health = 0
		mission.bomb_car.state = "exploding"
		mission.bomb_car.explosion_frame = 1
		mission.bomb_car.explosion_timer = time()
	end

	-- Spawn multiple explosions around the building
	local b = mission.bomb_target_building
	if b then
		spawn_bomb_explosions_around_building(b)
	else
		-- Fallback to checkpoint explosions
		spawn_bomb_explosions(explosion_x, explosion_y)
	end

	-- Start building collapse animation (don't remove immediately)
	if mission.bomb_target_building then
		start_building_collapse(mission.bomb_target_building)
	end

	-- Mission complete after explosion
	mission.bomb_countdown_active = false
	mission.bomb_delivery_completed = true
	printh("Bomb delivery complete! Building collapsing!")
end

-- Spawn multiple explosion effects around the bomb site
function spawn_bomb_explosions(center_x, center_y)
	-- Create several explosion effects in a pattern
	local explosion_offsets = {
		{ x = 0, y = 0 },       -- center
		{ x = -30, y = -20 },   -- top-left
		{ x = 30, y = -20 },    -- top-right
		{ x = -30, y = 20 },    -- bottom-left
		{ x = 30, y = 20 },     -- bottom-right
		{ x = 0, y = -35 },     -- top
		{ x = 0, y = 35 },      -- bottom
		{ x = -40, y = 0 },     -- left
		{ x = 40, y = 0 },      -- right
	}

	-- Stagger explosions with slight delays (using collision_effects system)
	for i, offset in ipairs(explosion_offsets) do
		local ex = center_x + offset.x
		local ey = center_y + offset.y
		-- Stagger by 0.1 seconds each
		local delay = (i - 1) * 0.1
		add_delayed_explosion(ex, ey, delay)
	end
end

-- Add a delayed explosion effect
function add_delayed_explosion(x, y, delay)
	-- Use collision_effects system but with delayed start
	local effect = {
		x = x,
		y = y,
		start_time = time() + delay,
		end_time = time() + delay + 1.0,  -- longer duration for big explosions
		is_bomb_explosion = true,
	}
	add(collision_effects, effect)
end

-- Spawn many explosions around a building's perimeter and inside
function spawn_bomb_explosions_around_building(b)
	if not b then return end

	local cx = b.x + b.w / 2
	local cy = b.y + b.h / 2
	local half_w = b.w / 2
	local half_h = b.h / 2

	-- Create explosion grid covering the building
	local explosion_points = {}

	-- Center explosion
	add(explosion_points, { x = cx, y = cy })

	-- Corners
	add(explosion_points, { x = b.x, y = b.y })
	add(explosion_points, { x = b.x + b.w, y = b.y })
	add(explosion_points, { x = b.x, y = b.y + b.h })
	add(explosion_points, { x = b.x + b.w, y = b.y + b.h })

	-- Edge midpoints
	add(explosion_points, { x = cx, y = b.y })
	add(explosion_points, { x = cx, y = b.y + b.h })
	add(explosion_points, { x = b.x, y = cy })
	add(explosion_points, { x = b.x + b.w, y = cy })

	-- Extra explosions inside building
	add(explosion_points, { x = cx - half_w/2, y = cy - half_h/2 })
	add(explosion_points, { x = cx + half_w/2, y = cy - half_h/2 })
	add(explosion_points, { x = cx - half_w/2, y = cy + half_h/2 })
	add(explosion_points, { x = cx + half_w/2, y = cy + half_h/2 })

	-- Outer explosions (outside building perimeter)
	local outer_offset = 30
	add(explosion_points, { x = b.x - outer_offset, y = cy })
	add(explosion_points, { x = b.x + b.w + outer_offset, y = cy })
	add(explosion_points, { x = cx, y = b.y - outer_offset })
	add(explosion_points, { x = cx, y = b.y + b.h + outer_offset })

	-- Add random explosions for chaos
	for i = 1, 8 do
		local rx = b.x + rnd(b.w)
		local ry = b.y + rnd(b.h)
		add(explosion_points, { x = rx, y = ry })
	end

	-- Spawn all explosions with staggered delays
	for i, pt in ipairs(explosion_points) do
		local delay = (i - 1) * 0.08  -- faster stagger for more chaos
		add_delayed_explosion(pt.x, pt.y, delay)
	end
end

-- Building collapse state
collapsing_building = nil
collapse_start_time = nil
collapse_duration = 2.0  -- seconds to sink into ground

-- Start building collapse animation
function start_building_collapse(building)
	if not building then return end
	collapsing_building = building
	collapse_start_time = time()
	-- Mark building as collapsing (for rendering offset)
	building.collapsing = true
	building.collapse_offset = 0
end

-- Update building collapse animation
function update_building_collapse()
	if not collapsing_building then return end

	local elapsed = time() - collapse_start_time
	local progress = elapsed / collapse_duration

	if progress >= 1.0 then
		-- Collapse complete, remove building
		demolish_building(collapsing_building)
		collapsing_building = nil
		collapse_start_time = nil
	else
		-- Update collapse offset (building sinks down)
		-- Use easing: start slow, accelerate
		local ease_progress = progress * progress  -- quadratic ease-in
		collapsing_building.collapse_offset = ease_progress * 100  -- sink 100 pixels
	end
end

-- Demolish a building (remove it from the buildings list)
function demolish_building(building)
	if not building then return end

	-- Find and remove the building
	for i, b in ipairs(buildings) do
		if b == building then
			printh("Demolished building at " .. b.x .. ", " .. b.y)
			deli(buildings, i)
			break
		end
	end
end

-- Fail bomb delivery mission
function fail_bomb_delivery(reason)
	mission.bomb_delivery_failed = true
	mission.bomb_delivery_active = false
	mission.bomb_delivery_fail_reason = reason or "MISSION FAILED!"
	printh("Bomb Delivery failed: " .. mission.bomb_delivery_fail_reason)

	sfx(SFX.death_or_fail)  -- mission failure sound

	-- Show failure message briefly, then revert quest
	mission.bomb_delivery_fail_timer = time() + 3  -- 3 seconds to show failure message
end

-- Check if we need to revert quest after failure (call from main update)
function update_bomb_delivery_failure()
	if not mission.bomb_delivery_fail_timer then return end

	if time() >= mission.bomb_delivery_fail_timer then
		-- Revert to talk_to_companion_7
		mission.bomb_delivery_fail_timer = nil
		mission.talked_to_companion_7 = false  -- Reset so player can accept again
		mission.current_quest = "talk_to_companion_7"
		mission.quest_complete = false

		-- Reset bomb delivery state for retry
		mission.bomb_delivery_active = false
		mission.bomb_delivery_start_time = nil
		mission.bomb_delivery_hits = 0
		mission.bomb_delivery_completed = false
		mission.bomb_delivery_failed = false
		mission.bomb_delivery_current_cp = 1  -- Reset checkpoint progress
		mission.bomb_picked_up = false
		mission.bomb_car = nil
		-- Reset countdown state
		mission.bomb_countdown_active = false
		mission.bomb_countdown_start = nil
		mission.bomb_exploded = false
		mission.bomb_target_building = nil

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
	local total_secs = flr(remaining)
	local mins = flr(total_secs / 60)
	local secs = total_secs % 60

	-- Format as MM:SS (e.g., 1:30)
	local time_text = mins .. ":" .. (secs < 10 and "0" or "") .. secs
	local cp_text = "CP: " .. (current_cp - 1) .. "/" .. total_cps
	-- Show hits taken counting UP (e.g., 0/3, 1/3, 2/3)
	local hits_text = "HITS: " .. mission.bomb_delivery_hits .. "/" .. cfg.max_hits

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

	-- Draw timer (white, color 33)
	print_shadow(time_text, cx - time_w/2, y, 33)

	-- Draw checkpoint progress (gold/orange, color 21)
	print_shadow(cp_text, cx - cp_w/2, y + 12, 21)

	-- Draw hits remaining (red, color 12)
	print_shadow(hits_text, cx - hits_w/2, y + 24, 12)
end

-- Draw bomb countdown HUD (countdown number and flashing RUN text - no blocking background)
function draw_bomb_countdown_hud()
	if mission.current_quest ~= "bomb_delivery" then return end
	if not mission.bomb_countdown_active then return end
	if mission.bomb_exploded then return end

	local remaining = get_bomb_countdown_remaining()
	if not remaining then return end

	local secs = flr(remaining) + 1  -- Show 10, 9, 8... (ceiling)
	if secs > 10 then secs = 10 end
	if secs < 1 then secs = 1 end

	local cx = SCREEN_W / 2
	local cy = SCREEN_H / 2

	-- Draw large countdown number (no background box)
	local countdown_text = tostr(secs)
	local text_w = print(countdown_text, 0, -100)
	print_shadow(countdown_text, cx - text_w/2, cy - 4, 33)  -- white

	-- Draw "RUN!" text below - flashing between red (12) and orange (21)
	local run_text = "RUN!"
	local run_w = print(run_text, 0, -100)
	-- Flash rapidly between red and orange
	local flash = flr(time() * 8) % 2
	local run_color = (flash == 0) and 12 or 21  -- red (12) / orange (21)
	print_shadow(run_text, cx - run_w/2, cy + 20, run_color)

	-- Draw "GET AWAY FROM THE CAR!" above - also flashing
	local warn_text = "GET AWAY FROM THE CAR!"
	local warn_w = print(warn_text, 0, -100)
	local warn_color = (flash == 0) and 21 or 12  -- alternate with RUN text
	print_shadow(warn_text, cx - warn_w/2, cy - 30, warn_color)
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
	rectfill(x - 130, y - 25, x + 130, y + 45, 1)
	rect(x - 130, y - 25, x + 130, y + 45, 12)  -- bright red border

	-- Draw text centered with proper palette colors
	local tw1 = print(msg, 0, -100)
	local tw2 = print(msg2, 0, -100)

	-- KABOOM! gets special orange/yellow treatment, other failures get red
	local msg_color = 12  -- red (bright red from palette)
	if msg == "KABOOM!" then
		msg_color = 21  -- gold/orange for explosion
	end

	print_shadow(msg, x - tw1/2, y, msg_color)
	print_shadow(msg2, x - tw2/2, y + 14, 33)  -- white (color 33)
end

-- Add bomb delivery current checkpoint to visible list for depth sorting
function add_bomb_target_to_visible(visible)
	if mission.current_quest ~= "bomb_delivery" then return end
	if mission.bomb_delivery_completed or mission.bomb_delivery_failed then return end

	-- Before timer starts, don't show checkpoints (only show arrow on car)
	if not mission.bomb_delivery_active then return end

	local checkpoints = mission.bomb_delivery_checkpoints
	if not checkpoints or #checkpoints == 0 then return end

	local cp_idx = mission.bomb_delivery_current_cp
	if cp_idx > #checkpoints then return end

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
			is_final = (cp_idx == #checkpoints),
		})
	end
end

-- Draw red arrow above a target (bomb pickup or bomb car)
-- Always shows arrow pointing at bomb car when player is not in it
function draw_bomb_car_arrow()
	if mission.current_quest ~= "bomb_delivery" then return end
	if mission.bomb_delivery_completed or mission.bomb_delivery_failed then return end
	if mission.bomb_countdown_active then return end  -- don't show during countdown (player ejected, running away)

	local sx, sy
	local color = 12  -- red

	if not mission.bomb_picked_up then
		-- Show arrow over bomb pickup location (first checkpoint)
		if not mission.bomb_delivery_checkpoints or #mission.bomb_delivery_checkpoints == 0 then return end
		local pickup = mission.bomb_delivery_checkpoints[1]
		sx, sy = world_to_screen(pickup.x, pickup.y)
	else
		-- Show arrow over bomb car ONLY if player is not in it
		if not mission.bomb_car then return end
		-- Skip if player is already in the bomb car
		if is_in_bomb_car() then return end
		sx, sy = world_to_screen(mission.bomb_car.x, mission.bomb_car.y)
	end

	-- Only draw if on screen
	if sx < -50 or sx > SCREEN_W + 50 or sy < -50 or sy > SCREEN_H + 50 then return end

	-- Bobbing animation
	local bob = sin(time() * 3) * 4

	-- Draw red arrow pointing down
	local arrow_x = sx
	local arrow_top = sy - 48 + bob  -- top of stem
	local arrow_tip = sy - 24 + bob  -- tip of arrow (pointing down)

	-- Draw stem (vertical line)
	line(arrow_x, arrow_top, arrow_x, arrow_tip - 6, color)
	line(arrow_x - 1, arrow_top, arrow_x - 1, arrow_tip - 6, color)
	line(arrow_x + 1, arrow_top, arrow_x + 1, arrow_tip - 6, color)

	-- Draw arrow head pointing down (triangle using lines)
	-- Left edge of arrow head
	line(arrow_x - 6, arrow_tip - 8, arrow_x, arrow_tip, color)
	line(arrow_x - 5, arrow_tip - 8, arrow_x, arrow_tip - 1, color)
	-- Right edge of arrow head
	line(arrow_x + 6, arrow_tip - 8, arrow_x, arrow_tip, color)
	line(arrow_x + 5, arrow_tip - 8, arrow_x, arrow_tip - 1, color)
	-- Fill middle of arrow head
	line(arrow_x - 4, arrow_tip - 7, arrow_x + 4, arrow_tip - 7, color)
	line(arrow_x - 3, arrow_tip - 5, arrow_x + 3, arrow_tip - 5, color)
	line(arrow_x - 2, arrow_tip - 3, arrow_x + 2, arrow_tip - 3, color)
	line(arrow_x - 1, arrow_tip - 1, arrow_x + 1, arrow_tip - 1, color)
end

-- Draw bomb target as yellow circle (like racing checkpoints)
function draw_bomb_target_sprite(sx, sy, is_final)
	local radius = RACE_CONFIG.checkpoint_world_radius
	local color = RACE_CONFIG.checkpoint_active_color  -- bright yellow

	-- Pulsing effect (same as race checkpoints)
	local pulse = sin(time() * 4) * 4
	circ(sx, sy, radius + pulse, color)
	circ(sx, sy, radius + pulse - 2, color)

	-- Draw "FINAL" label for last checkpoint
	if is_final then
		print_shadow("FINAL", sx - 15, sy - radius - 16, 12)  -- red
	end
end

-- Draw bomb delivery markers on minimap (bomb pickup, bomb car, or checkpoints)
function draw_bomb_delivery_minimap(cfg, mx, my, half_mw, half_mh, px, py, tile_size, half_map_w, half_map_h)
	if mission.current_quest ~= "bomb_delivery" then return end
	if mission.bomb_delivery_completed or mission.bomb_delivery_failed then return end

	local blink = flr(time() * 4) % 2 == 0  -- Faster blink for urgency

	if not mission.bomb_delivery_active then
		-- Before timer starts
		local target_x, target_y

		if not mission.bomb_picked_up then
			-- Show bomb pickup location (first checkpoint)
			local checkpoints = mission.bomb_delivery_checkpoints
			if not checkpoints or #checkpoints == 0 then return end
			target_x = checkpoints[1].x
			target_y = checkpoints[1].y
		elseif mission.bomb_car then
			-- Show bomb car location
			target_x = mission.bomb_car.x
			target_y = mission.bomb_car.y
		else
			return
		end

		local marker_x = mx + (target_x / tile_size + half_map_w - px + half_mw)
		local marker_y = my + (target_y / tile_size + half_map_h - py + half_mh)
		-- Clamp to minimap bounds
		marker_x = max(cfg.x, min(cfg.x + cfg.width - 1, marker_x))
		marker_y = max(cfg.y, min(cfg.y + cfg.height - 1, marker_y))
		if blink then
			circfill(marker_x, marker_y, 2, 12)  -- Red marker
		end
	else
		-- After timer starts, show current checkpoint
		local checkpoints = mission.bomb_delivery_checkpoints
		if not checkpoints or #checkpoints == 0 then return end

		local cp_idx = mission.bomb_delivery_current_cp
		if cp_idx > #checkpoints then return end

		local target = checkpoints[cp_idx]
		local marker_x = mx + (target.x / tile_size + half_map_w - px + half_mw)
		local marker_y = my + (target.y / tile_size + half_map_h - py + half_mh)
		-- Clamp to minimap bounds
		marker_x = max(cfg.x, min(cfg.x + cfg.width - 1, marker_x))
		marker_y = max(cfg.y, min(cfg.y + cfg.height - 1, marker_y))
		if blink then
			local color = (cp_idx == #checkpoints) and 8 or 10  -- Red for final, yellow for intermediate
			circfill(marker_x, marker_y, 2, color)
		end
	end
end
