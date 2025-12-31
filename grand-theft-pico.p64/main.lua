--[[pod_format="raw"]]

-- Grand Theft Picotron
-- A top-down GTA1/2-style game for Picotron

-- ============================================
-- REQUIRE FUNCTION (for modules that return values)
-- ============================================
function require(name)
	if _modules == nil then
		_modules = {}
	end

	local already_imported = _modules[name]
	if already_imported ~= nil then
		return already_imported
	end

	local filename = fullpath(name .. '.lua')
	local src = fetch(filename)

	if type(src) ~= "string" then
		notify("could not include " .. filename)
		stop()
		return
	end

	local func, err = load(src, "@" .. filename, "t", _ENV)
	if not func then
		send_message(3, { event = "report_error", content = "*syntax error" })
		send_message(3, { event = "report_error", content = tostr(err) })
		stop()
		return
	end

	local module = func()
	_modules[name] = module

	return module
end

-- ============================================
-- INCLUDES (load modules)
-- ============================================
include("src/constants.lua")
include("src/config.lua")
include("src/utils.lua")
include("src/profiler.lua")
include("src/perspective.lua")
include("src/culling.lua")
include("src/wall_renderer.lua")
include("src/building.lua")
include("src/collision.lua")
include("src/ground.lua")
include("src/worldgen.lua")
include("src/flora.lua")
include("src/input.lua")
include("src/npc.lua")
include("src/vehicle.lua")
include("src/weapon.lua")
include("src/dealer.lua")
include("src/fox.lua")
include("src/cactus.lua")
include("src/kathy.lua")
include("src/mothership.lua")
include("src/alien_minion.lua")
include("src/quest.lua")
include("src/race.lua")
include("src/menu.lua")

-- Load input utilities module (for single-press detection)
input_utils = require("src/input_utils")

-- ============================================
-- PALETTE SETUP
-- ============================================
palette_loaded = false

function setup_palette()
	if not palette_loaded then
		-- Try loading palette from project folder
		local palette_data = fetch("toybox_palette.pal")

		if not palette_data then
			-- Try alternate path
			palette_data = fetch("/ram/cart/toybox_palette.pal")
			printh("Trying /ram/cart/toybox_palette.pal...")
		end

		if palette_data then
			printh("Palette loaded! Type: " .. type(palette_data))

			local color_count = 0
			-- Load all 64 colors from palette
			for i = 0, 63 do
				local color = palette_data[i]
				if color then
					color_count = color_count + 1
					-- Apply using pal() with p=2 to set RGB display palette
					pal(i, color, 2)
				end
			end

			-- Set color 0 as transparent for sprites
			palt(0, true)
			palette_loaded = true
			printh("SUCCESS: " .. color_count .. " colors loaded and applied!")
		else
			printh("WARNING: Could not load toybox_palette.pal from any path")
		end
	end
end

-- ============================================
-- GAME STATE (globals used by modules)
-- ============================================
cam_x, cam_y = 480, 480  -- camera world position (start centered on player)

game = {
	player = {
		x = 480,
		y = 480,
		facing_right = true,
		facing_dir = "east",  -- "north", "south", "east" (east/west use flip_x)
		walk_frame = 0,
		-- Combat/popularity system
		health = PLAYER_CONFIG.max_health,
		armor = 0,  -- starts with no armor, buy at shop
		popularity = PLAYER_CONFIG.starting_popularity,
		-- Money system
		money = PLAYER_CONFIG.starting_money,
		-- Weapon inventory
		weapons = {},         -- List of owned weapon keys (e.g., {"hammer", "pistol"})
		ammo = {},            -- Ammo counts by weapon key (e.g., {pistol = 30})
		equipped_index = 0,   -- 0 = no weapon, 1+ = index into weapons
		is_attacking = false,
		attack_timer = 0,
		attack_angle = 0,     -- For melee swing rotation
		fire_cooldown = 0,    -- Cooldown timer for ranged weapons
	}
}

-- Game stats tracking (lifetime stats for end-game display)
game_stats = {
	cars_wrecked = 0,
	boats_wrecked = 0,
	flirts_failed = 0,
	times_died = 0,
	npcs_met = 0,
	bullets_fired = 0,
}

-- List of NPCs that are fans/lovers (by NPC reference)
-- Fans: NPCs who recognized the player, won't flee, show heart
-- Lovers: Fans who filled love meter, always show heart, can heal
fans = {}  -- { npc = npc_ref, is_lover = false, love = 0, id = unique_id }
lovers = {}  -- separate list for quick lookup on minimap
next_fan_id = 1  -- global counter for unique fan IDs

-- Dialog system state
dialog = {
	active = false,
	npc = nil,           -- NPC we're talking to
	fan_data = nil,      -- fan data for the NPC
	options = {},        -- current dialog options
	selected = 1,        -- currently selected option
	phase = "choose",    -- "choose" = picking line, "result" = showing result
	result_text = "",    -- text to show after choosing
	result_timer = 0,    -- time until dialog closes
	close_cooldown = 0,  -- prevents weapon firing right after closing dialog
	mission_dialog = false, -- if true, wait for Z press instead of timer
}

-- NOTE: Quest system (mission, quest_complete_visual, and all quest functions)
-- has been moved to src/quest.lua

-- Popularity change display (shows +/- text near bar)
popularity_change = {
	amount = 0,         -- amount to display (+5 or -2 etc)
	end_time = 0,       -- when to stop showing
}

-- Helper function to change popularity and show feedback
function change_popularity(amount)
	-- Popularity can never drop below 1
	game.player.popularity = max(1, min(PLAYER_CONFIG.max_popularity, game.player.popularity + amount))
	popularity_change.amount = amount
	popularity_change.end_time = time() + PLAYER_CONFIG.popularity_text_duration
end

-- Remove fan/lover status from an NPC (called when they're hit)
function remove_fan_status(npc)
	-- Remove from lovers list
	for i = #lovers, 1, -1 do
		if lovers[i] == npc then
			deli(lovers, i)
			break
		end
	end

	-- Remove from fans list
	for i = #fans, 1, -1 do
		if fans[i].npc == npc then
			deli(fans, i)
			break
		end
	end
end

-- Player death state
player_dead = false  -- true = show death sprite
death_sequence_active = false  -- true = death animation is running (separate from player_dead)
death_timer = 0
death_fade = 0  -- 0-1 for fade effect
death_respawned = false  -- track if respawn already happened this death

-- Player hit flash state (show sprite 11 when hit)
player_hit_flash = 0  -- end time for hit flash
player_hit_sprite = 11  -- sprite to show when hit
player_death_sprite = 36  -- sprite to show when dead

-- Trigger player hit flash (call when player takes damage)
function trigger_player_hit_flash()
	player_hit_flash = time() + 0.15  -- show hit sprite for 0.15 seconds
end

-- Apply damage to player (armor absorbs first, then health)
function damage_player(amount)
	if amount <= 0 then return end

	local p = game.player

	-- Armor absorbs damage first
	if p.armor > 0 then
		if p.armor >= amount then
			-- Armor absorbs all damage
			p.armor = p.armor - amount
			amount = 0
		else
			-- Armor absorbs partial damage
			amount = amount - p.armor
			p.armor = 0
		end
	end

	-- Remaining damage hits health
	if amount > 0 then
		p.health = max(0, p.health - amount)
	end

	-- Trigger hit flash
	trigger_player_hit_flash()
end

-- Handle player death
function handle_player_death()
	if player_dead then return end

	printh("[DEATH] handle_player_death called, health=" .. game.player.health)
	player_dead = true
	death_sequence_active = true
	death_timer = time()
	death_fade = 0
	death_respawned = false  -- reset respawn flag for new death

	-- Track death stat
	if game_stats then
		game_stats.times_died = (game_stats.times_died or 0) + 1
	end

	printh("[DEATH] player_dead=true, death_sequence_active=true, death_timer=" .. death_timer)

	-- Lose half money
	game.player.money = flr(game.player.money / 2)

	-- No popularity loss from dying (player shouldn't be punished twice)

	-- Clear all lovers (romantic partners lost)
	lovers = {}
	for _, fan in ipairs(fans) do
		fan.is_lover = false
		fan.love = 0
	end

	-- Reset hostile dealers
	if arms_dealers then
		for _, dealer in ipairs(arms_dealers) do
			if dealer.state == "hostile" then
				dealer.state = "idle"
			end
		end
	end

	-- Close any open dialogs/shop
	if dialog then dialog.active = false end
	if shop then shop.active = false end

	-- Exit vehicle if in one
	if player_vehicle then
		player_vehicle.is_player_vehicle = false
		player_vehicle = nil
	end
end

-- Death sequence darken colors (similar to night transition)
death_darken_sequence = { 33, 30, 20, 25, 11, 1 }  -- progressively darker, ends at black
death_darken_index = 0

-- Update death sequence
-- Timeline: 0-1s show death sprite + text, 1-4s darken screen, 4-5s fade back in
function update_death()
	-- Check if player should die (only when not already in death sequence)
	if not death_sequence_active then
		if game.player.health <= 0 then
			printh("[DEATH] update_death: health<=0, calling handle_player_death")
			handle_player_death()
			death_darken_index = 0  -- reset darken index
		end
		return
	end

	local elapsed = time() - death_timer

	-- Phase 1 (0-1s): Show death sprite and "DEEP FRIED" text, no darkening yet
	if elapsed < 1 then
		death_fade = 0
		death_darken_index = 0
	-- Phase 2 (1-4s): Progressively darken screen using night-style transition
	elseif elapsed < 4 then
		-- Map elapsed 1-4 to darken index 1-6
		local progress = (elapsed - 1) / 3  -- 0 to 1
		death_darken_index = flr(progress * #death_darken_sequence) + 1
		death_darken_index = min(death_darken_index, #death_darken_sequence)
		death_fade = progress  -- for additional overlay if needed
	-- Phase 3 (4-5s): Hold at full dark, then respawn and fade back in
	elseif elapsed < 5 then
		death_fade = 1 - (elapsed - 4)  -- fade from 1 to 0
		death_darken_index = flr((1 - (elapsed - 4)) * #death_darken_sequence)
		-- Respawn player at start position (once, when entering phase 3)
		-- Use flag to ensure respawn only happens once
		if not death_respawned then
			printh("[RESPAWN] Phase 3: elapsed=" .. elapsed .. ", triggering respawn")
			death_respawned = true
			game.player.x = 0
			game.player.y = 0
			game.player.health = PLAYER_CONFIG.max_health
			cam_x = 0
			cam_y = 0
			camera_lead_x = 0  -- reset camera lead
			camera_lead_y = 0
			player_dead = false  -- show normal sprite during fade-in (but sequence still active)

			-- Clear all enemies and bullets immediately on respawn
			-- Mothership cleanup
			mothership = nil
			mothership_bullets = {}
			mothership_spawned = false
			mothership_spiral_active = false
			mothership_buildings_destroyed = false
			mothership_dying = false
			mothership_defeated_message_active = false
			epilogue_active = false  -- Also reset epilogue on death
			-- Alien minion cleanup
			alien_minions = {}
			alien_minion_bullets = {}
			last_minion_spawn_time = 0

			-- Reset quest to previous checkpoint (talk_to_companion)
			reset_quest_on_death()
			printh("[RESPAWN] Done: pos=(0,0), health=" .. game.player.health .. ", player_dead=false, sequence still active")
		end
	else
		-- Death sequence complete
		printh("[DEATH] Phase 4: elapsed=" .. elapsed .. ", death sequence complete")
		player_dead = false
		death_sequence_active = false
		death_fade = 0
		death_darken_index = 0
		death_respawned = false
	end
end

-- Draw death overlay using color table (like night mode transition)
function draw_death_overlay()
	if not death_sequence_active then return end

	local elapsed = time() - death_timer

	-- Draw darkening overlay using color table (same technique as night mode)
	if death_darken_index > 0 and death_darken_index <= #death_darken_sequence then
		local darken_color = death_darken_sequence[death_darken_index]
		-- Enable color table and draw full screen rect with darken color
		local coltab_sprite = get_spr(shadow_coltab_mode)
		memmap(0x8000, coltab_sprite)
		poke(0x550b, 0x3f)  -- enable color table
		rectfill(0, 0, SCREEN_W - 1, SCREEN_H - 1, darken_color)
		unmap(coltab_sprite)
		poke(0x550b, 0x00)  -- disable color table
	end

	-- Show "DEEP FRIED" text immediately and throughout most of death sequence
	if elapsed < 4 then
		local text = "DEEP FRIED"
		local tw = print(text, 0, -100)
		print_shadow(text, (SCREEN_W - tw) / 2, SCREEN_H / 2 - 8, 12)  -- red (color 12)

		-- Show what was lost
		local loss_text = "Lost money and popularity"
		local ltw = print(loss_text, 0, -100)
		print_shadow(loss_text, (SCREEN_W - ltw) / 2, SCREEN_H / 2 + 8, 6)
	end
end

-- Player shadow
SHADOW_RADIUS = 37
shadow_coltab_mode = 56  -- current color table sprite (cycles 56, 57, 58)

-- Night mode / Day-night cycle
night_mode = false
night_mask = nil  -- userdata for night overlay mask
street_lights_on = false  -- street lights only on at full night

-- Day-night cycle state
day_night_state = "day"  -- "day", "to_night", "night", "to_day"
day_night_transition_index = 0  -- current index in transition sequence
day_night_transition_timer = 0  -- frames until next step

-- In-game time tracking (24-minute cycle = 24 in-game hours)
-- Time is stored as hours (0-23.99) and advances at 1 hour per real minute
game_time_hours = 8  -- start at 8:00 AM
game_time_start = nil  -- real time() when game started

-- Buildings created from level data in config
buildings = {}

-- Nearby entity caches (computed once per frame for optimization)
-- Avoids iterating through full NPC/vehicle lists multiple times
nearby_fans = {}      -- { npc, fan_data, dist } for fans within interaction range
nearby_fan = nil      -- closest fan NPC reference (for quick access)
nearby_fan_data = nil -- closest fan's data

-- ============================================
-- MAIN CALLBACKS
-- ============================================

-- Rendering mode: "tline3d" (batched scanlines, fastest) or "tri" (batched textri)
render_mode = "tline3d"

-- Ground rendering mode: "scanline" (batched tline3d)
ground_mode = "scanline"

-- Draw with color table applied - pass a function to draw inside
function draw_with_colortable(color_table_sprite, draw_fn)
	local sprite = get_spr(color_table_sprite)
	memmap(0x8000, sprite)
	poke(0x550b, 0x3f)  -- enable color table for shapes
	draw_fn()  -- call the drawing function
	unmap(sprite)
	poke(0x550b, 0x00)  -- disable color table
end

-- Apply just one row of a color table
function apply_colortable_row(color_table_sprite, color_row)
	local sprite = get_spr(color_table_sprite)
	local address = 0x8000 + color_row * 64
	for x = 0, 63 do
		local c = sprite:get(x, color_row)
		poke(address + x, c)
	end
	poke(0x550b, 0x3f)  -- enable color table for shapes
end

-- Reset color table (disable it)
function reset_colortable()
	poke(0x550b, 0x00)
end

-- Check if current game time is during night hours (6 PM to 6 AM)
function is_night_time()
	local cfg = DAY_NIGHT_CYCLE_CONFIG
	local hour = game_time_hours
	-- Night is from night_start_hour (18) to night_end_hour (6)
	-- This wraps around midnight, so: hour >= 18 OR hour < 6
	return hour >= cfg.night_start_hour or hour < cfg.night_end_hour
end

-- Update game time (advances 1 in-game hour per real minute)
function update_game_time()
	-- Initialize start time if needed
	if not game_time_start then
		game_time_start = time()
		game_time_hours = DAY_NIGHT_CYCLE_CONFIG.start_hour
	end

	-- Calculate elapsed real seconds since start
	local elapsed = time() - game_time_start
	-- 1 real minute = 1 in-game hour, so 1 real second = 1/60 in-game hour
	local hours_elapsed = elapsed / 60
	-- Add to start hour and wrap at 24
	game_time_hours = (DAY_NIGHT_CYCLE_CONFIG.start_hour + hours_elapsed) % 24
end

-- Skip time by a certain number of hours (N key)
function skip_time(hours)
	-- Adjust the start time backwards to effectively skip forward
	-- Skipping 3 hours = subtracting 3 * 60 = 180 seconds from start time
	game_time_start = game_time_start - (hours * 60)
	printh("Skipped " .. hours .. " hours, now " .. get_time_string())
end

-- Get formatted time string (e.g., "8:00 AM")
function get_time_string()
	local hour = flr(game_time_hours)
	local minute = flr((game_time_hours - hour) * 60)
	local period = "AM"

	local display_hour = hour
	if hour >= 12 then
		period = "PM"
		if hour > 12 then display_hour = hour - 12 end
	end
	if hour == 0 then display_hour = 12 end

	-- Format minutes with leading zero
	local min_str = tostr(minute)
	if minute < 10 then min_str = "0" .. min_str end

	return tostr(display_hour) .. ":" .. min_str .. " " .. period
end

-- Update day-night cycle transitions
function update_day_night_cycle()
	-- First, update game time
	update_game_time()

	-- Check if we should be in night or day based on time
	local should_be_night = is_night_time()

	-- Handle automatic transitions based on game time
	if should_be_night and day_night_state == "day" then
		-- Start transition to night
		start_night_transition()
	elseif not should_be_night and day_night_state == "night" then
		-- Start transition to day
		start_day_transition()
	end

	-- Process ongoing transitions
	if day_night_state == "to_night" then
		-- Transitioning to night
		day_night_transition_timer = day_night_transition_timer - 1
		if day_night_transition_timer <= 0 then
			day_night_transition_index = day_night_transition_index + 1
			if day_night_transition_index > #NIGHT_CONFIG.day_to_night then
				-- Transition complete - now it's night
				day_night_state = "night"
				street_lights_on = true  -- turn on street lights
				printh("Night time! Street lights ON")
			else
				-- Apply next color in sequence
				NIGHT_CONFIG.darken_color = NIGHT_CONFIG.day_to_night[day_night_transition_index]
				day_night_transition_timer = NIGHT_CONFIG.transition_speed
			end
		end
	elseif day_night_state == "to_day" then
		-- Transitioning to day
		day_night_transition_timer = day_night_transition_timer - 1
		if day_night_transition_timer <= 0 then
			day_night_transition_index = day_night_transition_index + 1
			if day_night_transition_index > #NIGHT_CONFIG.night_to_day then
				-- Transition complete - now it's day
				day_night_state = "day"
				night_mode = false  -- disable overlay completely
				printh("Day time!")
			else
				-- Apply next color in sequence
				NIGHT_CONFIG.darken_color = NIGHT_CONFIG.night_to_day[day_night_transition_index]
				day_night_transition_timer = NIGHT_CONFIG.transition_speed
			end
		end
	end
end

-- Start transition to night
function start_night_transition()
	if day_night_state == "to_night" or day_night_state == "night" then return end
	day_night_state = "to_night"
	day_night_transition_index = 1
	day_night_transition_timer = NIGHT_CONFIG.transition_speed
	night_mode = true  -- enable overlay
	street_lights_on = false  -- lights off during transition
	NIGHT_CONFIG.darken_color = NIGHT_CONFIG.day_to_night[1]
	printh("Starting transition to night: " .. NIGHT_CONFIG.darken_color)
end

-- Start transition to day
function start_day_transition()
	if day_night_state == "to_day" or day_night_state == "day" then return end
	day_night_state = "to_day"
	day_night_transition_index = 1
	day_night_transition_timer = NIGHT_CONFIG.transition_speed
	street_lights_on = false  -- turn off street lights immediately
	NIGHT_CONFIG.darken_color = NIGHT_CONFIG.night_to_day[1]
	printh("Starting transition to day (lights OFF): " .. NIGHT_CONFIG.darken_color)
end

-- Skip time forward by configured hours (N key handler)
function handle_time_skip()
	skip_time(DAY_NIGHT_CYCLE_CONFIG.time_skip_hours)
end

-- Night mode settings (initialized from config in _init)

-- Check if a position is on any road surface (not sidewalk)
function is_on_any_road_surface(x, y)
	for _, road in ipairs(ROADS) do
		local half_road = road.width / 2
		if road.direction == "horizontal" then
			if y >= road.y - half_road and y <= road.y + half_road and
			   x >= road.x1 and x <= road.x2 then
				return true
			end
		elseif road.direction == "vertical" then
			if x >= road.x - half_road and x <= road.x + half_road and
			   y >= road.y1 and y <= road.y2 then
				return true
			end
		end
	end
	return false
end

-- ============================================
-- TRAFFIC LIGHT SYSTEM
-- ============================================
-- Global traffic state (all intersections sync)
-- Phases: "ns" = N-S green, "ns_yellow" = N-S yellow, "ew" = E-W green, "ew_yellow" = E-W yellow
traffic_phase = "ns"  -- current phase
traffic_timer = 0     -- time of last phase change

-- Check if a position is at an intersection (where two roads cross)
function is_at_intersection(x, y)
	local half_road = ROAD_CONFIG.road_width / 2
	local on_horizontal = false
	local on_vertical = false

	for _, road in ipairs(ROADS) do
		if road.direction == "horizontal" then
			if y >= road.y - half_road and y <= road.y + half_road and
			   x >= road.x1 and x <= road.x2 then
				on_horizontal = true
			end
		elseif road.direction == "vertical" then
			if x >= road.x - half_road and x <= road.x + half_road and
			   y >= road.y1 and y <= road.y2 then
				on_vertical = true
			end
		end
	end

	return on_horizontal and on_vertical
end

-- Get all intersection center points (where roads cross)
function get_intersections()
	local intersections = {}
	local half_road = ROAD_CONFIG.road_width / 2

	-- Find all horizontal roads
	local h_roads = {}
	local v_roads = {}
	for _, road in ipairs(ROADS) do
		if road.direction == "horizontal" then
			add(h_roads, road)
		elseif road.direction == "vertical" then
			add(v_roads, road)
		end
	end

	-- Check each horizontal/vertical pair for intersection
	for _, h_road in ipairs(h_roads) do
		for _, v_road in ipairs(v_roads) do
			-- Check if they actually cross
			local h_y = h_road.y
			local v_x = v_road.x

			-- Horizontal road spans x1 to x2, check if v_x is in range
			-- Vertical road spans y1 to y2, check if h_y is in range
			if v_x >= h_road.x1 and v_x <= h_road.x2 and
			   h_y >= v_road.y1 and h_y <= v_road.y2 then
				add(intersections, { x = v_x, y = h_y })
			end
		end
	end

	return intersections
end

-- Update traffic light phase
-- Cycle: ns (green) -> ns_yellow -> ew (green) -> ew_yellow -> ns ...
function update_traffic_lights()
	local now = time()
	local cycle_time = TRAFFIC_CONFIG.cycle_time
	local yellow_time = TRAFFIC_CONFIG.yellow_time

	local all_red_time = TRAFFIC_CONFIG.all_red_time

	if traffic_phase == "ns" then
		-- N-S is green, check if time for yellow
		if now >= traffic_timer + cycle_time then
			traffic_timer = now
			traffic_phase = "ns_yellow"
		end
	elseif traffic_phase == "ns_yellow" then
		-- N-S is yellow, check if time for all-red
		if now >= traffic_timer + yellow_time then
			traffic_timer = now
			traffic_phase = "all_red_ns_to_ew"
		end
	elseif traffic_phase == "all_red_ns_to_ew" then
		-- All red (after N-S), check if time to switch to E-W green
		if now >= traffic_timer + all_red_time then
			traffic_timer = now
			traffic_phase = "ew"
		end
	elseif traffic_phase == "ew" then
		-- E-W is green, check if time for yellow
		if now >= traffic_timer + cycle_time then
			traffic_timer = now
			traffic_phase = "ew_yellow"
		end
	elseif traffic_phase == "ew_yellow" then
		-- E-W is yellow, check if time for all-red
		if now >= traffic_timer + yellow_time then
			traffic_timer = now
			traffic_phase = "all_red_ew_to_ns"
		end
	elseif traffic_phase == "all_red_ew_to_ns" then
		-- All red (after E-W), check if time to switch to N-S green
		if now >= traffic_timer + all_red_time then
			traffic_timer = now
			traffic_phase = "ns"
		end
	end
end

-- Check if NPC can cross in given direction based on current traffic phase
function can_cross_in_direction(direction)
	-- "ns" phase = north/south traffic moves (vertical crossing allowed)
	-- "ew" phase = east/west traffic moves (horizontal crossing allowed)
	-- Yellow phases: don't start crossing (treat as red for new crossings)
	if traffic_phase == "ns" then
		return direction == "north" or direction == "south"
	elseif traffic_phase == "ew" then
		return direction == "east" or direction == "west"
	else
		-- Yellow phase - don't start new crossings
		return false
	end
end

-- Get the signal sprite for a light based on which direction it controls
-- ns_light = true means this light controls north-south traffic
-- N-S lights show GREEN when N-S phase (N-S traffic can go)
-- E-W lights show GREEN when E-W phase (E-W traffic can go)
-- All-red phases show RED for both directions (safety buffer between switches)
-- Sprite orientation is handled by flip_x/flip_y flags when drawing
function get_signal_sprite(ns_light, corner)
	local sprites

	-- All-red phases: both directions show red
	if traffic_phase == "all_red_ns_to_ew" or traffic_phase == "all_red_ew_to_ns" then
		if ns_light then
			return TRAFFIC_CONFIG.signal_sprites_ns.red
		else
			return TRAFFIC_CONFIG.signal_sprites_ew.red
		end
	end

	if ns_light then
		-- N-S traffic light uses N-S sprite set
		-- Shows GREEN when N-S phase (N-S traffic can go)
		-- Shows RED when E-W phase (E-W traffic has right of way)
		sprites = TRAFFIC_CONFIG.signal_sprites_ns
		if traffic_phase == "ns" then
			return sprites.green
		elseif traffic_phase == "ns_yellow" then
			return sprites.yellow
		else
			return sprites.red
		end
	else
		-- E-W traffic light uses E-W sprite set
		-- Shows GREEN when E-W phase (E-W traffic can go)
		-- Shows RED when N-S phase (N-S traffic has right of way)
		sprites = TRAFFIC_CONFIG.signal_sprites_ew
		if traffic_phase == "ew" then
			return sprites.green
		elseif traffic_phase == "ew_yellow" then
			return sprites.yellow
		else
			return sprites.red
		end
	end
end

-- Generate street lights at sidewalk corners
-- A sidewalk corner is where a sidewalk tile has exactly 2 adjacent sidewalk tiles
-- that form an L-shape (corner pattern)
-- Traffic lights are placed at these corners
function generate_street_lights()
	local lights = {}
	local light_set = {}  -- track unique positions to avoid duplicates
	local tile_size = MAP_CONFIG.tile_size
	local map_w = MAP_CONFIG.map_width
	local map_h = MAP_CONFIG.map_height
	local tiles = WORLD_DATA.tiles

	local function add_light(x, y, is_traffic_light, corner, flip_x, flip_y)
		local key = flr(x) .. "," .. flr(y)
		if not light_set[key] then
			light_set[key] = true
			add(lights, {
				x = x,
				y = y,
				is_traffic_light = is_traffic_light or false,
				corner = corner,  -- "nw", "ne", "sw", "se" for traffic lights
				flip_x = flip_x or false,
				flip_y = flip_y or false,
			})
		end
	end

	-- Helper to check if a tile is sidewalk
	local function is_sidewalk(mx, my)
		if mx < 0 or mx >= map_w or my < 0 or my >= map_h then
			return false
		end
		local tile = tiles:get(mx, my)
		return tile == MAP_TILE_SIDEWALK_NS or tile == MAP_TILE_SIDEWALK_EW
	end

	-- Scan all tiles for sidewalk corners
	for my = 0, map_h - 1 do
		for mx = 0, map_w - 1 do
			if is_sidewalk(mx, my) then
				-- Check adjacent tiles (N, S, E, W)
				local has_north = is_sidewalk(mx, my - 1)
				local has_south = is_sidewalk(mx, my + 1)
				local has_west = is_sidewalk(mx - 1, my)
				local has_east = is_sidewalk(mx + 1, my)

				-- Detect corner patterns (exactly 2 adjacent sidewalks forming an L)
				local corner = nil

				-- NW corner: has sidewalk to south AND east (L opens to SE)
				if has_south and has_east and not has_north and not has_west then
					corner = "nw"
				-- NE corner: has sidewalk to south AND west (L opens to SW)
				elseif has_south and has_west and not has_north and not has_east then
					corner = "ne"
				-- SW corner: has sidewalk to north AND east (L opens to NE)
				elseif has_north and has_east and not has_south and not has_west then
					corner = "sw"
				-- SE corner: has sidewalk to north AND west (L opens to NW)
				elseif has_north and has_west and not has_south and not has_east then
					corner = "se"
				end

				if corner then
					-- Convert map coords to world coords (center of tile)
					local wx, wy = map_to_world(mx, my)
					wx = wx + tile_size / 2
					wy = wy + tile_size / 2

					-- All sidewalk corners get traffic lights
					add_light(wx, wy, true, corner, false, false)
				end
			end
		end
	end

	printh("Generated " .. #lights .. " traffic lights at sidewalk corners")
	return lights
end

-- Street light positions (generated from roads)
STREET_LIGHTS = {}

-- Draw minimap using sprite 255 map directly
-- Coordinate system: world (0,0) = map center (128,128)
function draw_minimap()
	local cfg = MINIMAP_CONFIG
	if not cfg.enabled then return end

	local mx = cfg.x
	local my = cfg.y
	local mw = cfg.width
	local mh = cfg.height

	-- Get map sprite
	local map_spr = get_spr(MAP_CONFIG.sprite_id)
	local map_w = MAP_CONFIG.map_width
	local map_h = MAP_CONFIG.map_height
	local tile_size = MAP_CONFIG.tile_size
	local half_map_w = map_w / 2
	local half_map_h = map_h / 2

	-- Calculate player position in map coordinates (world 0,0 = map 128,128)
	local px = game.player.x / tile_size + half_map_w
	local py = game.player.y / tile_size + half_map_h

	-- Calculate visible region of map (centered on player)
	local half_mw = mw / 2
	local half_mh = mh / 2

	-- Draw border
	rectfill(mx - 1, my - 1, mx + mw + 1, my + mh + 1, cfg.border_color)

	-- Calculate source rectangle (clamp to map bounds)
	local src_x = flr(px - half_mw)
	local src_y = flr(py - half_mh)
	local src_w = mw
	local src_h = mh

	-- Calculate destination offset for clamping
	local dst_x = mx
	local dst_y = my

	-- Clamp left edge
	if src_x < 0 then
		dst_x = mx - src_x
		src_w = src_w + src_x
		src_x = 0
	end

	-- Clamp top edge
	if src_y < 0 then
		dst_y = my - src_y
		src_h = src_h + src_y
		src_y = 0
	end

	-- Clamp right edge
	if src_x + src_w > map_w then
		src_w = map_w - src_x
	end

	-- Clamp bottom edge
	if src_y + src_h > map_h then
		src_h = map_h - src_y
	end

	-- Clip to minimap area
	clip(mx, my, mw + 1, mh + 1)

	-- Fill background with water color (for areas outside map)
	rectfill(mx, my, mx + mw, my + mh, cfg.water_color)

	-- Draw the map sprite section (only if valid size)
	if src_w > 0 and src_h > 0 then
		sspr(map_spr, src_x, src_y, src_w, src_h, dst_x, dst_y)
	end

	-- Draw buildings on top (convert world coords to minimap coords)
	if cfg.show_buildings then
		for _, b in ipairs(buildings) do
			local bx1 = mx + (b.x / tile_size + half_map_w - px + half_mw)
			local by1 = my + (b.y / tile_size + half_map_h - py + half_mh)
			local bx2 = mx + ((b.x + b.w) / tile_size + half_map_w - px + half_mw)
			local by2 = my + ((b.y + b.h) / tile_size + half_map_h - py + half_mh)
			rectfill(bx1, by1, bx2, by2, cfg.building_color)
		end
	end

	-- Draw NPCs (and lovers in special color)
	if cfg.show_npcs or DEBUG_CONFIG.show_all_npcs then
		for _, npc in ipairs(npcs) do
			local nx = mx + (npc.x / tile_size + half_map_w - px + half_mw)
			local ny = my + (npc.y / tile_size + half_map_h - py + half_mh)
			if nx >= mx and nx <= mx + mw and ny >= my and ny <= my + mh then
				-- Check if this NPC is a lover (use special color)
				local color = cfg.npc_color
				if is_npc_lover(npc) then
					color = PLAYER_CONFIG.lover_map_color
				end
				pset(nx, ny, color)
			end
		end
	end

	-- Always draw lovers on minimap (even if NPCs are disabled)
	for _, lover_npc in ipairs(lovers) do
		local lx = mx + (lover_npc.x / tile_size + half_map_w - px + half_mw)
		local ly = my + (lover_npc.y / tile_size + half_map_h - py + half_mh)
		if lx >= mx and lx <= mx + mw and ly >= my and ly <= my + mh then
			pset(lx, ly, PLAYER_CONFIG.lover_map_color)
		end
	end

	-- Draw vehicles
	for _, vehicle in ipairs(vehicles) do
		if vehicle.state ~= "destroyed" then
			local is_boat = vehicle.vtype.water_only
			-- Check if this type should be shown (debug flag shows all)
			if DEBUG_CONFIG.show_all_vehicles or (is_boat and cfg.show_boats) or (not is_boat and cfg.show_vehicles) then
				local vx = mx + (vehicle.x / tile_size + half_map_w - px + half_mw)
				local vy = my + (vehicle.y / tile_size + half_map_h - py + half_mh)
				if vx >= mx and vx <= mx + mw and vy >= my and vy <= my + mh then
					local color = is_boat and cfg.boat_color or cfg.vehicle_color
					pset(vx, vy, color)
				end
			end
		end
	end

	-- Draw arms dealers (always visible on minimap)
	if arms_dealers then
		for _, dealer in ipairs(arms_dealers) do
			if dealer.state ~= "dead" then
				local dx = mx + (dealer.x / tile_size + half_map_w - px + half_mw)
				local dy = my + (dealer.y / tile_size + half_map_h - py + half_mh)
				-- Always draw dealers, even if off edge of minimap (clipped anyway)
				circfill(dx, dy, ARMS_DEALER_CONFIG.minimap_size, ARMS_DEALER_CONFIG.minimap_color)
			end
		end
	end

	-- Draw foxes on minimap (quest enemies - always visible, clamped to edge if far)
	if foxes_spawned and mission.current_quest == "protect_city" then
		for _, fox in ipairs(foxes) do
			if fox.state ~= "dead" then
				local fx = mx + (fox.x / tile_size + half_map_w - px + half_mw)
				local fy = my + (fox.y / tile_size + half_map_h - py + half_mh)

				-- Clamp fox position to minimap edge if outside bounds
				local margin = 2  -- keep a small margin from edge
				local clamped = false
				if fx < mx + margin then
					fx = mx + margin
					clamped = true
				elseif fx > mx + mw - margin then
					fx = mx + mw - margin
					clamped = true
				end
				if fy < my + margin then
					fy = my + margin
					clamped = true
				elseif fy > my + mh - margin then
					fy = my + mh - margin
					clamped = true
				end

				-- Draw fox marker (smaller if clamped/far away)
				local fox_color = FOX_CONFIG.minimap_color
				if clamped then
					-- Draw as blinking triangle pointing toward fox when clamped
					local blink = flr(time() * 3) % 2 == 0
					if blink then
						pset(fx, fy, fox_color)
					end
				else
					-- Draw normally when on screen
					circfill(fx, fy, FOX_CONFIG.minimap_size, fox_color)
				end
			end
		end
	end

	-- Draw cactus on minimap (quest enemy - always visible, clamped to edge if far)
	if cactus and cactus.state ~= "dead" and mission.current_quest == "a_prick" then
		local cx = mx + (cactus.x / tile_size + half_map_w - px + half_mw)
		local cy = my + (cactus.y / tile_size + half_map_h - py + half_mh)

		-- Clamp cactus position to minimap edge if outside bounds
		local margin = 2
		local clamped = false
		if cx < mx + margin then
			cx = mx + margin
			clamped = true
		elseif cx > mx + mw - margin then
			cx = mx + mw - margin
			clamped = true
		end
		if cy < my + margin then
			cy = my + margin
			clamped = true
		elseif cy > my + mh - margin then
			cy = my + mh - margin
			clamped = true
		end

		-- Draw cactus marker (larger for boss, blink if clamped)
		local cactus_color = CACTUS_CONFIG.minimap_color
		if clamped then
			local blink = flr(time() * 3) % 2 == 0
			if blink then
				circfill(cx, cy, 1, cactus_color)
			end
		else
			circfill(cx, cy, CACTUS_CONFIG.minimap_size, cactus_color)
		end
	end

	-- Draw Kathy boss on minimap (quest enemy - always visible, clamped to edge if far)
	if kathy and kathy.state ~= "dead" and mission.current_quest == "auditor_kathy" then
		local kx = mx + (kathy.x / tile_size + half_map_w - px + half_mw)
		local ky = my + (kathy.y / tile_size + half_map_h - py + half_mh)

		-- Clamp Kathy position to minimap edge if outside bounds
		local margin = 2
		local clamped = false
		if kx < mx + margin then
			kx = mx + margin
			clamped = true
		elseif kx > mx + mw - margin then
			kx = mx + mw - margin
			clamped = true
		end
		if ky < my + margin then
			ky = my + margin
			clamped = true
		elseif ky > my + mh - margin then
			ky = my + mh - margin
			clamped = true
		end

		-- Draw Kathy marker (larger for boss, blink if clamped)
		local kathy_color = KATHY_CONFIG.minimap_color
		if clamped then
			local blink = flr(time() * 3) % 2 == 0
			if blink then
				circfill(kx, ky, 1, kathy_color)
			end
		else
			circfill(kx, ky, KATHY_CONFIG.minimap_size, kathy_color)
		end
	end

	-- Draw Kathy's foxes on minimap
	if kathy_foxes_spawned and mission.current_quest == "auditor_kathy" then
		for _, fox in ipairs(kathy_foxes) do
			if fox.state ~= "dead" then
				local fx = mx + (fox.x / tile_size + half_map_w - px + half_mw)
				local fy = my + (fox.y / tile_size + half_map_h - py + half_mh)

				-- Clamp fox position to minimap edge if outside bounds
				local margin = 2
				local clamped = false
				if fx < mx + margin then
					fx = mx + margin
					clamped = true
				elseif fx > mx + mw - margin then
					fx = mx + mw - margin
					clamped = true
				end
				if fy < my + margin then
					fy = my + margin
					clamped = true
				elseif fy > my + mh - margin then
					fy = my + mh - margin
					clamped = true
				end

				-- Draw fox marker (smaller, blink if clamped)
				local fox_color = FOX_CONFIG.minimap_color
				if clamped then
					local blink = flr(time() * 3) % 2 == 0
					if blink then
						pset(fx, fy, fox_color)
					end
				else
					circfill(fx, fy, FOX_CONFIG.minimap_size, fox_color)
				end
			end
		end
	end

	-- Draw beyond the sea quest markers (package, hermit)
	draw_beyond_the_sea_minimap(cfg, mx, my, half_mw, half_mh, px, py, tile_size, half_map_w, half_map_h)

	-- Draw bomb delivery target marker
	draw_bomb_delivery_minimap(cfg, mx, my, half_mw, half_mh, px, py, tile_size, half_map_w, half_map_h)

	-- Draw damaged building marker (fix_home quest)
	if mission.current_quest == "fix_home" and mission.damaged_building then
		local b = mission.damaged_building
		local bx = mx + (b.x / tile_size + half_map_w - px + half_mw)
		local by = my + (b.y / tile_size + half_map_h - py + half_mh)
		-- Blink the marker
		local blink = flr(time() * 3) % 2 == 0
		if blink then
			circfill(bx, by, 2, 21)  -- Gold dot for damaged building
		end
	end

	-- Draw player (center of minimap)
	if cfg.show_player then
		local player_mx = mx + half_mw
		local player_my = my + half_mh
		circfill(player_mx, player_my, cfg.player_size, cfg.player_color)
	end

	-- Reset clip
	clip()
end

-- Pre-allocated userdata for batched circfill (x, y, r, color) x max lights on screen
-- Increased for double-sided sidewalk lights
local MAX_VISIBLE_LIGHTS = 64
local light_batch = userdata("f64", 4, MAX_VISIBLE_LIGHTS)

-- Draw night mode overlay - efficient method
-- Draw to night_mask userdata, then render as sprite with color table
function draw_night_mode(player_sx, player_sy)
	if not night_mode then return end

	-- Get config values
	local player_radius = NIGHT_CONFIG.player_light_radius
	local street_radius = NIGHT_CONFIG.street_light_radius
	local darken_color = NIGHT_CONFIG.darken_color
	local ambient_color = NIGHT_CONFIG.ambient_color

	-- First pass: draw ambient tint over everything (no holes)
	local coltab_sprite = get_spr(shadow_coltab_mode)
	memmap(0x8000, coltab_sprite)
	poke(0x550b, 0x3f)  -- enable color table
	rectfill(0, 0, SCREEN_W, SCREEN_H, ambient_color)
	unmap(coltab_sprite)
	poke(0x550b, 0x00)

	-- Second pass: draw darker areas with light holes
	-- Set draw target to night mask
	set_draw_target(night_mask)

	-- Fill with darken color
	cls(darken_color)

	-- Punch out light circles with transparent color (0)
	-- Player light follows player position
	circfill(player_sx, player_sy, player_radius, 0)

	-- Street lights (only when fully night) - batched circfill
	if street_lights_on then
		local light_count = 0
		local margin = street_radius

		-- Build batch of visible lights
		for _, light in ipairs(STREET_LIGHTS) do
			local sx, sy = world_to_screen(light.x, light.y)
			-- Only include if on screen (with margin for the radius)
			if sx > -margin and sx < SCREEN_W + margin and sy > -margin and sy < SCREEN_H + margin then
				if light_count < MAX_VISIBLE_LIGHTS then
					-- Pack into userdata: x, y, radius, color (row = light_count)
					local row = light_count * 4
					light_batch[row] = sx
					light_batch[row + 1] = sy
					light_batch[row + 2] = street_radius
					light_batch[row + 3] = 0  -- transparent color to punch holes
					light_count = light_count + 1
				end
			end
		end

		-- Draw all lights in one batched call
		if light_count > 0 then
			circfill(light_batch, 0, light_count)
		end
	end

	-- Enemy lights (foxes) - draw individual circles
	local enemy_radius = NIGHT_CONFIG.enemy_light_radius
	if foxes and foxes_spawned then
		for _, fox in ipairs(foxes) do
			if fox.state ~= "dead" then
				local sx, sy = world_to_screen(fox.x, fox.y)
				if sx > -enemy_radius and sx < SCREEN_W + enemy_radius and
				   sy > -enemy_radius and sy < SCREEN_H + enemy_radius then
					circfill(sx, sy, enemy_radius, 0)
				end
			end
		end
	end

	-- Cactus boss light
	if cactus and cactus.state ~= "dead" then
		local sx, sy = world_to_screen(cactus.x, cactus.y)
		if sx > -enemy_radius and sx < SCREEN_W + enemy_radius and
		   sy > -enemy_radius and sy < SCREEN_H + enemy_radius then
			circfill(sx, sy, enemy_radius + 5, 0)  -- slightly larger for boss
		end
	end

	-- Kathy (auditor boss) light
	if kathy and kathy.state ~= "dead" then
		local sx, sy = world_to_screen(kathy.x, kathy.y)
		if sx > -enemy_radius and sx < SCREEN_W + enemy_radius and
		   sy > -enemy_radius and sy < SCREEN_H + enemy_radius then
			circfill(sx, sy, enemy_radius + 5, 0)  -- slightly larger for boss
		end
	end

	-- Alien minion lights
	if alien_minions then
		for _, minion in ipairs(alien_minions) do
			if minion.state ~= "dead" then
				local sx, sy = world_to_screen(minion.x, minion.y)
				if sx > -enemy_radius and sx < SCREEN_W + enemy_radius and
				   sy > -enemy_radius and sy < SCREEN_H + enemy_radius then
					circfill(sx, sy, enemy_radius, 0)
				end
			end
		end
	end

	-- Mothership light (larger glow for big boss, follows visual position)
	if mothership and mothership.state ~= "dead" then
		local sx, sy = world_to_screen(mothership.x, mothership.y)
		-- Apply hover offset so light follows the visual sprite position
		sy = sy + MOTHERSHIP_CONFIG.hover_offset
		local boss_radius = enemy_radius + 20  -- much larger for mothership
		if sx > -boss_radius and sx < SCREEN_W + boss_radius and
		   sy > -boss_radius and sy < SCREEN_H + boss_radius then
			circfill(sx, sy, boss_radius, 0)
		end
	end

	-- Arms dealer lights
	local dealer_radius = NIGHT_CONFIG.dealer_light_radius
	if arms_dealers then
		for _, dealer in ipairs(arms_dealers) do
			if dealer.state ~= "dead" then
				local sx, sy = world_to_screen(dealer.x, dealer.y)
				if sx > -dealer_radius and sx < SCREEN_W + dealer_radius and
				   sy > -dealer_radius and sy < SCREEN_H + dealer_radius then
					circfill(sx, sy, dealer_radius, 0)
				end
			end
		end
	end

	-- Reset draw target to screen
	set_draw_target()

	-- Apply color table and draw the mask
	coltab_sprite = get_spr(shadow_coltab_mode)
	memmap(0x8000, coltab_sprite)
	poke(0x550b, 0x3f)  -- enable color table

	-- Ensure color 0 is transparent when drawing sprite
	palt(0, true)

	-- Draw mask as sprite (color 0 is transparent, darken color gets darkened)
	spr(night_mask, 0, 0)

	-- Reset color table and transparency
	palt(0, true)  -- keep 0 transparent (default)
	unmap(coltab_sprite)
	poke(0x550b, 0x00)
end

function _init()
	setup_palette()

	-- Hide mouse cursor
	window{ cursor = 0 }

	-- Create night mask sprite (screen-sized)
	night_mask = userdata("u8", SCREEN_W, SCREEN_H)

	-- Initialize menu state (game_state starts as "menu" from menu.lua)
	menu.phase = "title"
	menu.has_save = check_save_exists()
	menu.thruster_timer = time()

	printh("Grand Theft Chicken - Menu initialized!")
end

-- Initialize game world (called when starting/continuing game from menu)
function init_game_world()
	-- Initialize world from map sprite 255
	-- This parses the map, generates ROADS, COUNTRYSIDE_ROADS, and LEVEL_BUILDINGS
	init_world_from_map()

	-- Create buildings from generated level data
	buildings = create_buildings_from_level()

	-- Set player position at world center (0,0) which is map center (128,128)
	-- (unless loading a save, position is already set)
	if game.player.x == 0 and game.player.y == 0 then
		cam_x = 0
		cam_y = 0
	else
		cam_x = game.player.x
		cam_y = game.player.y
	end
	printh("Player at: " .. game.player.x .. ", " .. game.player.y)

	-- Generate street lights along roads
	STREET_LIGHTS = generate_street_lights()
	printh("Generated " .. #STREET_LIGHTS .. " street lights")

	-- Generate countryside flora
	generate_flora()

	-- Restore companions if loading a save (before spawning other NPCs)
	restore_companions()

	-- Calculate how many NPCs to spawn (subtract existing companions)
	local companion_count = #fans
	local target_npcs = NPC_CONFIG.update_mode == 2 and NPC_CONFIG.target_npc_count or NPC_CONFIG.spawn_count
	local npcs_to_spawn = max(0, target_npcs - companion_count)

	-- Spawn NPCs on roads
	if npcs_to_spawn > 0 then
		if NPC_CONFIG.update_mode == 2 then
			spawn_npcs(npcs_to_spawn, game.player.x, game.player.y)
		else
			spawn_npcs(npcs_to_spawn)
		end
	end

	-- Spawn vehicles on roads and boats on water
	spawn_vehicles()

	-- Spawn arms dealers
	spawn_arms_dealers()

	-- Debug weapons: give player all weapons with ammo
	if DEBUG_CONFIG.debug_weapons then
		local p = game.player
		p.weapons = {}
		p.ammo = {}
		for _, weapon_key in ipairs(WEAPON_CONFIG.weapon_order) do
			add(p.weapons, weapon_key)
			-- Give ammo for ranged weapons
			if WEAPON_CONFIG.ranged[weapon_key] then
				p.ammo[weapon_key] = 999
			end
		end
		p.equipped_index = 1  -- equip first weapon
		printh("Debug: gave player all weapons")
	end

	-- Start quest if not already set (new game)
	if not mission.current_quest then
		-- Debug: start at specific quest (or intro by default)
		local start_at = DEBUG_CONFIG.start_quest

		if start_at and start_at ~= "intro" then
			-- Mark fox quest flags so foxes don't spawn unexpectedly
			mission.fox_quest_offered = true
			mission.fox_quest_accepted = true
			foxes_spawned = true
			foxes = {}

			-- Just start the quest directly
			start_quest(start_at)
			printh("Debug: started at quest '" .. start_at .. "'")
		else
			-- Start with the intro quest (meet 5 people, then talk to dealer)
			start_quest("intro")
		end
	else
		printh("Resuming quest: " .. mission.current_quest)
	end

	-- Enable profiler (detailed=true, cpu=true)
	profile.enabled(true, true)

	printh("Grand Theft Chicken - World initialized!")
	printh("Loaded " .. #buildings .. " buildings")
end

function _update()
	-- Menu state - only update menu
	if game_state == "menu" then
		update_menu()
		return
	end

	-- Playing state - run game updates
	profile("input")
	handle_input()
	profile("input")

	-- Update water animation
	update_water_animation()

	-- Update traffic lights
	update_traffic_lights()

	-- Update NPCs (pass player position for scare behavior)
	profile("npcs_update")
	update_npcs(game.player.x, game.player.y)
	profile("npcs_update")

	-- Update vehicles
	profile("vehicles_update")
	update_vehicles()
	profile("vehicles_update")

	-- Update weapons and projectiles
	update_projectiles()
	update_beams()
	update_melee_attack()

	-- Update arms dealers
	update_arms_dealers()
	update_shop()
	check_dealer_interaction()

	-- Update foxes (if quest active)
	update_foxes()

	-- Update cactus boss (if quest active)
	update_cactus()
	update_cactus_bullets()

	-- Update Kathy boss (if quest active)
	update_kathy()
	update_kathy_bullets()
	update_kathy_foxes()

	-- Update Mothership boss and alien minions (if quest active)
	update_mothership()
	update_alien_minions()

	-- Update epilogue input (handles skip button presses)
	update_epilogue()

	-- If player is in a vehicle, sync player position to vehicle
	if player_vehicle then
		game.player.x = player_vehicle.x
		game.player.y = player_vehicle.y
	end

	-- Debug: cycle shadow color table with M key
	if DEBUG_CONFIG.enabled and keyp("m") then
		shadow_coltab_mode = shadow_coltab_mode + 1
		if shadow_coltab_mode > 59 then
			shadow_coltab_mode = 56
		end
		printh("Shadow color table: " .. shadow_coltab_mode)
	end

	-- Skip time forward with N key (adds 3 hours)
	if keyp("n") then
		handle_time_skip()
	end

	-- Update day-night cycle transitions
	update_day_night_cycle()

	-- Update nearby entity cache (once per frame)
	update_nearby_cache()

	-- Check for fan interaction and update dialog
	check_fan_interaction()
	update_dialog()

	-- Update death sequence (checks for player death, handles respawn)
	update_death()

	-- Update quest objectives
	update_quests()

	-- Update beyond the sea quest (package pickup/delivery)
	update_beyond_the_sea()

	-- Update race quest
	update_race()

	-- Update car wrecker quest timer
	update_car_wrecker()
	update_car_wrecker_failure()

	-- Update speed dating quest timer
	update_speed_dating()
	update_speed_dating_failure()

	-- Update bomb delivery quest
	update_bomb_pickup()  -- Check if player picks up bomb
	update_bomb_delivery()
	update_bomb_countdown()  -- Handle explosion countdown after reaching final checkpoint
	update_bomb_delivery_failure()
	update_building_collapse()  -- Animate building collapse after bomb explosion
end

-- Update quest system
function update_quests()
	-- Update quest completion visual (handles linger time and advancing)
	update_quest_complete_visual()

	if not mission.current_quest then return end

	-- Check quest completion periodically
	check_quest_completion()

	-- Quest advancement is now handled by update_quest_complete_visual after linger time
end

-- Update nearby entity cache (called once per frame)
-- This avoids iterating through full lists multiple times for interaction checks
-- Also refreshes heart show timer for nearby fans
function update_nearby_cache()
	local px, py = game.player.x, game.player.y
	local interact_range = PLAYER_CONFIG.fan_detect_distance * 2
	local now = time()
	local heart_duration = PLAYER_CONFIG.heart_show_duration

	-- Clear caches
	nearby_fans = {}
	nearby_fan = nil
	nearby_fan_data = nil

	-- Skip if in vehicle (can't interact with fans)
	if player_vehicle then return end

	-- Find all nearby fans and track the closest one
	local best_dist = interact_range
	for _, fan_data in ipairs(fans) do
		local npc = fan_data.npc
		-- Skip NPCs that are fleeing (e.g., after 3-strike failure)
		if npc.state == "fleeing" then
			-- Don't show heart or allow interaction with fleeing fans
		else
			local dx = npc.x - px
			local dy = npc.y - py
			local dist = sqrt(dx * dx + dy * dy)
			if dist < interact_range then
				add(nearby_fans, { npc = npc, fan_data = fan_data, dist = dist })
				-- Refresh heart show timer when player is nearby
				fan_data.heart_show_until = now + heart_duration
				if dist < best_dist then
					best_dist = dist
					nearby_fan = npc
					nearby_fan_data = fan_data
				end
			end
		end
	end
end

-- Print text with drop shadow for legibility
function print_shadow(text, x, y, col, shadow_col)
	shadow_col = shadow_col or 0  -- default black shadow
	print(text, x + 1, y + 1, shadow_col)
	print(text, x, y, col)
end

-- Draw player health bar
function draw_health_bar()
	local cfg = PLAYER_CONFIG
	local x = cfg.health_bar_x
	local y = cfg.health_bar_y
	local w = cfg.health_bar_width
	local h = cfg.health_bar_height

	-- Calculate health percentage
	local health_pct = game.player.health / cfg.max_health
	health_pct = max(0, min(1, health_pct))  -- clamp 0-1
	local fill_w = flr(w * health_pct)

	-- Draw label
	print_shadow("HP", x, y - 8, cfg.health_color)

	-- Draw border
	rect(x - 1, y - 1, x + w, y + h, cfg.health_border_color)
	-- Draw background
	rectfill(x, y, x + w - 1, y + h - 1, cfg.health_bg_color)
	-- Draw health fill
	if fill_w > 0 then
		rectfill(x, y, x + fill_w - 1, y + h - 1, cfg.health_color)
	end
end

-- Draw player armor bar (only shown if player has armor)
function draw_armor_bar()
	local cfg = PLAYER_CONFIG
	local p = game.player

	-- Only draw if player has armor
	if p.armor <= 0 then return end

	local x = cfg.armor_bar_x
	local y = cfg.armor_bar_y
	local w = cfg.armor_bar_width
	local h = cfg.armor_bar_height

	-- Calculate armor percentage
	local armor_pct = p.armor / cfg.max_armor
	armor_pct = max(0, min(1, armor_pct))  -- clamp 0-1
	local fill_w = flr(w * armor_pct)

	-- Draw label
	print_shadow("ARM", x, y - 8, cfg.armor_color)

	-- Draw border
	rect(x - 1, y - 1, x + w, y + h, cfg.armor_border_color)
	-- Draw background
	rectfill(x, y, x + w - 1, y + h - 1, cfg.armor_bg_color)
	-- Draw armor fill
	if fill_w > 0 then
		rectfill(x, y, x + fill_w - 1, y + h - 1, cfg.armor_color)
	end
end

-- Draw player popularity bar
function draw_popularity_bar()
	local cfg = PLAYER_CONFIG
	local x = cfg.popularity_bar_x
	local y = cfg.popularity_bar_y
	local w = cfg.popularity_bar_width
	local h = cfg.popularity_bar_height

	-- Calculate popularity percentage
	local pop_pct = game.player.popularity / cfg.max_popularity
	pop_pct = max(0, min(1, pop_pct))  -- clamp 0-1
	local fill_w = flr(w * pop_pct)

	-- Draw label
	print_shadow("POP", x, y - 8, cfg.popularity_color)

	-- Draw border
	rect(x - 1, y - 1, x + w, y + h, cfg.popularity_border_color)
	-- Draw background
	rectfill(x, y, x + w - 1, y + h - 1, cfg.popularity_bg_color)
	-- Draw popularity fill
	if fill_w > 0 then
		rectfill(x, y, x + fill_w - 1, y + h - 1, cfg.popularity_color)
	end

	-- Draw popularity change text in center of screen (if active)
	if time() < popularity_change.end_time then
		local amount = popularity_change.amount
		local text = (amount >= 0) and ("+" .. amount .. " POPULARITY") or (tostr(amount) .. " POPULARITY")
		local col = (amount >= 0) and cfg.popularity_gain_color or cfg.popularity_loss_color
		local text_w = print(text, 0, -100)
		print_shadow(text, SCREEN_CX - text_w / 2, SCREEN_CY - 20, col)
	end
end

-- Draw lover count under popularity bar
function draw_lover_count()
	local cfg = PLAYER_CONFIG
	local x = cfg.popularity_bar_x
	local y = cfg.popularity_bar_y + cfg.popularity_bar_height + 4  -- below popularity bar

	-- Draw heart icon and count
	local count = #lovers
	local heart_sprite = cfg.heart_sprite
	-- Draw small heart sprite (scaled down or just use spr)
	spr(heart_sprite, x, y - 2)
	-- Draw count next to heart
	print_shadow("x" .. count, x + 10, y, cfg.popularity_color)
end

-- Draw clock HUD (above minimap)
function draw_clock()
	local cfg = DAY_NIGHT_CYCLE_CONFIG
	local time_str = get_time_string()

	-- Draw time with shadow
	print_shadow(time_str, cfg.clock_x, cfg.clock_y, cfg.clock_color, cfg.clock_shadow_color)
end

-- Draw quest HUD (current objectives)
function draw_quest_hud()
	if not mission.current_quest then return end

	-- Position in top-right area, below weapon HUD
	local x = SCREEN_W - 180
	local y = 32
	local max_width = 175  -- max width for quest text area
	local max_chars = 38   -- approximate chars that fit in max_width

	-- Draw quest name
	local quest_name = get_quest_name(mission.current_quest)
	print_shadow(quest_name, x, y, 22)  -- yellow for quest title
	y = y + 10

	-- Draw objectives with word wrapping
	local objectives = get_quest_objectives()
	for _, obj in ipairs(objectives) do
		-- Check if complete (starts with [X])
		local color = 33  -- white default
		local display_obj = obj
		if sub(obj, 1, 3) == "[X]" then
			color = 19  -- green for complete
			-- If quest is complete, make the X blink
			if quest_complete_visual.active then
				local blink = flr(time() * 4) % 2 == 0
				if blink then
					-- Replace [X] with [ ] to create blink effect
					display_obj = "[ ]" .. sub(obj, 4)
				end
			end
		end

		-- Wrap long objectives
		local lines = wrap_text(display_obj, max_chars)
		for i, line in ipairs(lines) do
			-- Indent continuation lines
			if i > 1 then
				line = "    " .. line
			end
			print_shadow(line, x, y, color)
			y = y + 10
		end
	end
end

-- Draw big quest completed text in center of screen
function draw_quest_complete_banner()
	if not quest_complete_visual.active then return end

	local elapsed = time() - quest_complete_visual.start_time

	-- Blink the text for first 3 seconds, then stay solid
	local show_text = true
	if elapsed < 3 then
		show_text = flr(time() * 3) % 2 == 0
	end

	if show_text then
		local text = "QUEST COMPLETED"
		-- Get actual text width using print's return value (prints offscreen at y=-100)
		local text_width = print(text, 0, -100) - 0
		local cx = (SCREEN_W - text_width) / 2
		local cy = SCREEN_H / 2 - 20

		-- Draw with shadow for visibility
		-- Large text effect: draw each char scaled or use print with offset
		print_shadow(text, cx + 1, cy + 1, 1)   -- shadow
		print_shadow(text, cx, cy, 22)          -- yellow text

		-- Show completed quest name below
		local name = quest_complete_visual.completed_quest_name
		local name_width = print(name, 0, -100) - 0
		local nx = (SCREEN_W - name_width) / 2
		print_shadow(name, nx, cy + 14, 33)  -- white

		-- Show money reward below quest name (only if > 0)
		if quest_complete_visual.money_reward and quest_complete_visual.money_reward > 0 then
			local money_text = "+$" .. quest_complete_visual.money_reward
			local money_width = print(money_text, 0, -100) - 0
			local mx = (SCREEN_W - money_width) / 2
			print_shadow(money_text, mx, cy + 28, 11)  -- green
		end
	end
end

-- Draw player money display
function draw_money()
	local cfg = PLAYER_CONFIG
	local x = cfg.money_display_x
	local y = cfg.money_display_y
	-- Draw money as "$XXX" text in green
	print_shadow("$" .. game.player.money, x, y + 1, cfg.money_color)
end

-- Find the nearest fan/lover NPC within interaction range
-- Uses cached values computed in update_nearby_cache()
function find_nearby_fan()
	return nearby_fan, nearby_fan_data
end

-- Helper: shuffle an array in place
function shuffle_array(arr)
	for i = #arr, 2, -1 do
		local j = flr(rnd(i)) + 1
		arr[i], arr[j] = arr[j], arr[i]
	end
	return arr
end

-- Helper: pick random items from array (without replacement)
function pick_random_items(arr, count)
	local copy = {}
	for _, v in ipairs(arr) do add(copy, v) end
	shuffle_array(copy)
	local result = {}
	for i = 1, min(count, #copy) do
		add(result, copy[i])
	end
	return result
end

-- Start dialog with a fan
function start_dialog(npc, fan_data)
	dialog.active = true
	dialog.npc = npc
	dialog.fan_data = fan_data
	dialog.selected = 1
	dialog.phase = "choose"
	dialog.love_gained = 0  -- track love gained this dialog for display

	-- Stop the NPC from moving during dialog
	npc.in_dialog = true

	-- Initialize failure count if not set
	if not fan_data.failures then
		fan_data.failures = 0
	end

	-- Build options based on fan/lover status
	dialog.options = {}

	-- Check if this is the intro NPC
	local fan_id = fan_data.id or "?"
	printh("start_dialog: fan_id=" .. fan_id .. " is_intro_npc=" .. tostring(npc.is_intro_npc) .. " quest=" .. tostring(mission.current_quest) .. " failures=" .. tostring(fan_data.failures or 0))
	if npc.is_intro_npc and mission.current_quest == "intro" and not mission.talked_to_dealer then
		printh("Setting up intro dialog!")
		dialog.phase = "quest"
		dialog.quest_text = "Hey, you're new around here! Welcome to the city! If you want to survive, you should talk to an arms dealer first. Look for Doug or Bill - they sell weapons. Check your minimap for their location!"
		add(dialog.options, { text = "Thanks for the tip!", action = "accept_intro" })
		add(dialog.options, { text = "I'll figure it out myself.", action = "decline_intro" })
		return
	end

	-- Check if this is the quest giver NPC (5th fan with fox quest) - legacy support
	if npc.is_quest_giver and not mission.fox_quest_offered then
		dialog.phase = "quest"
		dialog.quest_text = "Help! Monsters have been spotted outside the city! Please protect us from the foxes! You should buy a weapon from Doug or Bill - they're arms dealers somewhere in the city."
		add(dialog.options, { text = "I'll help!", action = "accept_quest" })
		add(dialog.options, { text = "Not now...", action = "decline_quest" })
		return
	end

	if fan_data.is_lover then
		-- Lovers always have heal option
		add(dialog.options, { text = "Heal me!", action = "heal" })
		-- If on "Find Love" quest, add option to ask about troubles (triggers cactus quest)
		if mission.current_quest == "find_love" and not mission.lover_asked_troubles then
			add(dialog.options, { text = "What troubles you?", action = "ask_troubles_findlove" })
		end
		-- If on "Find Missions" quest, add option to talk about troubles
		if mission.current_quest == "find_missions" and not mission.talked_to_lover then
			add(dialog.options, { text = "What troubles you?", action = "ask_troubles" })
		end
		-- Talk to companion quests - offer mission with accept/decline
		if mission.current_quest == "talk_to_companion_1" and not mission.talked_to_companion_1 then
			add(dialog.options, { text = "What's new?", action = "offer_companion_1" })
		elseif mission.current_quest == "talk_to_companion_2" and not mission.talked_to_companion_2 then
			add(dialog.options, { text = "What's new?", action = "offer_companion_2" })
		elseif mission.current_quest == "talk_to_companion_3" and not mission.talked_to_companion_3 then
			add(dialog.options, { text = "What's new?", action = "offer_companion_3" })
		elseif mission.current_quest == "talk_to_companion_4" and not mission.talked_to_companion_4 then
			add(dialog.options, { text = "What's new?", action = "offer_companion_4" })
		elseif mission.current_quest == "talk_to_companion_5" and not mission.talked_to_companion_5 then
			add(dialog.options, { text = "What's new?", action = "offer_companion_5" })
		elseif mission.current_quest == "talk_to_companion_6" and not mission.talked_to_companion_6 then
			add(dialog.options, { text = "What's new?", action = "offer_companion_6" })
		elseif mission.current_quest == "talk_to_companion_7" and not mission.talked_to_companion_7 then
			add(dialog.options, { text = "What's new?", action = "offer_companion_7" })
		elseif mission.current_quest == "talk_to_companion_8" and not mission.talked_to_companion_8 then
			add(dialog.options, { text = "What's new?", action = "offer_companion_8" })
		elseif mission.current_quest == "talk_to_companion_9" and not mission.talked_to_companion_9 then
			add(dialog.options, { text = "What's new?", action = "offer_companion_9" })
		end
		-- Race replay option (available after completing mega_race once, only when no main quest active)
		-- Only show when current quest is find_missions (all main quests complete) or nil
		local can_race = mission.race_completed_once and
			(mission.current_quest == "find_missions" or mission.current_quest == nil)
		if can_race then
			add(dialog.options, { text = "Let's race again!", action = "start_race" })
		end
		-- Retry car wrecker if failed
		if mission.current_quest == "car_wrecker" and mission.wrecker_failed then
			add(dialog.options, { text = "Let me try wrecking cars again!", action = "retry_wrecker" })
		end
		-- Retry speed dating if failed
		if mission.current_quest == "speed_dating" and mission.speed_dating_failed then
			add(dialog.options, { text = "Let me try speed dating again!", action = "retry_speed_dating" })
		end
		-- Retry bomb delivery if failed
		if mission.current_quest == "bomb_delivery" and mission.bomb_delivery_failed then
			add(dialog.options, { text = "Let me try delivering again!", action = "retry_bomb_delivery" })
		end
		add(dialog.options, { text = "Nevermind", action = "cancel" })
	else
		-- Non-lovers get flirting options based on archetype
		local archetype = fan_data.archetype or "friendly"
		local all_options = PLAYER_CONFIG.dialog_options

		-- Get the archetype-matching options
		local matching_options = all_options[archetype] or all_options.friendly

		-- Get one random option from the matching archetype (guaranteed)
		local archetype_pick = matching_options[flr(rnd(#matching_options)) + 1]
		-- Mark it as matching the archetype
		archetype_pick = {
			text = archetype_pick.text,
			response = archetype_pick.response,
			love = archetype_pick.love,
			is_correct = true  -- this is the right choice
		}

		-- Build pool of options from OTHER archetypes
		local other_pool = {}
		for arch, opts in pairs(all_options) do
			if arch ~= archetype then
				for _, opt in ipairs(opts) do
					add(other_pool, {
						text = opt.text,
						response = opt.response,
						love = opt.love,
						is_correct = false  -- wrong archetype
					})
				end
			end
		end

		-- Pick 2 random options from other archetypes
		local other_picks = pick_random_items(other_pool, 2)

		-- Combine: archetype pick + other picks, then shuffle
		local final_options = { archetype_pick }
		for _, opt in ipairs(other_picks) do
			add(final_options, opt)
		end
		shuffle_array(final_options)

		-- Convert to dialog format
		for _, opt in ipairs(final_options) do
			add(dialog.options, {
				text = opt.text,
				action = "flirt",
				love = opt.love,
				response = opt.response,
				is_correct = opt.is_correct
			})
		end
	end
end

-- Handle dialog option selection
function select_dialog_option()
	local opt = dialog.options[dialog.selected]
	if not opt then return end

	if opt.action == "cancel" then
		-- Clear dialog flag on NPC
		if dialog.npc then dialog.npc.in_dialog = false end
		dialog.active = false
		return
	end

	-- Intro dialog actions
	if opt.action == "accept_intro" then
		dialog.phase = "result"
		dialog.result_text = "Good luck out there! The dealers are marked on your minimap."
		dialog.result_timer = time() + 1.5
		-- Mark intro NPC as done with intro dialog
		dialog.npc.is_intro_npc = false
		return
	end

	if opt.action == "decline_intro" then
		dialog.phase = "result"
		dialog.result_text = "Suit yourself! But seriously, get a weapon soon."
		dialog.result_timer = time() + 1.5
		dialog.npc.is_intro_npc = false
		return
	end

	-- Quest actions (legacy fox quest)
	if opt.action == "accept_quest" then
		mission.fox_quest_offered = true
		mission.fox_quest_accepted = true
		dialog.npc.is_quest_giver = false  -- no longer shows quest dialog
		dialog.phase = "result"
		dialog.result_text = "Thank you! Be careful out there!"
		dialog.result_timer = time() + 1.5
		-- Start the first quest and spawn foxes
		start_quest("protect_city")
		spawn_foxes()
		return
	end

	if opt.action == "decline_quest" then
		-- Player declined, but quest can be offered again later
		dialog.phase = "result"
		dialog.result_text = "Please reconsider... we need your help!"
		dialog.result_timer = time() + 1.5
		return
	end

	if opt.action == "heal" then
		-- Heal the player
		game.player.health = min(PLAYER_CONFIG.max_health, game.player.health + PLAYER_CONFIG.heal_amount)
		dialog.phase = "result"
		dialog.result_text = "You feel better! +" .. PLAYER_CONFIG.heal_amount .. " HP"
		dialog.result_timer = time() + 1.5
		return
	end

	if opt.action == "ask_troubles" then
		-- Complete the "Find Missions" quest objective
		mission.talked_to_lover = true
		dialog.phase = "result"
		dialog.result_text = "I've heard rumors of more monsters appearing... Come back after you've dealt with them and I'll tell you more!"
		dialog.mission_dialog = true
		dialog.result_start_time = time()
		return
	end

	if opt.action == "ask_troubles_findlove" then
		-- Complete the second objective of "Find Love" quest
		mission.lover_asked_troubles = true
		dialog.phase = "result"
		dialog.result_text = "A cactus monster is terrorizing downtown! Please help us!"
		dialog.mission_dialog = true
		dialog.result_start_time = time()
		return
	end

	-- Talk to companion quest actions - OFFER phase (shows mission description with accept/decline)
	if opt.action == "offer_companion_1" then
		dialog.phase = "quest"
		dialog.quest_text = "My home was damaged in the last attack! Can you help fix it? You'll need a hammer."
		dialog.options = {
			{ text = "I'll help!", action = "accept_companion_1" },
			{ text = "Not right now", action = "decline_companion" }
		}
		dialog.selected = 1
		return
	end

	if opt.action == "offer_companion_2" then
		dialog.phase = "quest"
		dialog.quest_text = "Thank you for fixing my home! But I heard there's a giant cactus monster downtown... Can you defeat it?"
		dialog.options = {
			{ text = "I'll take it down!", action = "accept_companion_2" },
			{ text = "Not right now", action = "decline_companion" }
		}
		dialog.selected = 1
		return
	end

	if opt.action == "offer_companion_3" then
		dialog.phase = "quest"
		dialog.quest_text = "A hermit on a nearby island needs a package delivered. Can you pick it up and bring it to him?"
		dialog.options = {
			{ text = "I'm on it!", action = "accept_companion_3" },
			{ text = "Not right now", action = "decline_companion" }
		}
		dialog.selected = 1
		return
	end

	if opt.action == "offer_companion_4" then
		dialog.phase = "quest"
		dialog.quest_text = "My ex is in the big street race today! I need you to beat them for me. Steal a car and get to the starting line!"
		dialog.options = {
			{ text = "Let's race!", action = "accept_companion_4" },
			{ text = "Not right now", action = "decline_companion" }
		}
		dialog.selected = 1
		return
	end

	if opt.action == "offer_companion_5" then
		dialog.phase = "quest"
		dialog.quest_text = "I work for a corrupt insurance company. We need you to wreck 12+ cars in 60 seconds! Steal a car and start smashing!"
		dialog.options = {
			{ text = "Time to wreck!", action = "accept_companion_5" },
			{ text = "Not right now", action = "decline_companion" }
		}
		dialog.selected = 1
		return
	end

	if opt.action == "offer_companion_6" then
		dialog.phase = "quest"
		dialog.quest_text = "An insurance auditor named Kathy is investigating all those wrecked cars! She's downtown with her agents. Take her out before she files her report!"
		dialog.options = {
			{ text = "I'll handle it!", action = "accept_companion_6" },
			{ text = "Not right now", action = "decline_companion" }
		}
		dialog.selected = 1
		return
	end

	if opt.action == "offer_companion_7" then
		dialog.phase = "quest"
		dialog.quest_text = "You're getting famous! A TV show wants you for their speed dating segment. Make 3 new lovers in 3 minutes to grow the polycule!"
		dialog.options = {
			{ text = "Love is in the air!", action = "accept_companion_7" },
			{ text = "Not right now", action = "decline_companion" }
		}
		dialog.selected = 1
		return
	end

	if opt.action == "offer_companion_8" then
		dialog.phase = "quest"
		dialog.quest_text = "Remember when I was a pizza delivery driver? A customer stiffed me on a tip. I need you to deliver a 'special package' to their house. Don't get hit more than 3 times or KABOOM!"
		dialog.options = {
			{ text = "Revenge is a dish best served... explosive!", action = "accept_companion_8" },
			{ text = "Not right now", action = "decline_companion" }
		}
		dialog.selected = 1
		return
	end

	if opt.action == "offer_companion_9" then
		dialog.phase = "quest"
		dialog.quest_text = "Look up! A massive alien mothership has appeared over the city! It's destroying buildings and spawning minions everywhere. You have to stop this invasion!"
		dialog.options = {
			{ text = "Time to save the world!", action = "accept_companion_9" },
			{ text = "Not right now", action = "decline_companion" }
		}
		dialog.selected = 1
		return
	end

	-- ACCEPT companion missions - these advance the quest
	if opt.action == "accept_companion_1" then
		mission.talked_to_companion_1 = true
		dialog.phase = "result"
		dialog.result_text = "Great! Find a hammer and fix the damaged building!"
		dialog.mission_dialog = true
		dialog.result_start_time = time()
		return
	end

	if opt.action == "accept_companion_2" then
		mission.talked_to_companion_2 = true
		dialog.phase = "result"
		dialog.result_text = "Be careful! That cactus is dangerous!"
		dialog.mission_dialog = true
		dialog.result_start_time = time()
		return
	end

	if opt.action == "accept_companion_3" then
		mission.talked_to_companion_3 = true
		dialog.phase = "result"
		dialog.result_text = "The package is on an island to the east. You'll need a boat!"
		dialog.mission_dialog = true
		dialog.result_start_time = time()
		return
	end

	if opt.action == "accept_companion_4" then
		mission.talked_to_companion_4 = true
		dialog.phase = "result"
		dialog.result_text = "Show them who's boss! Get to the starting line!"
		dialog.mission_dialog = true
		dialog.result_start_time = time()
		return
	end

	if opt.action == "accept_companion_5" then
		mission.talked_to_companion_5 = true
		dialog.phase = "result"
		dialog.result_text = "Wreck 12 cars in 60 seconds! Go go go!"
		dialog.mission_dialog = true
		dialog.result_start_time = time()
		return
	end

	if opt.action == "accept_companion_6" then
		mission.talked_to_companion_6 = true
		dialog.phase = "result"
		dialog.result_text = "Auditor Kathy is downtown with her fox agents. Stop her!"
		dialog.mission_dialog = true
		dialog.result_start_time = time()
		return
	end

	if opt.action == "accept_companion_7" then
		mission.talked_to_companion_7 = true
		dialog.phase = "result"
		dialog.result_text = "The cameras are rolling! Find 3 new lovers in 3 minutes!"
		dialog.mission_dialog = true
		dialog.result_start_time = time()
		-- Start the speed dating timer
		start_speed_dating_timer()
		return
	end

	if opt.action == "accept_companion_8" then
		mission.talked_to_companion_8 = true
		dialog.phase = "result"
		dialog.result_text = "The bomb is in the car! Steal one and deliver it fast!"
		dialog.mission_dialog = true
		dialog.result_start_time = time()
		return
	end

	if opt.action == "accept_companion_9" then
		mission.talked_to_companion_9 = true
		dialog.phase = "result"
		dialog.result_text = "The fate of the city rests on your shoulders! Destroy the mothership!"
		dialog.mission_dialog = true
		dialog.result_start_time = time()
		printh("DEBUG: accept_companion_9 triggered, mission.talked_to_companion_9 = " .. tostring(mission.talked_to_companion_9))
		return
	end

	-- DECLINE companion missions - does NOT advance the quest
	if opt.action == "decline_companion" then
		dialog.phase = "result"
		dialog.result_text = "Come back when you're ready!"
		dialog.result_timer = time() + 1.0
		return
	end

	-- Retry car wrecker mission (if failed)
	if opt.action == "retry_wrecker" then
		dialog.phase = "result"
		dialog.result_text = "Alright, let's try again! Steal a car and wreck 12 vehicles in 60 seconds!"
		dialog.mission_dialog = true
		dialog.result_start_time = time()
		retry_car_wrecker()
		return
	end

	-- Retry speed dating mission (if failed)
	if opt.action == "retry_speed_dating" then
		dialog.phase = "result"
		dialog.result_text = "The cameras are rolling again! Find 3 new lovers in 3 minutes!"
		dialog.mission_dialog = true
		dialog.result_start_time = time()
		-- Reset and start speed dating timer
		mission.speed_dating_active = false
		mission.speed_dating_start_time = nil
		mission.speed_dating_lovers_at_start = #lovers
		mission.speed_dating_new_lovers = 0
		mission.speed_dating_completed = false
		mission.speed_dating_failed = false
		start_speed_dating_timer()
		return
	end

	-- Retry bomb delivery mission (if failed)
	if opt.action == "retry_bomb_delivery" then
		dialog.phase = "result"
		dialog.result_text = "The bomb is armed again! Steal a car and deliver it fast!"
		dialog.mission_dialog = true
		dialog.result_start_time = time()
		-- Reset bomb delivery state
		mission.bomb_delivery_active = false
		mission.bomb_delivery_start_time = nil
		mission.bomb_delivery_hits = 0
		mission.bomb_delivery_completed = false
		mission.bomb_delivery_failed = false
		return
	end

	-- Start race replay (after completing mega_race once)
	if opt.action == "start_race" then
		dialog.phase = "result"
		dialog.result_text = "Another race? Let's do it! Get to the starting line!"
		dialog.mission_dialog = true
		dialog.result_start_time = time()
		-- Start the race without changing quest chain
		start_race_replay()
		return
	end

	-- Flirting action
	if opt.action == "flirt" then
		local fan_data = dialog.fan_data

		-- Check if this is the correct archetype choice
		if opt.is_correct then
			-- Success! Add love
			fan_data.love = fan_data.love + opt.love
			dialog.love_gained = opt.love

			-- Check if love meter is full (becomes a lover)
			if fan_data.love >= PLAYER_CONFIG.love_meter_max then
				fan_data.is_lover = true
				fan_data.love = PLAYER_CONFIG.love_meter_max
				-- Add to lovers list for minimap
				add(lovers, fan_data.npc)
				-- Track for speed dating quest
				track_speed_dating_lover()
				dialog.phase = "result"
				dialog.result_text = "They're smitten! New lover!"
			else
				-- Show NPC's response with love gain
				dialog.phase = "result"
				dialog.result_text = opt.response or "..."
			end
		else
			-- Wrong choice! Increment failure count
			fan_data.failures = (fan_data.failures or 0) + 1
			dialog.love_gained = 0
			local fan_id = fan_data.id or "?"
			printh("Flirt failed! fan_id=" .. fan_id .. " failures=" .. fan_data.failures .. " max=" .. PLAYER_CONFIG.max_failures)

			-- Track flirt failed stat
			if game_stats then
				game_stats.flirts_failed = (game_stats.flirts_failed or 0) + 1
			end

			-- Check if they've had enough (3 strikes)
			if fan_data.failures >= PLAYER_CONFIG.max_failures then
				printh("Fan ID=" .. fan_id .. " gave up! 3 strikes - removing and fleeing immediately")
				dialog.phase = "result"
				dialog.result_text = "I'm done with you!"
				dialog.result_timer = time() + 1.5
				dialog.fan_gave_up = true
				-- IMMEDIATELY remove from fans list to prevent re-interaction
				local removed = false
				for i, fd in ipairs(fans) do
					if fd.npc == dialog.npc then
						printh("Removing fan ID=" .. (fd.id or "?") .. " from fans list, fans count before=" .. #fans)
						deli(fans, i)
						removed = true
						printh("Removed! fans count after=" .. #fans)
						break
					end
				end
				if not removed then
					printh("WARNING: Fan not found in fans list!")
				end
				-- Start fleeing IMMEDIATELY
				dialog.npc.state = "fleeing"
				dialog.npc.state_end_time = time() + NPC_CONFIG.flee_duration
				dialog.npc.flee_dir = get_flee_direction(dialog.npc, game.player.x, game.player.y)
				dialog.npc.facing_dir = dialog.npc.flee_dir or dialog.npc.facing_dir
				-- Keep fan_checked = true so they can't immediately become a fan again
				-- They'll reset when they finish fleeing and move away
				dialog.npc.in_dialog = false  -- Let them move while fleeing
				dialog.npc.rejected_player = true  -- Mark as rejected so they can't become fan again soon
				-- Lose popularity for failing at flirting
				change_popularity(-PLAYER_CONFIG.popularity_loss_flirt_fail)
				return
			else
				-- Show a random failure response
				local responses = PLAYER_CONFIG.failure_responses
				local fail_response = responses[flr(rnd(#responses)) + 1]
				dialog.phase = "result"
				dialog.result_text = fail_response
			end
		end
		dialog.result_timer = time() + 1.5
		return
	end
end

-- Update dialog system
function update_dialog()
	if not dialog.active then return end

	if dialog.phase == "result" then
		-- Allow X to skip result phase (for non-mission dialogs only)
		if not dialog.mission_dialog and btnp(5) then
			if dialog.npc then dialog.npc.in_dialog = false end
			dialog.active = false
			dialog.mission_dialog = false
			dialog.close_cooldown = time() + 0.1
			return
		end

		-- For mission dialogs, wait for E press; for others, wait for timer
		local should_close = false
		if dialog.mission_dialog then
			-- Mission dialogs require E to continue (with small delay to avoid instant close)
			-- Use input_utils.key_pressed for proper single-press detection
			if dialog.result_start_time and time() > dialog.result_start_time + 0.2 then
				if input_utils.key_pressed("e") then
					should_close = true
				end
			end
		else
			-- Regular dialogs use timer
			if time() >= dialog.result_timer then
				should_close = true
			end
		end

		if should_close then
			-- Clear dialog flag on NPC so they can move again
			if dialog.npc then dialog.npc.in_dialog = false end

			-- Check if fan gave up (3 strikes) - already handled, just add cooldown
			if dialog.fan_gave_up then
				dialog.fan_gave_up = false
				-- Add cooldown to prevent immediately talking to another fan
				dialog.close_cooldown = time() + 0.5
			end

			dialog.active = false
			dialog.mission_dialog = false
		end
		return
	end

	-- Navigate options with up/down
	if btnp(2) then  -- up
		dialog.selected = dialog.selected - 1
		if dialog.selected < 1 then dialog.selected = #dialog.options end
	elseif btnp(3) then  -- down
		dialog.selected = dialog.selected + 1
		if dialog.selected > #dialog.options then dialog.selected = 1 end
	end

	-- Select with O/Z key or E key (use input_utils for E to share state with check_fan_interaction)
	if btnp(4) or input_utils.key_pressed("e") then
		select_dialog_option()
	end

	-- Cancel with X button
	if btnp(5) then
		if dialog.npc then dialog.npc.in_dialog = false end
		dialog.active = false
		dialog.close_cooldown = time() + 0.1  -- prevent weapon fire for 0.1s
	end
end

-- Wrap text to fit within max characters per line
-- Returns a table of lines
function wrap_text(text, max_chars)
	local lines = {}
	local current_line = ""

	-- Split text into words manually (avoid string.gmatch)
	local words = split(text, " ", false)
	for _, word in ipairs(words) do
		if #word > 0 then
			if #current_line == 0 then
				current_line = word
			elseif #current_line + 1 + #word <= max_chars then
				current_line = current_line .. " " .. word
			else
				add(lines, current_line)
				current_line = word
			end
		end
	end

	-- Add remaining line
	if #current_line > 0 then
		add(lines, current_line)
	end

	return lines
end

-- Draw dialog box
function draw_dialog()
	if not dialog.active then return end

	local cfg = PLAYER_CONFIG
	local w = cfg.dialog_width
	local max_chars = cfg.dialog_max_chars_per_line
	local line_h = cfg.dialog_line_height
	local x = (SCREEN_W - w) / 2

	-- Calculate height based on content
	local content_height = 0
	local wrapped_options = {}  -- cache wrapped text for options

	if dialog.phase == "result" then
		-- Result phase: wrap result text
		local result_lines = wrap_text(dialog.result_text, max_chars)
		content_height = #result_lines * line_h + 20  -- padding
		if dialog.love_gained and dialog.love_gained > 0 then
			content_height = content_height + 14  -- extra line for love gain
		end
	elseif dialog.phase == "quest" then
		-- Quest phase: show quest text + options
		local quest_lines = wrap_text(dialog.quest_text or "", max_chars)
		content_height = #quest_lines * line_h + 16  -- quest text + spacing
		-- Add height for options
		for i, opt in ipairs(dialog.options) do
			local prefix = (i == dialog.selected) and "> " or "  "
			local text = prefix .. opt.text
			local lines = wrap_text(text, max_chars)
			wrapped_options[i] = lines
			content_height = content_height + #lines * line_h + 4
		end
		content_height = content_height + 12  -- extra padding
	else
		-- Choose phase: calculate height for all options with wrapping
		for i, opt in ipairs(dialog.options) do
			local prefix = (i == dialog.selected) and "> " or "  "
			local text = prefix .. opt.text
			local lines = wrap_text(text, max_chars)
			wrapped_options[i] = lines
			content_height = content_height + #lines * line_h + 4  -- 4px gap between options
		end
		content_height = content_height + 22  -- padding for love bar area
	end

	-- Add space for love bar if showing (not during quest phase)
	if dialog.fan_data and not dialog.fan_data.is_lover and dialog.phase ~= "quest" then
		content_height = content_height + 16
	end

	local h = max(cfg.dialog_height, content_height)
	local y = SCREEN_H - h - 20  -- above bottom of screen

	-- Draw box
	rectfill(x, y, x + w, y + h, cfg.dialog_bg_color)
	rect(x, y, x + w, y + h, cfg.dialog_border_color)

	-- Show love meter at the top if flirting (not a lover yet, not quest phase)
	local content_start_y = y + 8
	if dialog.fan_data and not dialog.fan_data.is_lover and dialog.phase ~= "quest" then
		local love_pct = dialog.fan_data.love / cfg.love_meter_max
		local bar_w = w - 16
		local bar_x = x + 8
		local bar_y = y + 4
		-- Background
		rectfill(bar_x, bar_y, bar_x + bar_w, bar_y + 6, 1)
		-- Fill
		if love_pct > 0 then
			rectfill(bar_x, bar_y, bar_x + bar_w * love_pct, bar_y + 6, 14)
		end
		-- Border
		rect(bar_x - 1, bar_y - 1, bar_x + bar_w + 1, bar_y + 7, 6)
		-- Label
		print_shadow("LOVE", bar_x, bar_y - 8, 14)

		-- Show failure count if any
		if dialog.fan_data.failures and dialog.fan_data.failures > 0 then
			local strikes = dialog.fan_data.failures .. "/" .. cfg.max_failures
			print_shadow(strikes, bar_x + bar_w - 16, bar_y - 8, 8)  -- red color for strikes
		end
		content_start_y = bar_y + 14
	end

	if dialog.phase == "result" then
		-- Show result text with wrapping, centered
		local result_lines = wrap_text(dialog.result_text, max_chars)
		local total_text_height = #result_lines * line_h
		local result_y = y + (h - total_text_height) / 2

		for _, line in ipairs(result_lines) do
			local tw = print(line, 0, -100)  -- measure text width properly
			print(line, x + (w - tw) / 2, result_y, cfg.dialog_text_color)
			result_y = result_y + line_h
		end

		-- Show love gain text below result (if gained love)
		if dialog.love_gained and dialog.love_gained > 0 then
			local love_text = "+" .. dialog.love_gained .. " love"
			local ltw = print(love_text, 0, -100)  -- measure text width properly
			print(love_text, x + (w - ltw) / 2, result_y + 4, cfg.love_gain_color)
		end

		-- Show "E to continue" for mission dialogs (bottom left)
		if dialog.mission_dialog then
			local continue_text = "[E] Continue"
			print_shadow(continue_text, x + 6, y + h - 10, 22)  -- yellow
		end
	elseif dialog.phase == "quest" then
		-- Show quest text first, then options below
		local oy = y + 8
		local quest_lines = wrap_text(dialog.quest_text or "", max_chars)

		-- Draw quest text in yellow
		for _, line in ipairs(quest_lines) do
			print(line, x + 8, oy, 22)  -- yellow for quest text
			oy = oy + line_h
		end

		oy = oy + 8  -- gap between quest text and options

		-- Draw options
		for i, opt in ipairs(dialog.options) do
			local col = (i == dialog.selected) and cfg.dialog_selected_color or cfg.dialog_option_color
			local prefix = (i == dialog.selected) and "> " or "  "
			local text = prefix .. opt.text
			local lines = wrap_text(text, max_chars)

			for j, line in ipairs(lines) do
				if j > 1 then
					line = "  " .. line
				end
				print(line, x + 8, oy, col)
				oy = oy + line_h
			end
			oy = oy + 2
		end
	else
		-- Show options with text wrapping
		local oy = content_start_y
		for i, opt in ipairs(dialog.options) do
			local col = (i == dialog.selected) and cfg.dialog_selected_color or cfg.dialog_option_color
			local prefix = (i == dialog.selected) and "> " or "  "
			local text = prefix .. opt.text
			local lines = wrap_text(text, max_chars)

			for j, line in ipairs(lines) do
				-- Only show prefix on first line
				if j > 1 then
					line = "  " .. line  -- indent continuation lines
				end
				print(line, x + 8, oy, col)
				oy = oy + line_h
			end
			oy = oy + 2  -- small gap between options
		end
	end

	-- Show [X] Quit indicator in bottom right corner
	local quit_text = "[X] Quit"
	local quit_w = print(quit_text, 0, -100)  -- measure text width properly
	print_shadow(quit_text, x + w - quit_w - 6, y + h - 10, 6)
end

-- Check for fan interaction (E key near fan)
function check_fan_interaction()
	if dialog.active then return end
	if player_vehicle then return end  -- can't talk while in vehicle
	if shop and shop.active then return end  -- can't talk while shopping
	-- Cooldown after dialog closes to prevent instant re-interaction
	if dialog.close_cooldown and time() < dialog.close_cooldown then return end

	-- Check for NPC currently in dialog (don't allow re-interaction)
	local npc, fan_data = find_nearby_fan()
	if npc and npc.in_dialog then return end  -- NPC is still in dialog

	-- Use keyp for single-press detection (input_utils.key_pressed may be consumed by dealer check)
	if keyp("e") then
		if npc and fan_data then
			start_dialog(npc, fan_data)
		end
	end
end

-- Draw prompt when near a fan
function draw_fan_prompt()
	if dialog.active then return end
	if player_vehicle then return end

	local npc, fan_data = find_nearby_fan()
	if npc and fan_data then
		local sx, sy = world_to_screen(npc.x, npc.y)
		-- Different text for fans vs lovers (lovers can talk/heal)
		local text = fan_data.is_lover and "E: TALK" or "E: FLIRT"
		local tw = print(text, 0, -100)  -- measure text width properly
		-- Draw above the heart sprite (moved up from -20 to -28)
		local prompt_y = sy - 28
		print_shadow(text, sx - tw/2, prompt_y, PLAYER_CONFIG.prompt_color)
	end
end

function _draw()
	-- Menu state - only draw menu
	if game_state == "menu" then
		draw_menu()
		return
	end

	-- Playing state - draw game
	cls(0)  -- dark background

	-- Draw ground tiles (grass and dirt roads)
	profile("ground")
	draw_ground()
	profile("ground")

	-- Draw countryside flora (behind buildings/sprites)
	profile("flora")
	draw_flora()
	profile("flora")

	-- Get player sprite info
	local player_spr = get_player_sprite()
	local flip_x = not game.player.facing_right

	-- Draw buildings, player, NPCs, and lamps with proper depth sorting
	profile("buildings")
	draw_buildings_and_player(buildings, game.player, player_spr, flip_x)
	profile("buildings")

	-- Draw collision effects (explosion feedback)
	draw_collision_effects()

	-- Draw bomb car arrow (before timer starts)
	draw_bomb_car_arrow()

	-- Draw projectiles and beams (these stay on top, not depth sorted)
	-- Player weapons are now drawn via the depth-sorted queue in building.lua
	draw_projectiles()
	draw_beams()

	-- Draw player shadow overlay using color table (only when not in night mode)
	-- if not night_mode then
	-- 	apply_color_table(shadow_coltab_mode)
	-- end

	-- Draw night mode overlay (darkness with street light cutouts)
	-- Calculate player screen position for spotlight
	profile("night")
	local player_sx, player_sy = world_to_screen(game.player.x, game.player.y)
	draw_night_mode(player_sx, player_sy)
	profile("night")

	-- Draw traffic signals AFTER night overlay so they stay bright/visible
	draw_traffic_signals()

	-- Draw clock above minimap
	draw_clock()

	-- Draw minimap
	draw_minimap()

	-- Draw race checkpoints on minimap
	draw_race_minimap()

	-- Draw vehicle health bar (if in vehicle)
	draw_vehicle_health_bar()

	-- Draw steal prompt (if near a vehicle)
	draw_steal_prompt()

	-- Draw fan prompt (if near a fan)
	draw_fan_prompt()

	-- Draw beyond the sea quest prompts (package is now depth-sorted in building.lua)
	draw_beyond_the_sea_prompts()

	-- Draw bomb pickup prompt (bomb delivery quest)
	draw_bomb_pickup_prompt()

	-- Draw race checkpoint markers (world space)
	draw_race_checkpoint()

	-- Draw player health, armor, popularity, and money
	draw_health_bar()
	draw_armor_bar()
	draw_popularity_bar()
	draw_lover_count()
	draw_money()

	-- Draw weapon HUD (equipped weapon and ammo)
	draw_weapon_hud()

	-- Draw quest HUD (current objectives)
	draw_quest_hud()

	-- Draw race HUD (lap counter, position)
	draw_race_hud()

	-- Draw car wrecker HUD (timer, wreck count)
	draw_wrecker_hud()
	draw_wrecker_failure()

	-- Draw speed dating HUD (timer)
	draw_speed_dating_hud()
	draw_speed_dating_failure()

	-- Draw bomb delivery HUD (timer)
	draw_bomb_delivery_hud()
	draw_bomb_countdown_hud()  -- Big countdown timer after reaching final checkpoint

	-- Draw repair progress bar (fix_home quest)
	draw_repair_progress_bar()

	-- Draw quest completed banner (big center text)
	draw_quest_complete_banner()

	-- Draw fox defeated message
	draw_fox_defeated_message()

	-- Draw cactus UI
	draw_cactus_bullets()
	draw_cactus_health_bar()
	draw_cactus_defeated_message()

	-- Draw Kathy UI
	draw_kathy_bullets()
	draw_kathy_health_bar()
	draw_kathy_defeated_message()
	draw_kathy_fox_defeated_message()

	-- Draw Mothership UI
	draw_mothership_bullets()
	draw_alien_minion_bullets()
	draw_mothership_health_bar()
	draw_mothership_defeated_message()

	-- Draw dealer prompt and boss health bar
	draw_dealer_prompt()
	draw_boss_health_bar()
	draw_defeat_message()

	-- Draw dialog box (if talking to fan)
	draw_dialog()

	-- Draw shop UI (overlays everything)
	draw_shop()

	-- Draw death overlay (WASTED screen - overlays everything)
	draw_death_overlay()

	-- Draw bomb delivery failure (KABOOM!) AFTER death overlay so it appears on top
	draw_bomb_delivery_failure()

	-- UI with drop shadows (only when debug enabled)
	profile("ui")
	if DEBUG_CONFIG.enabled then
		-- print_shadow("GTA PICOTRON", 4, 4, 6)
		print_shadow("arrows: move  X: toggle renderer", 4, 14, 6)
		print_shadow("pos: "..flr(game.player.x)..","..flr(game.player.y), 4, SCREEN_H - 20, 6)
		print_shadow("mode: "..render_mode, 4, SCREEN_H - 10, 6)
		print_shadow("coltab: "..shadow_coltab_mode.." (M cycle)", SCREEN_W - 150, 24, 6)

		-- CPU stats
		local cpu = stat(1)  -- CPU usage (0-1 range, where 1 = 100%)
		local fps = stat(7)  -- current FPS
		print_shadow("cpu: "..flr(cpu * 100).."%", SCREEN_W - 70, 4, 6)
		print_shadow("fps: "..flr(fps), SCREEN_W - 70, 14, 6)
		print_shadow("dir: "..(game.player.facing_dir or "?"), SCREEN_W - 70, 24, 6)

		-- Draw profiler output
		profile.draw()

		-- Print profiler stats to console every 10 seconds
		profile.printh_periodic()
	end

	-- Draw debug stats (independent of DEBUG_CONFIG.enabled)
	draw_vehicle_profiler()
	draw_npc_profiler()
	profile("ui")
end
