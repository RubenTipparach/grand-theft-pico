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
	return {
		x = x,
		y = y,
		npc_type = npc_type,
		facing_dir = "south",
		walk_frame = 0,
		walk_timer = 0,
		state = "idle",  -- "idle" or "walking"
		state_timer = 0,
		damaged = false,
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

-- Spawn NPCs on roads
function spawn_npcs(count)
	npcs = {}
	for i = 1, count do
		local x, y = get_random_road_point()
		local npc_type_index = flr(rnd(#NPC_TYPES)) + 1
		add(npcs, create_npc(x, y, npc_type_index))
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

-- Update a single NPC
function update_npc(npc)
	npc.state_timer = npc.state_timer - 1

	if npc.state == "idle" then
		-- Standing still
		npc.walk_frame = 0
		npc.walk_timer = 0

		if npc.state_timer <= 0 then
			-- Time to start walking
			local new_dir = pick_valid_direction(npc)
			if new_dir then
				npc.facing_dir = new_dir
				npc.state = "walking"
				local cfg = NPC_CONFIG.direction_change_time
				npc.state_timer = cfg.min + flr(rnd(cfg.max - cfg.min))
			else
				-- Can't move, stay idle longer
				local cfg = NPC_CONFIG.idle_time
				npc.state_timer = cfg.min + flr(rnd(cfg.max - cfg.min))
			end
		end
	elseif npc.state == "walking" then
		-- Moving
		local vec = DIR_VECTORS[npc.facing_dir]
		local speed = NPC_CONFIG.walk_speed
		local radius = NPC_CONFIG.collision_radius

		local new_x = npc.x + vec.dx * speed
		local new_y = npc.y + vec.dy * speed

		-- Check for collision
		if npc_collides_with_building(new_x, new_y, radius) then
			-- Hit a building, stop and go idle
			npc.state = "idle"
			local cfg = NPC_CONFIG.idle_time
			npc.state_timer = cfg.min + flr(rnd(cfg.max - cfg.min))
		else
			-- Move
			npc.x = new_x
			npc.y = new_y

			-- Update walk animation (3-frame cycle)
			npc.walk_timer = npc.walk_timer + 1
			local anim_speed = NPC_CONFIG.animation_speed
			npc.walk_frame = flr(npc.walk_timer / anim_speed) % 3 + 1
		end

		if npc.state_timer <= 0 then
			-- Time to change direction or stop
			if rnd(1) < 0.3 then
				-- Stop and idle
				npc.state = "idle"
				local cfg = NPC_CONFIG.idle_time
				npc.state_timer = cfg.min + flr(rnd(cfg.max - cfg.min))
			else
				-- Pick a new direction
				local new_dir = pick_valid_direction(npc)
				if new_dir then
					npc.facing_dir = new_dir
					local cfg = NPC_CONFIG.direction_change_time
					npc.state_timer = cfg.min + flr(rnd(cfg.max - cfg.min))
				else
					-- Can't move, go idle
					npc.state = "idle"
					local cfg = NPC_CONFIG.idle_time
					npc.state_timer = cfg.min + flr(rnd(cfg.max - cfg.min))
				end
			end
		end
	end
end

-- Update all NPCs
function update_npcs()
	for _, npc in ipairs(npcs) do
		update_npc(npc)
	end
end

-- Get the current sprite for an NPC
function get_npc_sprite(npc)
	if npc.damaged then
		return npc.npc_type.damaged
	end

	local dir_sprites = npc.npc_type[npc.facing_dir]
	if npc.walk_frame == 0 then
		return dir_sprites.idle
	else
		return dir_sprites.walk[npc.walk_frame]
	end
end

-- Get NPC sprite width
function get_npc_width(npc)
	return npc.npc_type.w
end

-- Get NPC sprite height
function get_npc_height(npc)
	return npc.npc_type.h
end
