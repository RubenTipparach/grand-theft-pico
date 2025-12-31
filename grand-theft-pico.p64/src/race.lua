--[[pod_format="raw"]]
-- race.lua - Racing quest system

-- ============================================
-- RACE STATE
-- ============================================

-- Race is active when mission.current_quest == "mega_race"
-- State is stored in mission table (see quest.lua)

-- Delta time tracking for race updates
race_last_update_time = nil

-- ============================================
-- RACE INITIALIZATION
-- ============================================

-- Start the race (called when player reaches start line)
function start_race()
	if mission.race_started then return end

	mission.race_started = true
	mission.race_start_time = time()
	mission.player_lap = 1
	mission.player_checkpoint = 2  -- Start heading to checkpoint 2

	-- Spawn AI racers at start line
	spawn_racers()

	printh("Race started! " .. #mission.racers .. " racers spawned")
end

-- Start a race replay (called from companion dialog after completing mega_race once)
-- This sets up the race without changing the quest chain
function start_race_replay()
	-- Clean up any existing race first
	cleanup_race()

	-- Store the current quest so we can restore it after race
	mission.pre_race_quest = mission.current_quest

	-- Set up race state (similar to start_quest("mega_race") but doesn't change quest chain)
	mission.race_started = false
	mission.race_finished = false
	mission.race_won = false
	mission.player_lap = 0
	mission.player_checkpoint = 1
	mission.player_position = 1
	mission.racers = {}
	mission.racer_progress = {}
	mission.race_timed_out = false

	-- Convert Aseprite checkpoints to world coords
	mission.race_checkpoints = {}
	for _, cp in ipairs(RACE_CONFIG.checkpoints) do
		local wx, wy = sprite_map_to_world(cp.x, cp.y)
		add(mission.race_checkpoints, {x = wx, y = wy})
	end

	-- Temporarily set current quest to mega_race so race systems work
	mission.current_quest = "mega_race"

	printh("Race replay started! Drive to start line.")
end

-- Spawn AI racer vehicles at start line
function spawn_racers()
	if not mission.race_checkpoints or #mission.race_checkpoints == 0 then return end

	local start = mission.race_checkpoints[1]
	local second_cp = mission.race_checkpoints[2]
	local num_racers = RACE_CONFIG.num_racers

	mission.racers = {}
	mission.racer_progress = {}

	-- Determine race direction from start to checkpoint 2
	local race_dx = second_cp.x - start.x
	local race_dy = second_cp.y - start.y
	local race_dist = sqrt(race_dx * race_dx + race_dy * race_dy)
	if race_dist < 1 then race_dist = 1 end

	-- Normalize direction vector
	local dir_x = race_dx / race_dist
	local dir_y = race_dy / race_dist

	-- Perpendicular vector for row spacing (E-W layout)
	local perp_x = -dir_y
	local perp_y = dir_x

	-- Determine initial facing direction based on race direction
	local initial_dir = "east"
	if abs(race_dy) > abs(race_dx) then
		initial_dir = race_dy > 0 and "south" or "north"
	else
		initial_dir = race_dx > 0 and "east" or "west"
	end

	-- Spawn racers in 2 rows (E-W layout), some ahead of player
	-- Row layout: 4 cars per row, 2 rows
	-- Some cars spawn slightly ahead, some at same line, some behind
	local row_spacing = 40      -- distance between rows (along race direction)
	local col_spacing = 36      -- distance between cars in same row (perpendicular)
	local cars_per_row = 4

	for i = 1, num_racers do
		local row = flr((i - 1) / cars_per_row)  -- 0 or 1
		local col = (i - 1) % cars_per_row       -- 0, 1, 2, or 3

		-- Center the columns: -1.5, -0.5, 0.5, 1.5 spacing
		local col_offset = (col - 1.5) * col_spacing

		-- Row offset: first row slightly ahead, second row behind
		-- Row 0 = ahead by 20px, Row 1 = behind by 20px
		local row_offset = (row - 0.5) * row_spacing

		-- Calculate spawn position
		-- Perpendicular offset for column spread
		local spawn_x = start.x + perp_x * col_offset + dir_x * row_offset
		local spawn_y = start.y + perp_y * col_offset + dir_y * row_offset

		-- Create racer vehicle (alternate truck and van)
		local vtype = (i % 2 == 0) and "truck" or "van"
		local racer = create_vehicle(spawn_x, spawn_y, vtype, initial_dir)

		if racer then
			-- Mark as racer with boosted health
			racer.is_racer = true
			racer.has_driver = true
			racer.max_health = racer.max_health * RACE_CONFIG.racer_health_multiplier
			racer.health = racer.max_health

			-- Add to vehicles list and track
			add(vehicles, racer)
			add(mission.racers, racer)

			-- Initialize progress (lap 1, heading to checkpoint 2)
			add(mission.racer_progress, {
				lap = 1,
				checkpoint = 2,
				finished = false,
				finish_time = nil
			})
		end
	end
end

-- Clean up race (remove racers, reset state)
function cleanup_race()
	-- Remove racer vehicles from game
	if mission.racers then
		for _, racer in ipairs(mission.racers) do
			-- Check if player is in this racer vehicle - eject them!
			if player_vehicle == racer then
				-- Place player at vehicle's position before removing it
				game.player.x = racer.x
				game.player.y = racer.y
				player_vehicle.is_player_vehicle = false
				player_vehicle = nil
				printh("Player ejected from despawning racer vehicle!")
			end
			-- Remove from vehicles list
			for i = #vehicles, 1, -1 do
				if vehicles[i] == racer then
					deli(vehicles, i)
					break
				end
			end
		end
	end

	mission.racers = nil
	mission.racer_progress = nil
	mission.race_checkpoints = nil
	printh("Race cleaned up")
end

-- ============================================
-- RACE UPDATE
-- ============================================

-- Main race update (call from main.lua _update)
function update_race()
	if mission.current_quest ~= "mega_race" then return end
	if not mission.race_checkpoints then return end

	-- Check if we need to restore previous quest after replay
	if mission.race_restore_timer and time() >= mission.race_restore_timer then
		finish_race_replay()
		return
	end

	-- Calculate delta time
	local now = time()
	if not race_last_update_time then
		race_last_update_time = now
	end
	local dt = now - race_last_update_time
	race_last_update_time = now
	if dt > 0.1 then dt = 0.1 end  -- Clamp to prevent huge jumps

	-- Check if player reached start line (before race starts)
	if not mission.race_started then
		check_player_at_start()
		return
	end

	-- Race is active
	-- Check player checkpoint progress
	check_player_checkpoint()

	-- Update AI racers
	update_racers(dt)

	-- Update positions
	update_race_positions()

	-- Check for race time limit (5 minutes)
	check_race_time_limit()
end

-- Finish a race replay and restore the previous quest
function finish_race_replay()
	printh("Race replay finished, restoring quest: " .. tostring(mission.pre_race_quest))

	-- Clean up race
	cleanup_race()

	-- Restore the previous quest
	if mission.pre_race_quest then
		mission.current_quest = mission.pre_race_quest
		mission.pre_race_quest = nil
	end

	mission.race_restore_timer = nil
end

-- Check if player is at start line to begin race
function check_player_at_start()
	if not player_vehicle then return end  -- Must be in vehicle
	if not mission.race_checkpoints or #mission.race_checkpoints == 0 then return end

	local start = mission.race_checkpoints[1]
	local px, py = player_vehicle.x, player_vehicle.y
	local dx = px - start.x
	local dy = py - start.y
	local dist = sqrt(dx * dx + dy * dy)

	if dist < RACE_CONFIG.start_line_radius then
		start_race()
	end
end

-- Check if player hit current checkpoint
function check_player_checkpoint()
	if not player_vehicle then return end
	if not mission.race_checkpoints then return end
	if mission.race_finished then return end

	local cp_idx = mission.player_checkpoint
	local cp = mission.race_checkpoints[cp_idx]
	if not cp then return end

	local px, py = player_vehicle.x, player_vehicle.y
	local dx = px - cp.x
	local dy = py - cp.y
	local dist = sqrt(dx * dx + dy * dy)

	if dist < RACE_CONFIG.checkpoint_radius then
		-- Hit checkpoint!
		advance_player_checkpoint()
	end
end

-- Advance player to next checkpoint
function advance_player_checkpoint()
	local num_checkpoints = #mission.race_checkpoints
	mission.player_checkpoint = mission.player_checkpoint + 1

	-- Check for lap completion (checkpoint 1 is start/finish)
	if mission.player_checkpoint > num_checkpoints then
		mission.player_checkpoint = 1
		mission.player_lap = mission.player_lap + 1
		printh("Player completed lap " .. (mission.player_lap - 1) .. "!")

		-- Check for race finish
		if mission.player_lap > RACE_CONFIG.total_laps then
			mission.race_finished = true
			mission.race_completed_once = true  -- Mark that race has been completed (enables replay)

			-- Check if player won (1st place)
			mission.race_won = (mission.player_position == 1)

			-- Award popularity based on finish/win
			local race_cfg = QUEST_CONFIG.mega_race
			if mission.race_won then
				change_popularity(race_cfg.popularity_win)
				printh("Player WON the race! +" .. race_cfg.popularity_win .. " popularity!")
			else
				change_popularity(race_cfg.popularity_finish)
				printh("Player finished the race in position " .. mission.player_position .. "! +" .. race_cfg.popularity_finish .. " popularity")
			end

			-- If this was a replay, restore the previous quest after a delay
			if mission.pre_race_quest then
				-- Schedule quest restoration (handled in update_race)
				mission.race_restore_timer = time() + 3  -- 3 seconds to show results
			end
		end
	end
end

-- ============================================
-- AI RACER UPDATE
-- ============================================

-- Update all AI racers
function update_racers(dt)
	if not mission.racers then return end

	for i, racer in ipairs(mission.racers) do
		local progress = mission.racer_progress[i]
		if racer and progress and not progress.finished then
			-- Check if racer is destroyed
			if racer.state == "destroyed" or racer.state == "exploding" then
				progress.finished = true
				progress.finish_time = -1  -- DNF
			else
				-- Update racer AI - simple direct movement with avoidance
				update_racer_ai_simple(racer, progress, dt, i)
				-- Check racer checkpoint
				check_racer_checkpoint(racer, progress)
			end
		end
	end
end

-- Simple racer AI - drive directly toward checkpoint, with short-range obstacle avoidance
-- Uses direction commitment to prevent twitching (commit to one axis for 2-3 tiles)
function update_racer_ai_simple(racer, progress, dt, racer_index)
	if not mission.race_checkpoints then return end

	local cp = mission.race_checkpoints[progress.checkpoint]
	if not cp then return end

	-- Base speed with per-racer variance
	local base_speed = racer.vtype.speed * RACE_CONFIG.racer_speed_multiplier
	local racer_variance = 0.85 + (racer_index % 5) * 0.06  -- 0.85 to 1.09
	local speed = base_speed * racer_variance * dt

	-- If we have an avoidance target, go there first
	if racer.avoidance_target then
		local avoid_dx = racer.avoidance_target.x - racer.x
		local avoid_dy = racer.avoidance_target.y - racer.y
		local avoid_dist = sqrt(avoid_dx * avoid_dx + avoid_dy * avoid_dy)

		if avoid_dist < 20 then
			-- Reached avoidance point, clear it
			racer.avoidance_target = nil
			racer.committed_dir = nil  -- Clear commitment when reaching avoidance
			racer.committed_distance = 0
		else
			-- Move toward avoidance point
			local move_dir = get_best_direction_to_target(racer.x, racer.y, racer.avoidance_target.x, racer.avoidance_target.y)
			local vec = VEHICLE_DIR_VECTORS[move_dir]
			if vec then
				racer.x = racer.x + vec.dx * speed
				racer.y = racer.y + vec.dy * speed
				racer.facing_dir = move_dir
			end
			return
		end
	end

	-- Calculate direction to checkpoint
	local dx = cp.x - racer.x
	local dy = cp.y - racer.y
	local dist = sqrt(dx * dx + dy * dy)

	if dist < 1 then return end

	-- Initialize commitment tracking if needed
	if not racer.committed_distance then racer.committed_distance = 0 end
	local commit_dist = RACE_CONFIG.direction_commit_distance or 48

	-- Determine the ideal direction (prioritize one axis to prevent diagonal twitching)
	local ideal_dir = nil

	-- If we have a committed direction and haven't traveled enough, keep it
	if racer.committed_dir and racer.committed_distance < commit_dist then
		ideal_dir = racer.committed_dir
		-- But check if we've reached the goal on this axis
		local vec = VEHICLE_DIR_VECTORS[racer.committed_dir]
		if vec then
			-- If committed to horizontal but we're aligned horizontally, switch
			if (racer.committed_dir == "east" or racer.committed_dir == "west") then
				if abs(dx) < 16 then
					-- Close enough on X axis, switch to vertical
					racer.committed_dir = nil
					racer.committed_distance = 0
					ideal_dir = nil
				end
			-- If committed to vertical but we're aligned vertically, switch
			elseif (racer.committed_dir == "north" or racer.committed_dir == "south") then
				if abs(dy) < 16 then
					-- Close enough on Y axis, switch to horizontal
					racer.committed_dir = nil
					racer.committed_distance = 0
					ideal_dir = nil
				end
			end
		end
	end

	-- If no commitment, pick a new direction based on which axis has more distance
	if not ideal_dir then
		if abs(dx) > abs(dy) then
			-- Prioritize horizontal movement
			ideal_dir = dx > 0 and "east" or "west"
		else
			-- Prioritize vertical movement
			ideal_dir = dy > 0 and "south" or "north"
		end
		-- Commit to this direction
		racer.committed_dir = ideal_dir
		racer.committed_distance = 0
	end

	-- Get the movement vector for our committed direction
	local vec = VEHICLE_DIR_VECTORS[ideal_dir]
	if not vec then return end

	-- Calculate desired new position
	local desired_x = racer.x + vec.dx * speed
	local desired_y = racer.y + vec.dy * speed

	-- Check for obstacles in the way
	local blocking_building = nil

	-- Building collision check
	for _, b in ipairs(buildings) do
		if desired_x > b.x - 20 and desired_x < b.x + b.w + 20 and
		   desired_y > b.y - 20 and desired_y < b.y + b.h + 20 then
			blocking_building = b
			break
		end
	end

	-- Check for other racer collision (but don't do complex avoidance, just slow down)
	local racer_ahead = false
	for j, other in ipairs(mission.racers) do
		if j ~= racer_index and other.state ~= "destroyed" then
			local other_dx = desired_x - other.x
			local other_dy = desired_y - other.y
			local other_dist = sqrt(other_dx * other_dx + other_dy * other_dy)
			if other_dist < 20 then
				racer_ahead = true
				break
			end
		end
	end

	if blocking_building then
		-- Find a short-range avoidance point around the building
		local avoid_point = find_avoidance_point(racer.x, racer.y, blocking_building, cp.x, cp.y)
		if avoid_point then
			racer.avoidance_target = avoid_point
		end
		-- Clear commitment when blocked
		racer.committed_dir = nil
		racer.committed_distance = 0
		-- Still try to move in an alternate direction this frame
		local alt_dirs = get_alternate_directions(ideal_dir)
		for _, alt_dir in ipairs(alt_dirs) do
			local alt_vec = VEHICLE_DIR_VECTORS[alt_dir]
			if alt_vec then
				local alt_x = racer.x + alt_vec.dx * speed
				local alt_y = racer.y + alt_vec.dy * speed
				-- Quick check if alternate is clear
				local clear = true
				for _, b in ipairs(buildings) do
					if alt_x > b.x - 16 and alt_x < b.x + b.w + 16 and
					   alt_y > b.y - 16 and alt_y < b.y + b.h + 16 then
						clear = false
						break
					end
				end
				if clear then
					racer.x = alt_x
					racer.y = alt_y
					racer.facing_dir = alt_dir
					return
				end
			end
		end
	elseif racer_ahead then
		-- Slow down and try to go around other racer
		local alt_dirs = get_alternate_directions(ideal_dir)
		local moved = false
		for _, alt_dir in ipairs(alt_dirs) do
			local alt_vec = VEHICLE_DIR_VECTORS[alt_dir]
			if alt_vec then
				local alt_x = racer.x + alt_vec.dx * speed * 0.5
				local alt_y = racer.y + alt_vec.dy * speed * 0.5
				racer.x = alt_x
				racer.y = alt_y
				racer.facing_dir = alt_dir
				moved = true
				break
			end
		end
		if not moved then
			-- Just slow down in current direction
			racer.x = racer.x + vec.dx * speed * 0.3
			racer.y = racer.y + vec.dy * speed * 0.3
			racer.facing_dir = ideal_dir
		end
	else
		-- Clear path - move in committed direction
		racer.x = desired_x
		racer.y = desired_y
		racer.facing_dir = ideal_dir
		-- Track distance traveled in this direction
		racer.committed_distance = racer.committed_distance + speed
	end
end

-- Find a point to navigate around a building
function find_avoidance_point(rx, ry, building, goal_x, goal_y)
	-- Calculate building corners with padding
	local pad = 32
	local corners = {
		{x = building.x - pad, y = building.y - pad},           -- top-left
		{x = building.x + building.w + pad, y = building.y - pad}, -- top-right
		{x = building.x - pad, y = building.y + building.h + pad}, -- bottom-left
		{x = building.x + building.w + pad, y = building.y + building.h + pad}, -- bottom-right
	}

	-- Find corner that gets us closest to goal while being reachable
	local best_corner = nil
	local best_score = 999999

	for _, corner in ipairs(corners) do
		-- Distance from corner to goal
		local to_goal_dx = goal_x - corner.x
		local to_goal_dy = goal_y - corner.y
		local to_goal_dist = sqrt(to_goal_dx * to_goal_dx + to_goal_dy * to_goal_dy)

		-- Distance from racer to corner
		local to_corner_dx = corner.x - rx
		local to_corner_dy = corner.y - ry
		local to_corner_dist = sqrt(to_corner_dx * to_corner_dx + to_corner_dy * to_corner_dy)

		-- Prefer corners that are closer to us and get us closer to goal
		local score = to_goal_dist + to_corner_dist * 0.5

		if score < best_score then
			best_score = score
			best_corner = corner
		end
	end

	return best_corner
end

-- Get alternate directions to try when blocked (perpendicular first, then opposite)
function get_alternate_directions(blocked_dir)
	if blocked_dir == "north" then
		return {"east", "west", "south"}
	elseif blocked_dir == "south" then
		return {"east", "west", "north"}
	elseif blocked_dir == "east" then
		return {"north", "south", "west"}
	elseif blocked_dir == "west" then
		return {"north", "south", "east"}
	end
	return {"north", "east", "south", "west"}
end

-- Get best cardinal direction to reach target
function get_best_direction_to_target(fx, fy, tx, ty)
	local dx = tx - fx
	local dy = ty - fy

	-- Pick dominant direction
	if abs(dx) > abs(dy) then
		return dx > 0 and "east" or "west"
	else
		return dy > 0 and "south" or "north"
	end
end

-- Check if vehicle can turn from current to target direction (no 180s)
function can_vehicle_turn(from_dir, to_dir)
	if not from_dir then return true end
	local opposites = {
		north = "south",
		south = "north",
		east = "west",
		west = "east"
	}
	return opposites[from_dir] ~= to_dir
end

-- Check if racer hit their current checkpoint
function check_racer_checkpoint(racer, progress)
	if not mission.race_checkpoints then return end

	local cp = mission.race_checkpoints[progress.checkpoint]
	if not cp then return end

	local dx = racer.x - cp.x
	local dy = racer.y - cp.y
	local dist = sqrt(dx * dx + dy * dy)

	if dist < RACE_CONFIG.checkpoint_radius then
		-- Hit checkpoint
		local num_checkpoints = #mission.race_checkpoints
		progress.checkpoint = progress.checkpoint + 1

		if progress.checkpoint > num_checkpoints then
			progress.checkpoint = 1
			progress.lap = progress.lap + 1

			-- Check for racer finish
			if progress.lap > RACE_CONFIG.total_laps then
				progress.finished = true
				progress.finish_time = time() - mission.race_start_time
				printh("Racer finished!")
			end
		end
	end
end

-- ============================================
-- POSITION TRACKING
-- ============================================

-- Update race positions for all racers and player
function update_race_positions()
	if not mission.racers then return end

	-- Build list of all racers including player
	local standings = {}

	-- Add player
	add(standings, {
		is_player = true,
		lap = mission.player_lap,
		checkpoint = mission.player_checkpoint,
		dist_to_cp = get_player_dist_to_checkpoint(),
		finished = mission.race_finished
	})

	-- Add AI racers (skip if player stole this racer's car)
	for i, racer in ipairs(mission.racers) do
		-- Skip racers that are now player-controlled (player stole their car)
		if not racer.is_player_vehicle then
			local progress = mission.racer_progress[i]
			if progress then
				add(standings, {
					is_player = false,
					lap = progress.lap,
					checkpoint = progress.checkpoint,
					dist_to_cp = get_racer_dist_to_checkpoint(racer, progress),
					finished = progress.finished
				})
			end
		end
	end

	-- Sort by: finished (first), then lap (higher better), then checkpoint (higher better), then distance (lower better)
	sort_list(standings, function(a, b)
		-- Finished racers rank by finish time (we use lap as proxy)
		if a.finished and not b.finished then return true end
		if b.finished and not a.finished then return false end

		-- Higher lap = better position
		if a.lap ~= b.lap then return a.lap > b.lap end

		-- Higher checkpoint = better position
		if a.checkpoint ~= b.checkpoint then return a.checkpoint > b.checkpoint end

		-- Closer to next checkpoint = better
		return a.dist_to_cp < b.dist_to_cp
	end)

	-- Find player position
	for i, s in ipairs(standings) do
		if s.is_player then
			mission.player_position = i
			break
		end
	end
end

-- Get player distance to current checkpoint
function get_player_dist_to_checkpoint()
	if not player_vehicle then return 9999 end
	if not mission.race_checkpoints then return 9999 end

	local cp = mission.race_checkpoints[mission.player_checkpoint]
	if not cp then return 9999 end

	local dx = player_vehicle.x - cp.x
	local dy = player_vehicle.y - cp.y
	return sqrt(dx * dx + dy * dy)
end

-- Get racer distance to current checkpoint
function get_racer_dist_to_checkpoint(racer, progress)
	if not mission.race_checkpoints then return 9999 end

	local cp = mission.race_checkpoints[progress.checkpoint]
	if not cp then return 9999 end

	local dx = racer.x - cp.x
	local dy = racer.y - cp.y
	return sqrt(dx * dx + dy * dy)
end

-- ============================================
-- RACE TIME LIMIT
-- ============================================

-- Check if race time limit exceeded (5 minutes)
function check_race_time_limit()
	if not mission.race_started then return end
	if mission.race_finished then return end

	local elapsed = time() - mission.race_start_time
	local time_limit = RACE_CONFIG.time_limit or 300  -- 5 minutes default

	if elapsed >= time_limit then
		-- Time's up - race ends, player loses
		mission.race_finished = true
		mission.race_timed_out = true
		printh("Race timed out!")
	end
end

-- ============================================
-- RACE DRAWING
-- ============================================

-- Draw current checkpoint in world
function draw_race_checkpoint()
	if mission.current_quest ~= "mega_race" then return end
	if not mission.race_checkpoints then return end

	-- Draw all checkpoints (dimmed) and current checkpoint (bright)
	for i, cp in ipairs(mission.race_checkpoints) do
		local sx, sy = world_to_screen(cp.x, cp.y)

		-- Only draw if on screen
		if sx > -50 and sx < SCREEN_W + 50 and sy > -50 and sy < SCREEN_H + 50 then
			local is_current = (mission.race_started and i == mission.player_checkpoint) or
			                   (not mission.race_started and i == 1)
			local is_start = (i == 1)

			local radius = RACE_CONFIG.checkpoint_world_radius
			local color = is_current and RACE_CONFIG.checkpoint_active_color or RACE_CONFIG.checkpoint_color

			-- Draw checkpoint circle
			if is_current then
				-- Pulsing effect for current checkpoint
				local pulse = sin(time() * 4) * 4
				circ(sx, sy, radius + pulse, color)
				circ(sx, sy, radius + pulse - 2, color)
			else
				circ(sx, sy, radius, color)
			end

			-- Draw start/finish label
			if is_start and not mission.race_started then
				print_shadow("START", sx - 15, sy - radius - 12, 22)  -- yellow
			end
		end
	end
end

-- Draw race checkpoints on minimap
function draw_race_minimap()
	if mission.current_quest ~= "mega_race" then return end
	if not mission.race_checkpoints then return end

	-- Get minimap config and calculate values (same as draw_minimap)
	local cfg = MINIMAP_CONFIG
	if not cfg.enabled then return end

	local mx = cfg.x
	local my = cfg.y
	local mw = cfg.width
	local mh = cfg.height
	local tile_size = MAP_CONFIG.tile_size
	local map_w = MAP_CONFIG.map_width
	local map_h = MAP_CONFIG.map_height
	local half_map_w = map_w / 2
	local half_map_h = map_h / 2

	-- Calculate player position in map coordinates
	local px = game.player.x / tile_size + half_map_w
	local py = game.player.y / tile_size + half_map_h
	local half_mw = mw / 2
	local half_mh = mh / 2

	-- Clip to minimap area
	clip(mx, my, mw + 1, mh + 1)

	for i, cp in ipairs(mission.race_checkpoints) do
		-- Convert world to minimap coords
		local marker_x = mx + (cp.x / tile_size + half_map_w - px + half_mw)
		local marker_y = my + (cp.y / tile_size + half_map_h - py + half_mh)

		-- Clamp to minimap bounds
		marker_x = max(mx, min(mx + mw - 1, marker_x))
		marker_y = max(my, min(my + mh - 1, marker_y))

		local is_current = (mission.race_started and i == mission.player_checkpoint) or
		                   (not mission.race_started and i == 1)

		-- Draw checkpoint marker
		if is_current then
			-- Blink current checkpoint
			local blink = flr(time() * 3) % 2 == 0
			if blink then
				circfill(marker_x, marker_y, RACE_CONFIG.minimap_checkpoint_size + 1, RACE_CONFIG.checkpoint_active_color)
			end
		else
			pset(marker_x, marker_y, RACE_CONFIG.minimap_checkpoint_color)
		end
	end

	-- Reset clip
	clip()
end

-- Draw race HUD (lap counter, position, timer)
function draw_race_hud()
	if mission.current_quest ~= "mega_race" then return end

	local x = RACE_CONFIG.hud_x
	local y = RACE_CONFIG.hud_y

	if not mission.race_started then
		-- Show "Drive to start" message
		print_shadow("RACE: Drive to START", x, y, 22)
	else
		-- Show lap counter
		local lap_text = "LAP " .. mission.player_lap .. "/" .. RACE_CONFIG.total_laps
		print_shadow(lap_text, x, y, 22)  -- yellow

		-- Show position
		local pos_suffix = get_ordinal_suffix(mission.player_position)
		local pos_text = mission.player_position .. pos_suffix .. " PLACE"
		print_shadow(pos_text, x, y + 10, 22)

		-- Show race time (countdown from 5 minutes)
		if mission.race_start_time then
			local elapsed = time() - mission.race_start_time
			local time_limit = RACE_CONFIG.time_limit or 300
			local remaining = time_limit - elapsed
			if remaining < 0 then remaining = 0 end
			local mins = flr(remaining / 60)
			local secs = flr(remaining % 60)
			local time_text = string.format("%d:%02d", mins, secs)
			-- Color based on time remaining (red if low)
			local time_color = remaining < 30 and 12 or 7  -- red if < 30s, white otherwise
			print_shadow(time_text, x, y + 20, time_color)
		end
	end
end
