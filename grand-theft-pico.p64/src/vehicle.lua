--[[pod_format="raw"]]
-- vehicle.lua - Vehicle AI, rendering, and player interaction

-- Global vehicle list
vehicles = {}

-- Player vehicle state (nil = on foot, reference = in vehicle)
player_vehicle = nil

-- Directions for vehicle movement
local VEHICLE_DIRS = { "north", "south", "east", "west" }
local VEHICLE_DIR_VECTORS = {
	north = { dx = 0, dy = -1 },
	south = { dx = 0, dy = 1 },
	east  = { dx = 1, dy = 0 },
	west  = { dx = -1, dy = 0 },
}

-- ============================================
-- VEHICLE CREATION
-- ============================================

-- Offscreen update throttling settings (like NPCs)
local VEHICLE_OFFSCREEN_MARGIN = 64
local VEHICLE_OFFSCREEN_UPDATE_INTERVAL = 5  -- seconds between updates for offscreen vehicles
local VEHICLE_UPDATE_DISTANCE = 400  -- pixels from player; vehicles beyond this get throttled
local VEHICLE_FLEE_DURATION = 10  -- seconds to flee after being hit by player

-- Cooldown to prevent immediately re-stealing after exiting
local vehicle_exit_cooldown = 0

-- Respawn queue for destroyed vehicles (list of {respawn_time, vehicle_type, is_boat})
local vehicle_respawn_queue = {}

-- Collision effects (visual feedback when hitting cars)
-- Each entry: {x, y, end_time}
local collision_effects = {}

-- Create a new vehicle at a given position
function create_vehicle(x, y, vehicle_type_name, facing_dir)
	local vtype = VEHICLE_CONFIG.types[vehicle_type_name]
	if not vtype then
		vtype = VEHICLE_CONFIG.types.truck  -- fallback
	end

	local now = time()
	local health = vtype.health

	return {
		x = x,
		y = y,
		vtype = vtype,
		facing_dir = facing_dir or "east",
		state = "driving",       -- "driving", "waiting", "stopped", "fleeing", "destroyed", "exploding"
		health = health,
		max_health = health,
		is_player_vehicle = false,
		-- AI state
		target_dir = facing_dir or "east",
		wait_time = 0,           -- time to wait at red light
		last_update_time = now,
		offscreen_update_time = now,  -- for throttling offscreen vehicles
		-- Precomputed route (list of upcoming directions)
		route = {},              -- precomputed route directions
		route_distance = 0,      -- distance traveled since last route update
		-- Fleeing state
		flee_end_time = 0,       -- when to stop fleeing
		-- Road lane tracking (drive on right side)
		lane_offset = 0,         -- offset from road center to stay in lane
		-- Animation state
		fire_frame = 1,
		fire_timer = now,
		explosion_frame = 1,
		explosion_timer = now,
		-- Collision cooldown (prevent rapid damage)
		last_collision_time = 0,
		-- Current speed (for acceleration)
		current_speed = 0,
	}
end

-- ============================================
-- VEHICLE SPAWNING
-- ============================================

-- Get a random point on a MAIN road for vehicle spawning (no dirt roads)
function get_random_road_point()
	local cfg = MAP_CONFIG
	local tile_size = cfg.tile_size
	local map_w = cfg.map_width
	local map_h = cfg.map_height
	local half_w = map_w / 2
	local half_h = map_h / 2

	-- World coordinate bounds
	local min_wx = -half_w * tile_size
	local max_wx = half_w * tile_size
	local min_wy = -half_h * tile_size
	local max_wy = half_h * tile_size

	-- Try random positions until we find a MAIN road (not dirt)
	for attempt = 1, 100 do
		local wx = min_wx + rnd(max_wx - min_wx)
		local wy = min_wy + rnd(max_wy - min_wy)

		if is_on_main_road(wx, wy) then
			return wx, wy
		end
	end

	-- Fallback: return world center (should be on road)
	return 0, 0
end

-- Cache of known water positions (built once on first call)
local water_positions_cache = nil

-- Build cache of water tile positions from tilemap
function build_water_positions_cache()
	if water_positions_cache then return end

	water_positions_cache = {}

	if not WORLD_DATA or not WORLD_DATA.tiles then return end

	local cfg = MAP_CONFIG
	local tile_size = cfg.tile_size
	local map_w = cfg.map_width
	local map_h = cfg.map_height
	local half_w = map_w / 2
	local half_h = map_h / 2
	local tiles = WORLD_DATA.tiles

	-- Scan tilemap for water tiles
	for my = 0, map_h - 1 do
		for mx = 0, map_w - 1 do
			if tiles:get(mx, my) == MAP_TILE_WATER then
				-- Convert to world coordinates (center of tile)
				local wx = (mx - half_w) * tile_size + tile_size / 2
				local wy = (my - half_h) * tile_size + tile_size / 2
				add(water_positions_cache, { x = wx, y = wy })
			end
		end
	end

	printh("Built water cache with " .. #water_positions_cache .. " water tiles")
end

-- Get a random point on water for boat spawning
function get_random_water_point()
	-- Build cache if needed
	build_water_positions_cache()

	-- If we have cached water positions, pick one randomly
	if water_positions_cache and #water_positions_cache > 0 then
		local idx = flr(rnd(#water_positions_cache)) + 1
		local pos = water_positions_cache[idx]
		return pos.x, pos.y
	end

	-- Fallback: random sampling (in case cache failed)
	local cfg = MAP_CONFIG
	local tile_size = cfg.tile_size
	local map_w = cfg.map_width
	local map_h = cfg.map_height
	local half_w = map_w / 2
	local half_h = map_h / 2

	local min_wx = -half_w * tile_size
	local max_wx = half_w * tile_size
	local min_wy = -half_h * tile_size
	local max_wy = half_h * tile_size

	for attempt = 1, 100 do
		local wx = min_wx + rnd(max_wx - min_wx)
		local wy = min_wy + rnd(max_wy - min_wy)

		if is_water(wx, wy) then
			return wx, wy
		end
	end

	-- No water found
	return nil, nil
end

-- Check if position is too close to any existing vehicle
function is_too_close_to_vehicles(x, y, min_distance)
	for _, v in ipairs(vehicles) do
		local dx = v.x - x
		local dy = v.y - y
		local dist_sq = dx * dx + dy * dy
		if dist_sq < min_distance * min_distance then
			return true
		end
	end
	return false
end

-- Spawn vehicles on roads
function spawn_vehicles()
	vehicles = {}
	local cfg = VEHICLE_CONFIG

	-- Get available vehicle types (excluding boats)
	local road_types = { "truck", "van" }

	-- Spawn road vehicles
	for i = 1, cfg.max_vehicles do
		local x, y = get_random_road_point()
		-- Ensure vehicles are spread out
		if not is_too_close_to_vehicles(x, y, 64) then
			local vtype_name = road_types[flr(rnd(#road_types)) + 1]
			-- Determine initial direction based on road orientation
			local dir = get_road_direction_at(x, y)
			local vehicle = create_vehicle(x, y, vtype_name, dir)
			add(vehicles, vehicle)
		end
	end

	-- Spawn boats on water
	local boats_spawned = 0
	for i = 1, cfg.max_boats do
		local x, y = get_random_water_point()
		-- Check that we actually found water
		if x and y and is_water(x, y) and not is_too_close_to_vehicles(x, y, 64) then
			local dirs = { "north", "south", "east", "west" }
			local dir = dirs[flr(rnd(4)) + 1]
			local boat = create_vehicle(x, y, "boat", dir)
			add(vehicles, boat)
			boats_spawned = boats_spawned + 1
		end
	end

	printh("Spawned " .. #vehicles .. " vehicles (" .. boats_spawned .. " boats)")
end

-- Spawn a replacement vehicle far from the player
-- Returns true if successful, false if no valid spawn point found
function spawn_replacement_vehicle(vehicle_type, is_boat, player_x, player_y)
	local cfg = VEHICLE_CONFIG
	local min_dist = cfg.min_respawn_distance
	local min_dist_sq = min_dist * min_dist

	-- Try to find a spawn point at least min_respawn_distance from player
	for attempt = 1, 50 do
		local x, y
		if is_boat then
			x, y = get_random_water_point()
		else
			x, y = get_random_road_point()
		end

		-- Check distance from player
		local dx = x - player_x
		local dy = y - player_y
		local dist_sq = dx * dx + dy * dy

		if dist_sq >= min_dist_sq then
			-- Check not too close to other vehicles
			if not is_too_close_to_vehicles(x, y, 64) then
				local dir
				if is_boat then
					local dirs = { "north", "south", "east", "west" }
					dir = dirs[flr(rnd(4)) + 1]
				else
					dir = get_road_direction_at(x, y)
				end
				local vehicle = create_vehicle(x, y, vehicle_type, dir)
				add(vehicles, vehicle)
				return true
			end
		end
	end

	return false  -- couldn't find a valid spawn point
end

-- Process the respawn queue and clean up destroyed vehicles
function process_vehicle_respawns(player_x, player_y)
	local now = time()

	-- Process respawn queue
	local i = 1
	while i <= #vehicle_respawn_queue do
		local entry = vehicle_respawn_queue[i]
		if now >= entry.respawn_time then
			-- Try to spawn replacement
			spawn_replacement_vehicle(entry.vehicle_type, entry.is_boat, player_x, player_y)
			del(vehicle_respawn_queue, entry)
			-- Don't increment i since we removed an element
		else
			i = i + 1
		end
	end

	-- Clean up destroyed vehicles (remove from list after a delay)
	local cleanup_delay = 5  -- seconds to keep wreckage visible
	i = 1
	while i <= #vehicles do
		local v = vehicles[i]
		if v.state == "destroyed" and v.destroyed_time and now >= v.destroyed_time + cleanup_delay then
			del(vehicles, v)
			-- Don't increment i since we removed an element
		else
			i = i + 1
		end
	end
end

-- Road orientation cache (cleared each frame to prevent stale data)
local road_orientation_cache = {}
local road_orientation_cache_frame = -1

-- Check if a road at position is primarily N-S (vertical) or E-W (horizontal)
-- Returns "ns", "ew", or "intersection" or nil
-- OPTIMIZED: Uses tile-based caching to avoid repeated lookups
-- Uses MAIN roads only (no dirt roads for vehicles)
function get_road_orientation_at(wx, wy)
	-- Clear cache each frame
	local current_frame = time()
	if current_frame ~= road_orientation_cache_frame then
		road_orientation_cache = {}
		road_orientation_cache_frame = current_frame
	end

	-- Use tile-aligned coordinates for cache key (reduce cache entries)
	local tile_x = flr(wx / 16)
	local tile_y = flr(wy / 16)
	local cache_key = tile_x * 10000 + tile_y

	-- Check cache
	local cached = road_orientation_cache[cache_key]
	if cached ~= nil then
		return cached ~= false and cached or nil
	end

	-- Not in cache, compute it (use main road only)
	if not is_on_main_road(wx, wy) then
		road_orientation_cache[cache_key] = false
		return nil
	end

	local has_road_n = is_on_main_road(wx, wy - 16)
	local has_road_s = is_on_main_road(wx, wy + 16)
	local has_road_e = is_on_main_road(wx + 16, wy)
	local has_road_w = is_on_main_road(wx - 16, wy)

	local ns_connected = has_road_n or has_road_s
	local ew_connected = has_road_e or has_road_w

	local result
	if ns_connected and ew_connected then
		result = "intersection"
	elseif ns_connected then
		result = "ns"
	elseif ew_connected then
		result = "ew"
	else
		result = false
	end

	road_orientation_cache[cache_key] = result
	return result ~= false and result or nil
end

-- Get the road direction at a position (for initial vehicle facing)
-- Returns direction AND lane offset for right-side driving
function get_road_direction_at(wx, wy)
	local orientation = get_road_orientation_at(wx, wy)

	if orientation == "ns" then
		-- North-South road: vehicles go north or south
		-- Right-side driving: east side goes south, west side goes north
		return rnd(1) > 0.5 and "north" or "south"
	elseif orientation == "ew" then
		-- East-West road: vehicles go east or west
		-- Right-side driving: south side goes east, north side goes west
		return rnd(1) > 0.5 and "east" or "west"
	elseif orientation == "intersection" then
		-- At intersection, pick random direction
		local dirs = { "north", "south", "east", "west" }
		return dirs[flr(rnd(#dirs)) + 1]
	end

	-- Default to east
	return "east"
end

-- Get the lane offset for right-side driving based on direction
-- Positive offset = right side of road center
function get_lane_offset_for_direction(dir)
	local lane_offset = 12  -- offset from road center (road width is ~64, so 12px each side)
	if dir == "north" then
		return lane_offset, 0   -- drive on east side (right when going north)
	elseif dir == "south" then
		return -lane_offset, 0  -- drive on west side (right when going south)
	elseif dir == "east" then
		return 0, lane_offset   -- drive on south side (right when going east)
	elseif dir == "west" then
		return 0, -lane_offset  -- drive on north side (right when going west)
	end
	return 0, 0
end

-- ============================================
-- VEHICLE AI UPDATE
-- ============================================

-- Check if vehicle can proceed (traffic light check)
function can_vehicle_proceed(vehicle)
	-- If at an intersection, check traffic lights
	if is_at_intersection(vehicle.x, vehicle.y) then
		return can_cross_in_direction(vehicle.facing_dir)
	end
	return true
end

-- Check if there's another vehicle ahead (in same lane)
-- OPTIMIZED: Only checks vehicles within reasonable distance
function vehicle_ahead(vehicle, distance)
	local vec = VEHICLE_DIR_VECTORS[vehicle.facing_dir]
	local check_x = vehicle.x + vec.dx * distance
	local check_y = vehicle.y + vec.dy * distance

	-- Pre-calculate max check distance to skip far vehicles early
	local max_dist_sq = (distance + 32) * (distance + 32)

	for _, other in ipairs(vehicles) do
		if other ~= vehicle and other.state ~= "destroyed" and other.state ~= "exploding" then
			-- Quick distance check first (skip far vehicles)
			local rough_dx = other.x - vehicle.x
			local rough_dy = other.y - vehicle.y
			local rough_dist_sq = rough_dx * rough_dx + rough_dy * rough_dy
			if rough_dist_sq > max_dist_sq then
				goto continue
			end

			local dx = abs(other.x - check_x)
			local dy = abs(other.y - check_y)
			-- Check if other vehicle is in the way (tighter check for same lane)
			-- For N/S movement, check Y distance more strictly
			-- For E/W movement, check X distance more strictly
			local in_way = false
			if vehicle.facing_dir == "north" or vehicle.facing_dir == "south" then
				-- Moving vertically - check if other is in our lane (similar X)
				if dx < 16 and dy < 24 then
					in_way = true
				end
			else
				-- Moving horizontally - check if other is in our lane (similar Y)
				if dx < 24 and dy < 16 then
					in_way = true
				end
			end
			if in_way then
				return other
			end
			::continue::
		end
	end
	return nil
end

-- Precompute a route of upcoming directions for a vehicle
-- This computes several waypoints so we don't recalculate each frame
function precompute_vehicle_route(vehicle, num_waypoints)
	vehicle.route = {}
	vehicle.route_distance = 0

	local sim_x, sim_y = vehicle.x, vehicle.y
	local sim_dir = vehicle.facing_dir

	for i = 1, num_waypoints do
		-- Find the next direction at the next intersection
		local vec = VEHICLE_DIR_VECTORS[sim_dir]
		-- Move to approximate next intersection (every ~128 pixels)
		sim_x = sim_x + vec.dx * 128
		sim_y = sim_y + vec.dy * 128

		-- Get valid direction at this simulated position
		local new_dir = pick_single_direction(sim_x, sim_y, sim_dir)
		add(vehicle.route, new_dir)
		sim_dir = new_dir
	end
end

-- Pick a single direction from a position (for route precomputation)
function pick_single_direction(wx, wy, current_dir)
	local orientation = get_road_orientation_at(wx, wy)

	-- If at intersection or no orientation, pick based on weighted random
	if orientation == "intersection" or not orientation then
		-- 70% chance to continue straight
		if rnd(1) < 0.7 then
			return current_dir
		end
		-- Random turn (but not reverse)
		local dirs = {}
		for _, dir in ipairs(VEHICLE_DIRS) do
			if dir ~= current_dir then
				local is_reverse = (dir == "north" and current_dir == "south") or
				                   (dir == "south" and current_dir == "north") or
				                   (dir == "east" and current_dir == "west") or
				                   (dir == "west" and current_dir == "east")
				if not is_reverse then
					add(dirs, dir)
				end
			end
		end
		if #dirs > 0 then
			return dirs[flr(rnd(#dirs)) + 1]
		end
		return current_dir
	end

	-- Match road orientation
	if orientation == "ns" then
		if current_dir == "north" or current_dir == "south" then
			return current_dir
		end
		return rnd(1) > 0.5 and "north" or "south"
	elseif orientation == "ew" then
		if current_dir == "east" or current_dir == "west" then
			return current_dir
		end
		return rnd(1) > 0.5 and "east" or "west"
	end

	return current_dir
end

-- Pick a new direction at an intersection
-- Only picks directions that match the road orientation at the destination
-- OPTIMIZED: Minimized road surface checks, prioritize straight first
function pick_new_vehicle_direction(vehicle)
	local valid_dirs = {}
	local current_dir = vehicle.facing_dir

	-- Check straight direction first (most common case)
	local straight_vec = VEHICLE_DIR_VECTORS[current_dir]
	local straight_x = vehicle.x + straight_vec.dx * 48
	local straight_y = vehicle.y + straight_vec.dy * 48

	local straight_orientation = get_road_orientation_at(straight_x, straight_y)
	if straight_orientation then
		local straight_valid = (straight_orientation == "intersection") or
			(straight_orientation == "ns" and (current_dir == "north" or current_dir == "south")) or
			(straight_orientation == "ew" and (current_dir == "east" or current_dir == "west"))
		if straight_valid then
			-- 70% chance to go straight
			if rnd(1) < 0.7 then
				return current_dir
			end
			add(valid_dirs, current_dir)
		end
	end

	-- Check other directions (exclude reverse)
	for _, dir in ipairs(VEHICLE_DIRS) do
		if dir == current_dir then goto continue end

		-- Skip reverse direction initially
		local is_reverse = (dir == "north" and current_dir == "south") or
		                   (dir == "south" and current_dir == "north") or
		                   (dir == "east" and current_dir == "west") or
		                   (dir == "west" and current_dir == "east")
		if is_reverse then goto continue end

		local dir_vec = VEHICLE_DIR_VECTORS[dir]
		local test_x = vehicle.x + dir_vec.dx * 48
		local test_y = vehicle.y + dir_vec.dy * 48

		local dest_orientation = get_road_orientation_at(test_x, test_y)
		if dest_orientation then
			local dir_valid = (dest_orientation == "intersection") or
				(dest_orientation == "ns" and (dir == "north" or dir == "south")) or
				(dest_orientation == "ew" and (dir == "east" or dir == "west"))
			if dir_valid then
				add(valid_dirs, dir)
			end
		end
		::continue::
	end

	-- If no valid dirs, allow reverse
	if #valid_dirs == 0 then
		local reverse_dir = nil
		if current_dir == "north" then reverse_dir = "south"
		elseif current_dir == "south" then reverse_dir = "north"
		elseif current_dir == "east" then reverse_dir = "west"
		elseif current_dir == "west" then reverse_dir = "east"
		end

		if reverse_dir then
			local rev_vec = VEHICLE_DIR_VECTORS[reverse_dir]
			local rev_x = vehicle.x + rev_vec.dx * 48
			local rev_y = vehicle.y + rev_vec.dy * 48
			local rev_orientation = get_road_orientation_at(rev_x, rev_y)
			if rev_orientation then
				local rev_valid = (rev_orientation == "intersection") or
					(rev_orientation == "ns" and (reverse_dir == "north" or reverse_dir == "south")) or
					(rev_orientation == "ew" and (reverse_dir == "east" or reverse_dir == "west"))
				if rev_valid then
					add(valid_dirs, reverse_dir)
				end
			end
		end
	end

	if #valid_dirs > 0 then
		return valid_dirs[flr(rnd(#valid_dirs)) + 1]
	end

	return current_dir  -- fallback
end

-- Update a single AI vehicle
function update_vehicle_ai(vehicle, dt)
	if vehicle.is_player_vehicle then return end  -- skip player-controlled vehicles
	if vehicle.state == "destroyed" then return end
	if vehicle.state == "exploding" then return end

	local vtype = vehicle.vtype
	local now = time()

	-- Check if fleeing state should end
	if vehicle.state == "fleeing" then
		if now >= vehicle.flee_end_time then
			vehicle.state = "driving"
			-- Precompute new route after calming down
			precompute_vehicle_route(vehicle, 5)
		end
	end

	-- Calculate speed (fleeing = faster)
	local speed_mult = vehicle.state == "fleeing" and VEHICLE_CONFIG.flee_speed_multiplier or 1.0
	local speed = vtype.speed * speed_mult * dt
	local vec = VEHICLE_DIR_VECTORS[vehicle.facing_dir]

	-- Boats have simpler AI (just go back and forth on water)
	if vtype.water_only then
		local new_x = vehicle.x + vec.dx * speed
		local new_y = vehicle.y + vec.dy * speed

		-- Check if still on water
		if is_water(new_x, new_y) then
			vehicle.x = new_x
			vehicle.y = new_y
		else
			-- Pick a new direction that leads to water
			local dirs = { "north", "south", "east", "west" }
			local valid_dirs = {}
			for _, d in ipairs(dirs) do
				if d ~= vehicle.facing_dir then
					local dv = VEHICLE_DIR_VECTORS[d]
					local test_x = vehicle.x + dv.dx * 16
					local test_y = vehicle.y + dv.dy * 16
					if is_water(test_x, test_y) then
						add(valid_dirs, d)
					end
				end
			end
			-- Pick random valid direction, or just turn around
			if #valid_dirs > 0 then
				vehicle.facing_dir = valid_dirs[flr(rnd(#valid_dirs)) + 1]
			else
				-- No valid direction, turn around
				local opposite = { north = "south", south = "north", east = "west", west = "east" }
				vehicle.facing_dir = opposite[vehicle.facing_dir]
			end
		end
		return
	end

	-- Fleeing vehicles ignore traffic rules
	if vehicle.state == "fleeing" then
		-- Just drive fast, ignore lights, avoid collisions
		local ahead = vehicle_ahead(vehicle, 30)
		if ahead then
			-- Quick turn to avoid
			local dirs = { "north", "south", "east", "west" }
			for _, d in ipairs(dirs) do
				if d ~= vehicle.facing_dir then
					local dv = VEHICLE_DIR_VECTORS[d]
					local tx = vehicle.x + dv.dx * 48
					local ty = vehicle.y + dv.dy * 48
					if is_on_main_road(tx, ty) then
						vehicle.facing_dir = d
						break
					end
				end
			end
		end

		local target_x = vehicle.x + vec.dx * speed
		local target_y = vehicle.y + vec.dy * speed

		if is_on_main_road(target_x, target_y) then
			vehicle.x = target_x
			vehicle.y = target_y
		else
			-- Bounce off edge
			if vehicle.facing_dir == "north" then vehicle.facing_dir = "south"
			elseif vehicle.facing_dir == "south" then vehicle.facing_dir = "north"
			elseif vehicle.facing_dir == "east" then vehicle.facing_dir = "west"
			elseif vehicle.facing_dir == "west" then vehicle.facing_dir = "east"
			end
		end
		return
	end

	-- Road vehicle AI (normal driving)
	if vehicle.state == "waiting" then
		-- Waiting at red light
		if can_vehicle_proceed(vehicle) then
			vehicle.state = "driving"
		end
		return
	end

	-- Check for vehicle ahead (stop if there's one close)
	local ahead = vehicle_ahead(vehicle, 40)
	if ahead then
		-- Stop behind other vehicle
		vehicle.state = "stopped"
		return
	else
		if vehicle.state == "stopped" then
			vehicle.state = "driving"
		end
	end

	-- Track distance traveled for route consumption
	vehicle.route_distance = vehicle.route_distance + speed

	-- Get road orientation at CURRENT position
	local road_orientation = get_road_orientation_at(vehicle.x, vehicle.y)

	-- If on a straight road (not intersection), ensure direction matches road
	-- This prevents changing between N/S and E/W on straight roads
	if road_orientation == "ns" then
		if vehicle.facing_dir ~= "north" and vehicle.facing_dir ~= "south" then
			-- Force to match road orientation
			vehicle.facing_dir = rnd(1) > 0.5 and "north" or "south"
		end
	elseif road_orientation == "ew" then
		if vehicle.facing_dir ~= "east" and vehicle.facing_dir ~= "west" then
			-- Force to match road orientation
			vehicle.facing_dir = rnd(1) > 0.5 and "east" or "west"
		end
	end

	-- Check if APPROACHING intersection (look ahead) - stop BEFORE entering if red
	local look_ahead_dist = 24  -- distance to look ahead for intersection
	local ahead_x = vehicle.x + vec.dx * look_ahead_dist
	local ahead_y = vehicle.y + vec.dy * look_ahead_dist
	local ahead_orientation = get_road_orientation_at(ahead_x, ahead_y)

	-- If we're NOT at intersection but approaching one, check traffic light
	if road_orientation ~= "intersection" and ahead_orientation == "intersection" then
		if not can_vehicle_proceed(vehicle) then
			vehicle.state = "waiting"
			return
		end
	end

	-- If AT intersection, can change direction using precomputed route
	if road_orientation == "intersection" then
		-- Use precomputed route at intersections (every ~128 pixels)
		if vehicle.route_distance >= 128 then
			vehicle.route_distance = 0
			if #vehicle.route > 0 then
				vehicle.facing_dir = vehicle.route[1]
				del(vehicle.route, vehicle.route[1])

				-- Replenish route if running low
				if #vehicle.route < 2 then
					precompute_vehicle_route(vehicle, 5)
				end
			else
				-- No route, compute one
				precompute_vehicle_route(vehicle, 5)
			end
		end
	end

	-- Calculate lane offset for right-side driving
	local lane_ox, lane_oy = get_lane_offset_for_direction(vehicle.facing_dir)

	-- Move forward with lane offset correction
	local target_x = vehicle.x + vec.dx * speed
	local target_y = vehicle.y + vec.dy * speed

	-- Gradually steer towards the correct lane
	local lane_correction_speed = 0.1
	if road_orientation ~= "intersection" then
		if vehicle.facing_dir == "north" or vehicle.facing_dir == "south" then
			target_x = target_x + lane_ox * lane_correction_speed
		else
			target_y = target_y + lane_oy * lane_correction_speed
		end
	end

	-- Check if still on MAIN road (not dirt)
	if is_on_main_road(target_x, target_y) then
		vehicle.x = target_x
		vehicle.y = target_y
	else
		-- Hit edge of road or dead end - turn around
		if vehicle.facing_dir == "north" then vehicle.facing_dir = "south"
		elseif vehicle.facing_dir == "south" then vehicle.facing_dir = "north"
		elseif vehicle.facing_dir == "east" then vehicle.facing_dir = "west"
		elseif vehicle.facing_dir == "west" then vehicle.facing_dir = "east"
		end
		-- Recalculate route
		precompute_vehicle_route(vehicle, 5)
	end
end

-- Update player-controlled vehicle
function update_player_vehicle(vehicle, dt)
	local vtype = vehicle.vtype
	local cfg = VEHICLE_CONFIG
	local max_speed = vtype.speed * cfg.player_speed_multiplier  -- max speed from config

	-- Get input direction
	local dx, dy = 0, 0
	if btn(0) then dx = -1 end  -- left
	if btn(1) then dx = 1 end   -- right
	if btn(2) then dy = -1 end  -- up
	if btn(3) then dy = 1 end   -- down

	local is_moving = dx ~= 0 or dy ~= 0

	-- Handle acceleration/deceleration
	if is_moving then
		-- Accelerate towards max speed
		vehicle.current_speed = vehicle.current_speed + cfg.acceleration * dt
		if vehicle.current_speed > max_speed then
			vehicle.current_speed = max_speed
		end
	else
		-- Decelerate towards zero
		vehicle.current_speed = vehicle.current_speed - cfg.deceleration * dt
		if vehicle.current_speed < 0 then
			vehicle.current_speed = 0
		end
	end

	-- Apply movement if we have speed
	if vehicle.current_speed > 0 then
		-- Update facing direction based on input (only if pressing keys)
		if is_moving then
			if abs(dx) > abs(dy) then
				vehicle.facing_dir = dx > 0 and "east" or "west"
			else
				vehicle.facing_dir = dy > 0 and "south" or "north"
			end
		end

		-- Use facing direction for movement (not raw input)
		local vec = VEHICLE_DIR_VECTORS[vehicle.facing_dir]
		local speed = vehicle.current_speed * dt

		local new_x = vehicle.x + vec.dx * speed
		local new_y = vehicle.y + vec.dy * speed

		-- Check terrain validity
		local valid_terrain = false
		if vtype.water_only then
			valid_terrain = is_water(new_x, new_y)
		else
			valid_terrain = is_on_road_surface(new_x, new_y) or is_on_sidewalk(new_x, new_y) or is_on_grass(new_x, new_y)
			-- Don't go in water
			if is_water(new_x, new_y) then valid_terrain = false end
		end

		-- Check building collision
		local collides_building = false
		for _, b in ipairs(buildings) do
			if new_x + 16 > b.x and new_x - 16 < b.x + b.w and
			   new_y + 8 > b.y and new_y - 8 < b.y + b.h then
				collides_building = true
				break
			end
		end

		if valid_terrain and not collides_building then
			vehicle.x = new_x
			vehicle.y = new_y
		else
			-- Hit something, stop immediately
			vehicle.current_speed = 0
		end
	end

	-- Exit vehicle with E key
	if keyp(VEHICLE_CONFIG.steal_key) then
		exit_vehicle()
	end
end

-- ============================================
-- VEHICLE COLLISION
-- ============================================

-- Check and handle vehicle-to-vehicle collisions (OPTIMIZED: only nearby vehicles)
function check_vehicle_collisions(visible_vehicles)
	local now = time()
	local cfg = VEHICLE_CONFIG
	local count = #visible_vehicles

	for i = 1, count do
		local v1 = visible_vehicles[i]
		if v1.state ~= "destroyed" and v1.state ~= "exploding" then
			local w1 = v1.vtype.w / 2
			local h1 = v1.vtype.h / 2

			for j = i + 1, count do
				local v2 = visible_vehicles[j]
				if v2.state ~= "destroyed" and v2.state ~= "exploding" then
					-- Simple AABB collision
					local w2 = v2.vtype.w / 2
					local h2 = v2.vtype.h / 2

					if abs(v1.x - v2.x) < w1 + w2 and abs(v1.y - v2.y) < h1 + h2 then
						-- Spawn collision effect if player is involved (only once per cooldown)
						local player_involved = v1.is_player_vehicle or v2.is_player_vehicle
						local effect_spawned = false

						-- Collision! Apply damage if cooldown elapsed
						if now - v1.last_collision_time > 0.5 then
							v1.health = v1.health - cfg.damage_per_collision
							v1.last_collision_time = now

							-- Spawn effect once when damage is applied
							if player_involved and not effect_spawned then
								local cx = (v1.x + v2.x) / 2
								local cy = (v1.y + v2.y) / 2
								add(collision_effects, { x = cx, y = cy, end_time = now + 0.5 })
								effect_spawned = true
							end

							-- If hit by player, start fleeing
							if v2.is_player_vehicle and v1.state ~= "fleeing" then
								v1.state = "fleeing"
								v1.flee_end_time = now + VEHICLE_FLEE_DURATION
							end
						end
						if now - v2.last_collision_time > 0.5 then
							v2.health = v2.health - cfg.damage_per_collision
							v2.last_collision_time = now

							-- Spawn effect once when damage is applied
							if player_involved and not effect_spawned then
								local cx = (v1.x + v2.x) / 2
								local cy = (v1.y + v2.y) / 2
								add(collision_effects, { x = cx, y = cy, end_time = now + 0.5 })
								effect_spawned = true
							end

							-- If hit by player, start fleeing
							if v1.is_player_vehicle and v2.state ~= "fleeing" then
								v2.state = "fleeing"
								v2.flee_end_time = now + VEHICLE_FLEE_DURATION
							end
						end

						-- Push vehicles apart
						local dx = v1.x - v2.x
						local dy = v1.y - v2.y
						local dist = sqrt(dx * dx + dy * dy)
						if dist > 0 then
							local push = 2
							v1.x = v1.x + (dx / dist) * push
							v1.y = v1.y + (dy / dist) * push
							v2.x = v2.x - (dx / dist) * push
							v2.y = v2.y - (dy / dist) * push
						end
					end
				end
			end
		end
	end
end

-- Check vehicle collision with NPCs (OPTIMIZED: only visible vehicles)
function check_vehicle_npc_collisions(visible_vehicles)
	local cfg = VEHICLE_CONFIG

	for _, vehicle in ipairs(visible_vehicles) do
		if vehicle.state ~= "destroyed" and vehicle.state ~= "exploding" then
			local vw = vehicle.vtype.w / 2
			local vh = vehicle.vtype.h / 2

			for _, npc in ipairs(npcs) do
				local dx = npc.x - vehicle.x
				local dy = npc.y - vehicle.y

				if abs(dx) < vw + 4 and abs(dy) < vh + 4 then
					-- Push NPC away from vehicle center
					local dist = sqrt(dx * dx + dy * dy)
					if dist > 0 then
						local push_x = (dx / dist) * cfg.npc_push_force * (1/60)
						local push_y = (dy / dist) * cfg.npc_push_force * (1/60)
						npc.x = npc.x + push_x
						npc.y = npc.y + push_y

						-- Make NPC flee if not already
						if npc.state ~= "fleeing" and npc.state ~= "surprised" then
							npc.state = "surprised"
							npc.state_end_time = time() + NPC_CONFIG.surprise_duration
							npc.show_surprise = true
							npc.scare_player_x = vehicle.x
							npc.scare_player_y = vehicle.y
						end
					end
				end
			end
		end
	end
end

-- ============================================
-- VEHICLE DAMAGE AND DESTRUCTION
-- ============================================

-- Update vehicle health/fire/explosion state
function update_vehicle_state(vehicle, dt)
	local now = time()
	local cfg = VEHICLE_CONFIG

	-- Check for destruction
	if vehicle.health <= 0 and vehicle.state ~= "destroyed" and vehicle.state ~= "exploding" then
		vehicle.state = "exploding"
		vehicle.explosion_frame = 1
		vehicle.explosion_timer = now

		-- If player was in this vehicle, exit
		if vehicle.is_player_vehicle then
			player_vehicle = nil
			vehicle.is_player_vehicle = false
		end
	end

	-- Update explosion animation
	if vehicle.state == "exploding" then
		if now >= vehicle.explosion_timer + cfg.explosion_animation_speed then
			vehicle.explosion_frame = vehicle.explosion_frame + 1
			vehicle.explosion_timer = now

			if vehicle.explosion_frame > #cfg.explosion_sprites then
				vehicle.state = "destroyed"
				vehicle.destroyed_time = now  -- track when it was destroyed

				-- Queue respawn if enabled
				if cfg.respawn_enabled then
					local is_boat = vehicle.vtype.water_only or false
					local vtype_name = vehicle.vtype.name or "truck"
					add(vehicle_respawn_queue, {
						respawn_time = now + cfg.respawn_delay,
						vehicle_type = vtype_name,
						is_boat = is_boat,
					})
				end
			end
		end
	end

	-- Update fire animation (for damaged vehicles)
	if vehicle.state ~= "destroyed" and vehicle.state ~= "exploding" then
		if vehicle.health <= cfg.fire_threshold and vehicle.health > 0 then
			if now >= vehicle.fire_timer + cfg.fire_animation_speed then
				vehicle.fire_frame = (vehicle.fire_frame % #cfg.fire_sprites) + 1
				vehicle.fire_timer = now
				-- Slowly drain health when on fire
				vehicle.health = vehicle.health - 1
			end
		end
	end
end

-- ============================================
-- PLAYER VEHICLE INTERACTION
-- ============================================

-- Get nearest stealable vehicle
function get_nearest_stealable_vehicle(px, py)
	local cfg = VEHICLE_CONFIG
	local best_vehicle = nil
	local best_dist = cfg.steal_prompt_distance

	for _, vehicle in ipairs(vehicles) do
		if vehicle.state ~= "destroyed" and vehicle.state ~= "exploding" and not vehicle.is_player_vehicle then
			local dx = vehicle.x - px
			local dy = vehicle.y - py
			local dist = sqrt(dx * dx + dy * dy)
			if dist < best_dist then
				best_dist = dist
				best_vehicle = vehicle
			end
		end
	end

	return best_vehicle
end

-- Steal a vehicle
function steal_vehicle(vehicle)
	if player_vehicle then
		exit_vehicle()
	end

	vehicle.is_player_vehicle = true
	player_vehicle = vehicle

	-- Boost health for player vehicle
	local multiplier = VEHICLE_CONFIG.player_health_multiplier
	vehicle.max_health = vehicle.vtype.health * multiplier
	vehicle.health = min(vehicle.health * multiplier, vehicle.max_health)

	-- Spawn a startled NPC running away (the "driver")
	local npc_type_index = flr(rnd(#NPC_TYPES)) + 1
	local npc = create_npc(vehicle.x, vehicle.y, npc_type_index)
	npc.state = "surprised"
	npc.state_end_time = time() + NPC_CONFIG.surprise_duration
	npc.show_surprise = true
	npc.scare_player_x = vehicle.x
	npc.scare_player_y = vehicle.y
	add(npcs, npc)

	printh("Player stole a " .. vehicle.vtype.name)
end

-- Exit current vehicle
function exit_vehicle()
	if player_vehicle then
		player_vehicle.is_player_vehicle = false
		-- Stop the vehicle (no driver anymore)
		player_vehicle.state = "stopped"
		-- Place player next to vehicle
		game.player.x = player_vehicle.x + 20
		game.player.y = player_vehicle.y
		player_vehicle = nil
		-- Set cooldown to prevent immediately re-stealing
		vehicle_exit_cooldown = time() + 0.5  -- 0.5 second cooldown
		printh("Player exited vehicle")
	end
end

-- ============================================
-- MAIN UPDATE FUNCTION
-- ============================================

function update_vehicles()
	local now = time()
	local player_x = game.player.x
	local player_y = game.player.y

	-- Cache screen constants for visibility check
	local cx, cy = SCREEN_CX, SCREEN_CY
	local sw, sh = SCREEN_W, SCREEN_H
	local margin = VEHICLE_OFFSCREEN_MARGIN
	local update_dist_sq = VEHICLE_UPDATE_DISTANCE * VEHICLE_UPDATE_DISTANCE

	-- Collect visible/nearby vehicles for collision checks
	local visible_vehicles = {}

	for _, vehicle in ipairs(vehicles) do
		-- Calculate distance from player (squared to avoid sqrt)
		local dx = vehicle.x - player_x
		local dy = vehicle.y - player_y
		local dist_sq = dx * dx + dy * dy

		-- Check if visible on screen
		local sx = vehicle.x - cam_x + cx
		local sy = vehicle.y - cam_y + cy
		local is_visible = sx > -margin and sx < sw + margin and
		                   sy > -margin and sy < sh + margin

		-- Track visible vehicles for collision detection
		if is_visible or vehicle.is_player_vehicle then
			add(visible_vehicles, vehicle)
		end

		-- Determine if we should update this frame
		local should_update = false

		if vehicle.is_player_vehicle then
			-- Always update player vehicle
			should_update = true
		elseif is_visible then
			-- Visible vehicles always update
			should_update = true
			vehicle.offscreen_update_time = now
		elseif dist_sq <= update_dist_sq then
			-- Within update distance but offscreen: throttled update
			if now >= vehicle.offscreen_update_time + VEHICLE_OFFSCREEN_UPDATE_INTERVAL then
				should_update = true
				vehicle.offscreen_update_time = now
			end
		else
			-- Far away and offscreen: rarely update
			if now >= vehicle.offscreen_update_time + VEHICLE_OFFSCREEN_UPDATE_INTERVAL * 2 then
				should_update = true
				vehicle.offscreen_update_time = now
			end
		end

		if should_update then
			local dt = now - vehicle.last_update_time
			vehicle.last_update_time = now

			-- Clamp dt to avoid huge jumps
			if dt > 0.1 then dt = 0.1 end

			if vehicle.is_player_vehicle then
				update_player_vehicle(vehicle, dt)
			else
				update_vehicle_ai(vehicle, dt)
			end

			update_vehicle_state(vehicle, dt)
		end
	end

	-- Handle collisions (ONLY for visible/nearby vehicles now)
	check_vehicle_collisions(visible_vehicles)
	check_vehicle_npc_collisions(visible_vehicles)

	-- Process respawns and cleanup destroyed vehicles
	process_vehicle_respawns(player_x, player_y)

	-- Check for vehicle stealing (with cooldown after exiting)
	if not player_vehicle and time() > vehicle_exit_cooldown then
		local nearby = get_nearest_stealable_vehicle(game.player.x, game.player.y)
		if nearby and keyp(VEHICLE_CONFIG.steal_key) then
			steal_vehicle(nearby)
		end
	end
end

-- ============================================
-- VEHICLE RENDERING
-- ============================================

-- Get the current sprite for a vehicle
function get_vehicle_sprite(vehicle)
	local vtype = vehicle.vtype
	local dir = vehicle.facing_dir

	-- Destroyed vehicles show wreckage
	if vehicle.state == "destroyed" then
		return VEHICLE_CONFIG.destroyed_sprite
	end

	-- North/South use the north sprite (rotated visually)
	-- East/West use the east sprite (flip_x for west)
	if dir == "north" or dir == "south" then
		return vtype.sprite_n or vtype.sprite_e
	else
		return vtype.sprite_e
	end
end

-- Check if vehicle sprite should be flipped
function get_vehicle_flip(vehicle)
	local dir = vehicle.facing_dir
	local flip_x = (dir == "west")
	local flip_y = (dir == "south")
	return flip_x, flip_y
end

-- Get vehicle dimensions for current facing direction
function get_vehicle_dimensions(vehicle)
	local vtype = vehicle.vtype
	local dir = vehicle.facing_dir

	-- Swap width/height for north/south facing
	if dir == "north" or dir == "south" then
		return vtype.h, vtype.w  -- swapped
	else
		return vtype.w, vtype.h
	end
end

-- Draw vehicle health bar (called from UI drawing)
function draw_vehicle_health_bar()
	if not player_vehicle then return end

	local cfg = MINIMAP_CONFIG
	local vehicle = player_vehicle

	-- Position next to minimap
	local bar_x = cfg.x + cfg.width + 8
	local bar_y = cfg.y + cfg.height - 10
	local bar_w = 40
	local bar_h = 6

	-- Background
	rectfill(bar_x - 1, bar_y - 1, bar_x + bar_w + 1, bar_y + bar_h + 1, 0)

	-- Health percentage
	local health_pct = vehicle.health / vehicle.max_health
	health_pct = max(0, min(1, health_pct))

	-- Color based on health
	local bar_color = 11  -- green
	if health_pct < 0.3 then
		bar_color = 8  -- red
	elseif health_pct < 0.6 then
		bar_color = 9  -- orange
	end

	-- Health bar fill
	local fill_w = flr(bar_w * health_pct)
	if fill_w > 0 then
		rectfill(bar_x, bar_y, bar_x + fill_w, bar_y + bar_h, bar_color)
	end

	-- Border
	rect(bar_x, bar_y, bar_x + bar_w, bar_y + bar_h, 6)

	-- Label above health bar
	print("CAR", bar_x, bar_y - 8, 7)
end

-- Draw steal prompt when near a vehicle
function draw_steal_prompt()
	if player_vehicle then return end

	local nearby = get_nearest_stealable_vehicle(game.player.x, game.player.y)
	if nearby then
		local sx, sy = world_to_screen(nearby.x, nearby.y)
		-- Draw prompt above vehicle
		local text = "E: STEAL"
		local tw = #text * 4
		print(text, sx - tw/2 + 1, sy - 20 + 1, 0)  -- shadow
		print(text, sx - tw/2, sy - 20, 7)  -- white text
	end
end

-- Draw and update collision effects (explosion frame 1 for 0.5s)
function draw_collision_effects()
	local now = time()
	local exp_spr = VEHICLE_CONFIG.explosion_sprites[2]  -- frame 1 (1-indexed, so [2])

	-- Draw all active effects
	for _, effect in ipairs(collision_effects) do
		if now < effect.end_time then
			local sx, sy = world_to_screen(effect.x, effect.y)
			spr(exp_spr, sx - 8, sy - 8)
		end
	end

	-- Cleanup expired effects
	local i = 1
	while i <= #collision_effects do
		if now >= collision_effects[i].end_time then
			del(collision_effects, collision_effects[i])
		else
			i = i + 1
		end
	end
end
