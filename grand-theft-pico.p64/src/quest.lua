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
		"talk_to_companion_4",  -- leads to more quests
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

	fix_home = {
		damaged_building_sprite = 129,  -- Cracked concrete sprite
		repair_hits_needed = 10,        -- Hammer hits to fully repair
	},

	beyond_the_sea = {
		-- Aseprite/sprite map coordinates (0,0 = top-left, 128,128 = world center)
		-- These get converted to world coords via sprite_map_to_world()
		package_sprite_x = 216,
		package_sprite_y = 116,
		package_sprite = 134,           -- Package sprite
		hermit_sprite_x = 37,
		hermit_sprite_y = 217,
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

	-- Talk to Companion checkpoints (between main quests)
	talked_to_companion_1 = false,  -- before fix_home
	talked_to_companion_2 = false,  -- before a_prick
	talked_to_companion_3 = false,  -- before beyond_the_sea
	talked_to_companion_4 = false,  -- before find_missions

	-- Quest 8: Find Missions
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
		printh("Started quest: Talk to Companion (before Find Missions)")

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

	elseif mission.current_quest == "find_missions" then
		local status = mission.talked_to_lover and "[X]" or "[ ]"
		add(objectives, status .. " Talk to a lover about their troubles")
	end

	return objectives
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

-- Draw package on ground (if not picked up)
function draw_package()
	if mission.current_quest ~= "beyond_the_sea" then return end
	if mission.has_package then return end
	if not mission.package_location then return end

	local pkg = mission.package_location
	local sx, sy = world_to_screen(pkg.x, pkg.y)

	-- Only draw if on screen
	if sx > -32 and sx < SCREEN_W + 32 and sy > -32 and sy < SCREEN_H + 32 then
		-- Draw shadow at bottom of 32x32 sprite
		fillp(0b0101101001011010)
		circfill(sx, sy + 12, 10, 0)
		fillp()

		-- Draw package sprite (32x32, centered)
		local sprite_id = QUEST_CONFIG.beyond_the_sea.package_sprite
		spr(sprite_id, sx - 16, sy - 16, 2, 2)
	end
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
