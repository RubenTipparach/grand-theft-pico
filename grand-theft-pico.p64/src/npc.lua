--[[pod_format="raw"]]
-- npc.lua - NPC AI and rendering

-- Global NPC list
npcs = {}

-- Directions for movement
local DIRECTIONS = { "north", "south", "east", "west" }
local DIR_VECTORS = {
	north = { dx = 0, dy = -1 },
	south = { dx = 0, dy = 1 },
	east  = { dx = 1, dy = 0 },
	west  = { dx = -1, dy = 0 },
}

-- Create a new NPC at a given position
function create_npc(x, y, npc_type_index)
	local npc_type = NPC_TYPES[npc_type_index] or NPC_TYPES[1]
	local now = time()
	return {
		x = x,
		y = y,
		npc_type = npc_type,
		facing_dir = "south",
		walk_frame = 0,
		walk_time = now,          -- last animation frame change time
		state = "idle",           -- "idle", "walking", "surprised", or "fleeing"
		state_end_time = now,     -- when current state ends (seconds)
		damaged = false,
		-- Freaked out state
		prev_state = nil,         -- state to return to after calming down
		prev_facing_dir = nil,    -- direction to restore
		flee_dir = nil,           -- direction fleeing away from player
		show_surprise = false,    -- show exclamation sprite above head
		flee_recheck_time = now,  -- last flee direction check time
		last_update_time = now,   -- for delta time calculation
	}
end

-- Get a random point on a road for spawning
function get_random_road_point()
	local road = ROADS[flr(rnd(#ROADS)) + 1]
	local x, y

	if road.direction == "horizontal" then
		x = road.x1 + rnd(road.x2 - road.x1)
		y = road.y
	else
		x = road.x
		y = road.y1 + rnd(road.y2 - road.y1)
	end

	return x, y
end

-- Get a valid spawn point that doesn't collide with buildings
function get_valid_spawn_point()
	local max_attempts = 20
	local radius = NPC_CONFIG.collision_radius

	for attempt = 1, max_attempts do
		local x, y = get_random_road_point()
		-- Check if this point collides with any building
		if not npc_collides_with_building(x, y, radius) then
			return x, y
		end
	end

	-- Fallback: return a road point anyway (better than nothing)
	return get_random_road_point()
end

-- Spawn NPCs on roads, avoiding buildings
-- If player_x/player_y provided, spawns near player (for streaming mode)
function spawn_npcs(count, player_x, player_y)
	npcs = {}
	for i = 1, count do
		local npc = nil
		if player_x and player_y then
			-- Mode 2: spawn near player
			npc = spawn_npc_near_player(player_x, player_y)
		end
		if not npc then
			-- Mode 1 or fallback: spawn at random road points
			local x, y = get_valid_spawn_point()
			local npc_type_index = flr(rnd(#NPC_TYPES)) + 1
			npc = create_npc(x, y, npc_type_index)
		end
		add(npcs, npc)
	end
	printh("Spawned " .. #npcs .. " NPCs")
end

-- Check if a position collides with any building
function npc_collides_with_building(x, y, radius)
	for _, b in ipairs(buildings) do
		-- Expand building bounds by collision radius
		if x + radius > b.x and x - radius < b.x + b.w and
		   y + radius > b.y and y - radius < b.y + b.h then
			return true
		end
	end
	return false
end

-- Pick a new random direction that doesn't immediately hit a building
function pick_valid_direction(npc)
	local valid_dirs = {}
	local speed = NPC_CONFIG.walk_speed
	local radius = NPC_CONFIG.collision_radius

	-- Check each direction
	for _, dir in ipairs(DIRECTIONS) do
		local vec = DIR_VECTORS[dir]
		local test_x = npc.x + vec.dx * speed * 8  -- look ahead 8 frames
		local test_y = npc.y + vec.dy * speed * 8

		if not npc_collides_with_building(test_x, test_y, radius) then
			add(valid_dirs, dir)
		end
	end

	-- Pick a random valid direction, or stay still if none
	if #valid_dirs > 0 then
		return valid_dirs[flr(rnd(#valid_dirs)) + 1]
	end
	return nil
end

-- Get the best flee direction (away from player)
function get_flee_direction(npc, player_x, player_y)
	local dx = npc.x - player_x
	local dy = npc.y - player_y
	local speed = NPC_CONFIG.run_speed
	local radius = NPC_CONFIG.collision_radius

	-- Determine flee direction: run AWAY from player
	-- dx > 0 means NPC is to the RIGHT of player, so flee EAST (further right)
	-- dx < 0 means NPC is to the LEFT of player, so flee WEST (further left)
	-- dy > 0 means NPC is BELOW player, so flee SOUTH (further down)
	-- dy < 0 means NPC is ABOVE player, so flee NORTH (further up)
	local primary_dirs = {}

	-- Add directions in priority order: primary axis first, then secondary
	if abs(dx) > abs(dy) then
		-- Horizontal distance is greater, prioritize horizontal flee
		if dx > 0 then
			add(primary_dirs, "east")   -- NPC is right of player, flee right
		else
			add(primary_dirs, "west")   -- NPC is left of player, flee left
		end
		if dy > 0 then
			add(primary_dirs, "south")  -- NPC is below player, flee down
		else
			add(primary_dirs, "north")  -- NPC is above player, flee up
		end
		-- Add opposite directions as last resort fallbacks
		if dx > 0 then add(primary_dirs, "west") else add(primary_dirs, "east") end
		if dy > 0 then add(primary_dirs, "north") else add(primary_dirs, "south") end
	else
		-- Vertical distance is greater, prioritize vertical flee
		if dy > 0 then
			add(primary_dirs, "south")  -- NPC is below player, flee down
		else
			add(primary_dirs, "north")  -- NPC is above player, flee up
		end
		if dx > 0 then
			add(primary_dirs, "east")   -- NPC is right of player, flee right
		else
			add(primary_dirs, "west")   -- NPC is left of player, flee left
		end
		-- Add opposite directions as last resort fallbacks
		if dy > 0 then add(primary_dirs, "north") else add(primary_dirs, "south") end
		if dx > 0 then add(primary_dirs, "west") else add(primary_dirs, "east") end
	end

	-- Try each direction in priority order
	for _, dir in ipairs(primary_dirs) do
		local vec = DIR_VECTORS[dir]
		local test_x = npc.x + vec.dx * speed * 4
		local test_y = npc.y + vec.dy * speed * 4
		if not npc_collides_with_building(test_x, test_y, radius) then
			return dir
		end
	end

	-- Fallback: any valid direction
	return pick_valid_direction(npc)
end

-- Update a single NPC (time-based, frame-independent)
function update_npc(npc, player_x, player_y)
	local now = time()
	local dt = now - npc.last_update_time
	npc.last_update_time = now

	-- Check if player is too close (trigger surprised state)
	if npc.state ~= "surprised" and npc.state ~= "fleeing" and player_x and player_y then
		local dx = npc.x - player_x
		local dy = npc.y - player_y
		local dist = sqrt(dx * dx + dy * dy)
		if dist < NPC_CONFIG.scare_radius then
			-- Save current state to restore later
			npc.prev_state = npc.state
			npc.prev_facing_dir = npc.facing_dir
			-- Enter surprised state (frozen with exclamation)
			npc.state = "surprised"
			npc.state_end_time = now + NPC_CONFIG.surprise_duration
			npc.show_surprise = true
			npc.walk_frame = 0  -- freeze animation
			-- Store player position to calculate flee direction when fleeing starts
			npc.scare_player_x = player_x
			npc.scare_player_y = player_y
		end
	end

	if npc.state == "idle" then
		-- Standing still
		npc.walk_frame = 0

		if now >= npc.state_end_time then
			-- Time to start walking
			local new_dir = pick_valid_direction(npc)
			if new_dir then
				npc.facing_dir = new_dir
				npc.state = "walking"
				local cfg = NPC_CONFIG.direction_change_time
				npc.state_end_time = now + cfg.min + rnd(cfg.max - cfg.min)
			else
				-- Can't move, stay idle longer
				local cfg = NPC_CONFIG.idle_time
				npc.state_end_time = now + cfg.min + rnd(cfg.max - cfg.min)
			end
		end
	elseif npc.state == "walking" then
		-- Moving (pixels per second * delta time)
		local vec = DIR_VECTORS[npc.facing_dir]
		local speed = NPC_CONFIG.walk_speed * dt
		local radius = NPC_CONFIG.collision_radius

		local new_x = npc.x + vec.dx * speed
		local new_y = npc.y + vec.dy * speed

		-- Check for collision
		if npc_collides_with_building(new_x, new_y, radius) then
			-- Hit a building, stop and go idle
			npc.state = "idle"
			local cfg = NPC_CONFIG.idle_time
			npc.state_end_time = now + cfg.min + rnd(cfg.max - cfg.min)
		else
			-- Move
			npc.x = new_x
			npc.y = new_y

			-- Update walk animation (time-based)
			local anim_speed = NPC_CONFIG.animation_speed
			if now >= npc.walk_time + anim_speed then
				npc.walk_frame = (npc.walk_frame % 3) + 1
				npc.walk_time = now
			end
		end

		if now >= npc.state_end_time then
			-- Time to change direction or stop
			if rnd(1) < 0.3 then
				-- Stop and idle
				npc.state = "idle"
				local cfg = NPC_CONFIG.idle_time
				npc.state_end_time = now + cfg.min + rnd(cfg.max - cfg.min)
			else
				-- Pick a new direction
				local new_dir = pick_valid_direction(npc)
				if new_dir then
					npc.facing_dir = new_dir
					local cfg = NPC_CONFIG.direction_change_time
					npc.state_end_time = now + cfg.min + rnd(cfg.max - cfg.min)
				else
					-- Can't move, go idle
					npc.state = "idle"
					local cfg = NPC_CONFIG.idle_time
					npc.state_end_time = now + cfg.min + rnd(cfg.max - cfg.min)
				end
			end
		end
	elseif npc.state == "surprised" then
		-- Frozen in place, showing exclamation sprite
		npc.walk_frame = 0

		-- When surprise duration ends, start fleeing
		if now >= npc.state_end_time then
			npc.state = "fleeing"
			npc.state_end_time = now + NPC_CONFIG.flee_duration
			npc.show_surprise = false
			npc.flee_recheck_time = now
			-- Calculate flee direction NOW based on current player position
			-- Use stored scare position as fallback if player moved offscreen
			local flee_from_x = player_x or npc.scare_player_x or npc.x
			local flee_from_y = player_y or npc.scare_player_y or npc.y
			npc.flee_dir = get_flee_direction(npc, flee_from_x, flee_from_y)
			npc.facing_dir = npc.flee_dir or npc.facing_dir
			-- Clear stored scare position
			npc.scare_player_x = nil
			npc.scare_player_y = nil
		end
	elseif npc.state == "fleeing" then
		-- Running away from player (pixels per second * delta time)
		local speed = NPC_CONFIG.run_speed * dt
		local radius = NPC_CONFIG.collision_radius

		-- Periodically re-evaluate flee direction (time-based)
		if now >= npc.flee_recheck_time + NPC_CONFIG.flee_recheck_interval and player_x and player_y then
			npc.flee_recheck_time = now
			npc.flee_dir = get_flee_direction(npc, player_x, player_y)
			npc.facing_dir = npc.flee_dir or npc.facing_dir
		end

		if npc.flee_dir then
			local vec = DIR_VECTORS[npc.flee_dir]
			local new_x = npc.x + vec.dx * speed
			local new_y = npc.y + vec.dy * speed

			-- Check for collision
			if npc_collides_with_building(new_x, new_y, radius) then
				-- Hit a building, pick new flee direction
				npc.flee_dir = get_flee_direction(npc, player_x or npc.x, player_y or npc.y)
				npc.facing_dir = npc.flee_dir or npc.facing_dir
			else
				-- Move
				npc.x = new_x
				npc.y = new_y
			end

			-- Update walk animation (time-based, faster for running)
			local anim_speed = NPC_CONFIG.run_animation_speed
			if now >= npc.walk_time + anim_speed then
				npc.walk_frame = (npc.walk_frame % 3) + 1
				npc.walk_time = now
			end
		end

		-- Check if calmed down
		if now >= npc.state_end_time then
			-- Return to previous state
			npc.state = npc.prev_state or "idle"
			npc.facing_dir = npc.prev_facing_dir or npc.facing_dir
			npc.prev_state = nil
			npc.prev_facing_dir = nil
			npc.flee_dir = nil
			npc.show_surprise = false
			-- Reset timer for restored state
			if npc.state == "idle" then
				local cfg = NPC_CONFIG.idle_time
				npc.state_end_time = now + cfg.min + rnd(cfg.max - cfg.min)
			else
				local cfg = NPC_CONFIG.direction_change_time
				npc.state_end_time = now + cfg.min + rnd(cfg.max - cfg.min)
			end
		end
	end
end

-- Throttle settings for offscreen NPCs
local OFFSCREEN_MARGIN = 64  -- pixels beyond screen edge to consider "offscreen"

-- Spawn a single NPC near the player (for streaming mode)
function spawn_npc_near_player(player_x, player_y)
	local cfg = NPC_CONFIG
	local min_dist = cfg.spawn_distance_min
	local max_dist = cfg.despawn_distance  -- spawn up to despawn distance
	local radius = cfg.collision_radius

	-- Try to find a valid spawn point
	for attempt = 1, 10 do
		-- Random angle and distance
		local angle = rnd(1) * 6.28318  -- 2*PI
		local dist = min_dist + rnd(max_dist - min_dist)
		local x = player_x + cos(angle) * dist
		local y = player_y + sin(angle) * dist

		-- Check if on a road and not colliding with buildings
		if is_on_any_road(x, y) and not npc_collides_with_building(x, y, radius) then
			local npc_type_index = flr(rnd(#NPC_TYPES)) + 1
			return create_npc(x, y, npc_type_index)
		end
	end

	return nil
end

-- Mode 1: Persistent NPCs with distance-based throttling
local function update_npcs_persistent(player_x, player_y)
	local now = time()

	-- Cache config values
	local cfg = NPC_CONFIG
	local offscreen_interval = cfg.offscreen_update_interval
	local update_dist = cfg.offscreen_update_distance
	local update_dist_sq = update_dist * update_dist  -- avoid sqrt

	-- Cache screen constants for inline visibility
	local cx, cy = SCREEN_CX, SCREEN_CY
	local sw, sh = SCREEN_W, SCREEN_H
	local margin = OFFSCREEN_MARGIN

	for _, npc in ipairs(npcs) do
		-- Distance check from player (squared to avoid sqrt)
		local dx = npc.x - player_x
		local dy = npc.y - player_y
		local dist_sq = dx * dx + dy * dy

		-- Initialize offscreen update time if not present
		if not npc.offscreen_update_time then
			npc.offscreen_update_time = now
		end

		-- Check if within update distance
		local within_distance = dist_sq <= update_dist_sq

		if within_distance then
			-- Within distance: check visibility for throttling
			local sx = npc.x - cam_x + cx
			local sy = npc.y - cam_y + cy
			local is_visible = sx > -margin and sx < sw + margin and
			                   sy > -margin and sy < sh + margin

			if is_visible then
				-- Visible and within distance: update every frame
				update_npc(npc, player_x, player_y)
				npc.offscreen_update_time = now
			else
				-- Offscreen but within distance: throttled update
				if now >= npc.offscreen_update_time + offscreen_interval then
					update_npc(npc, nil, nil)
					npc.offscreen_update_time = now
				end
			end
		else
			-- Beyond distance: only update when interval elapses
			if now >= npc.offscreen_update_time + offscreen_interval then
				update_npc(npc, nil, nil)
				npc.offscreen_update_time = now
			end
		end
	end
end

-- Mode 2: Streaming NPCs - despawn far, respawn near
local function update_npcs_streaming(player_x, player_y)
	local cfg = NPC_CONFIG
	local despawn_dist = cfg.despawn_distance
	local despawn_dist_sq = despawn_dist * despawn_dist
	local target_count = cfg.target_npc_count

	-- Cache screen constants for inline visibility
	local cx, cy = SCREEN_CX, SCREEN_CY
	local sw, sh = SCREEN_W, SCREEN_H
	local margin = OFFSCREEN_MARGIN

	-- Pass 1: Update visible NPCs, mark distant ones for removal
	local to_remove = {}
	for i, npc in ipairs(npcs) do
		local dx = npc.x - player_x
		local dy = npc.y - player_y
		local dist_sq = dx * dx + dy * dy

		if dist_sq > despawn_dist_sq then
			-- Too far, mark for removal
			add(to_remove, i)
		else
			-- Check visibility
			local sx = npc.x - cam_x + cx
			local sy = npc.y - cam_y + cy
			local is_visible = sx > -margin and sx < sw + margin and
			                   sy > -margin and sy < sh + margin

			if is_visible then
				-- Visible: update every frame
				update_npc(npc, player_x, player_y)
			end
			-- Offscreen NPCs within despawn distance: don't update (frozen)
		end
	end

	-- Pass 2: Remove distant NPCs (iterate backwards to preserve indices)
	for i = #to_remove, 1, -1 do
		deli(npcs, to_remove[i])
	end

	-- Pass 3: Spawn new NPCs if below target count
	local spawn_needed = target_count - #npcs
	for i = 1, spawn_needed do
		local new_npc = spawn_npc_near_player(player_x, player_y)
		if new_npc then
			add(npcs, new_npc)
		end
	end
end

-- Update all NPCs using the configured mode
function update_npcs(player_x, player_y)
	if NPC_CONFIG.update_mode == 2 then
		update_npcs_streaming(player_x, player_y)
	else
		update_npcs_persistent(player_x, player_y)
	end
end

-- Get the current sprite for an NPC
function get_npc_sprite(npc)
	if npc.damaged then
		return npc.npc_type.damaged
	end

	-- Use normal directional sprites for all states (including surprised/fleeing)
	local dir_sprites = npc.npc_type[npc.facing_dir]
	if npc.walk_frame == 0 then
		return dir_sprites.idle
	else
		return dir_sprites.walk[npc.walk_frame]
	end
end

-- Check if NPC should show surprise exclamation
function npc_shows_surprise(npc)
	return npc.show_surprise
end

-- Get NPC sprite width
function get_npc_width(npc)
	return npc.npc_type.w
end

-- Get NPC sprite height
function get_npc_height(npc)
	return npc.npc_type.h
end
