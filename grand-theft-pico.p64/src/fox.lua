--[[pod_format="raw"]]
-- fox.lua - Fox enemy system

-- ============================================
-- FOX STATE
-- ============================================

-- Global list of foxes
foxes = {}

-- Whether foxes have been spawned (after quest accepted)
foxes_spawned = false

-- Fox defeated message display
fox_defeated_message = {
	active = false,
	end_time = 0,
	fox_name = "",
	duration = 2.0,  -- seconds to show message
}

-- ============================================
-- FOX CREATION AND SPAWNING
-- ============================================

-- Create a new fox
function create_fox(x, y, name)
	local cfg = FOX_CONFIG

	local fox = {
		x = x,
		y = y,
		name = name,
		health = cfg.health,
		max_health = cfg.health,
		state = "idle",       -- "idle", "chasing", "attacking", "dead"
		facing_right = true,
		walk_frame = 0,
		anim_timer = 0,
		attack_timer = 0,     -- Cooldown for attacks
		hit_flash = 0,        -- Timer for damage flash visual
		damaged_frame = 0,
		damaged_anim_timer = 0,
	}

	add(foxes, fox)
	return fox
end

-- Find a valid spawn position on dirt road outside city center
function find_fox_spawn_position()
	local tile_size = 16

	-- Safety check for world data
	if not WORLD_DATA or not WORLD_DATA.tiles then
		printh("ERROR: find_fox_spawn_position - WORLD_DATA not initialized!")
		-- Fallback: spawn at a random far location
		local angle = rnd(1)
		local dist = 400 + rnd(200)
		return cos(angle) * dist, sin(angle) * dist
	end

	local map_w = WORLD_DATA.tiles:width()
	local map_h = WORLD_DATA.tiles:height()

	-- City center is around 0,0 - spawn foxes far from center
	local min_dist_from_center = 300  -- minimum distance from 0,0

	for attempt = 1, 100 do
		-- Random map position
		local mx = flr(rnd(map_w))
		local my = flr(rnd(map_h))

		-- Convert to world position
		local wx = (mx - map_w / 2) * tile_size
		local wy = (my - map_h / 2) * tile_size

		-- Check distance from center
		local dist = sqrt(wx * wx + wy * wy)
		if dist > min_dist_from_center then
			-- Check if it's a dirt road
			if is_dirt_road_from_map(wx, wy) then
				return wx, wy
			end
			-- Also accept grass tiles far from city
			local tile = get_map_tile_at_world(wx, wy)
			if tile == MAP_TILE_GRASS then
				return wx, wy
			end
		end
	end

	-- Fallback: spawn at a random far location
	local angle = rnd(1)
	local dist = 400 + rnd(200)
	return cos(angle) * dist, sin(angle) * dist
end

-- Spawn all foxes (called after quest is accepted)
function spawn_foxes()
	printh("spawn_foxes() called, foxes_spawned=" .. tostring(foxes_spawned))

	if foxes_spawned then
		printh("Foxes already spawned, returning early")
		return
	end

	local cfg = FOX_CONFIG
	if not cfg then
		printh("ERROR: FOX_CONFIG is nil!")
		return
	end

	printh("FOX_CONFIG.spawn_count=" .. tostring(cfg.spawn_count))

	local name_index = 1

	for i = 1, cfg.spawn_count do
		local x, y = find_fox_spawn_position()
		local name = cfg.names[name_index]
		printh("Creating fox " .. i .. " '" .. tostring(name) .. "' at (" .. tostring(x) .. ", " .. tostring(y) .. ")")
		create_fox(x, y, name)

		name_index = name_index + 1
		if name_index > #cfg.names then
			name_index = 1
		end
	end

	foxes_spawned = true
	mission.total_foxes = cfg.spawn_count
	mission.foxes_killed = 0
	printh("Spawned " .. cfg.spawn_count .. " foxes, #foxes=" .. #foxes)
end

-- Get count of living foxes
function get_living_fox_count()
	local count = 0
	for _, fox in ipairs(foxes) do
		if fox.state ~= "dead" then
			count = count + 1
		end
	end
	return count
end

-- Fire a bullet from fox toward player (same system as dealer)
function fire_fox_bullet(fox)
	local cfg = FOX_CONFIG
	local dealer_cfg = ARMS_DEALER_CONFIG
	local p = game.player

	-- Calculate fox center (sprite is drawn with feet at fox.y)
	local dst_size = cfg.sprite_size * cfg.sprite_scale
	local fox_center_x = fox.x
	local fox_center_y = fox.y - dst_size / 2

	-- Calculate direction to player
	local dx = p.x - fox_center_x
	local dy = p.y - fox_center_y
	local dist = sqrt(dx * dx + dy * dy)

	if dist <= 0 then return end

	-- Normalize
	dx = dx / dist
	dy = dy / dist

	-- Create projectile using same bullet sprites as dealer
	local bullet_sprite = dealer_cfg.bullet_sprites[1]
	local proj = {
		x = fox_center_x,
		y = fox_center_y,
		dx = dx,
		dy = dy,
		speed = cfg.bullet_speed,
		damage = cfg.damage,
		owner = fox,  -- Not "player"
		sprite = bullet_sprite,
		sprite_frames = {
			dealer_cfg.bullet_sprites[1],
			dealer_cfg.bullet_sprites[2],
		},
		frame_index = 1,
		frame_timer = 0,
		animation_speed = 0.1,
	}

	add(projectiles, proj)
end

-- ============================================
-- FOX UPDATE
-- ============================================

-- Update all foxes
function update_foxes()
	if not foxes_spawned then return end

	local now = time()
	local p = game.player
	local cfg = FOX_CONFIG

	for _, fox in ipairs(foxes) do
		if fox.state ~= "dead" then
			-- Calculate distance to player
			local dx = p.x - fox.x
			local dy = p.y - fox.y
			local dist = sqrt(dx * dx + dy * dy)

			-- State transitions based on distance
			if dist <= cfg.aggro_distance then
				-- Player in aggro range - chase!
				if dist > cfg.target_distance then
					fox.state = "chasing"
					-- Move toward player
					local speed = cfg.chase_speed / 60
					fox.x = fox.x + (dx / dist) * speed
					fox.y = fox.y + (dy / dist) * speed
				else
					-- In attack range - fire bullets like dealer
					fox.state = "attacking"
					if now >= fox.attack_timer then
						-- Fire bullet at player (same system as dealer)
						fire_fox_bullet(fox)
						fox.attack_timer = now + cfg.fire_rate
					end
				end
				-- Face toward player
				fox.facing_right = dx >= 0
			else
				-- Player too far - idle/wander
				fox.state = "idle"
			end

			-- Update animation
			update_fox_animation(fox, now)

			-- Check if fox died
			if fox.health <= 0 and fox.state ~= "dead" then
				fox.state = "dead"
				-- Track kill for quest
				mission.foxes_killed = mission.foxes_killed + 1
				-- Small explosion effect
				add_collision_effect(fox.x, fox.y, 0.5)
				-- Show defeated message
				show_fox_defeated(fox.name)
				-- Check if all foxes are dead (quest complete)
				if get_living_fox_count() == 0 and mission.current_quest == "protect_city" then
					check_quest_completion()
				end
			end
		end
	end
end

-- Update fox animation
function update_fox_animation(fox, now)
	local cfg = FOX_CONFIG

	-- Update damaged animation if currently flashing from hit
	if fox.hit_flash and now < fox.hit_flash then
		if now >= fox.damaged_anim_timer + 0.03 then
			fox.damaged_anim_timer = now
			fox.damaged_frame = fox.damaged_frame + 1
			if fox.damaged_frame >= cfg.damaged_frames then
				fox.damaged_frame = 0
			end
		end
		return
	end

	-- Determine animation speed based on state
	local anim_speed, max_frames
	if fox.state == "chasing" or fox.state == "attacking" then
		anim_speed = cfg.walk_animation_speed
		max_frames = cfg.walk_frames
	else
		anim_speed = cfg.idle_animation_speed
		max_frames = cfg.idle_frames
	end

	-- Advance animation frame
	if now >= fox.anim_timer + anim_speed then
		fox.anim_timer = now
		fox.walk_frame = fox.walk_frame + 1
		if fox.walk_frame >= max_frames then
			fox.walk_frame = 0
		end
	end
end

-- ============================================
-- FOX RENDERING
-- ============================================

-- Get sprite ID for fox
function get_fox_sprite(fox)
	local cfg = FOX_CONFIG
	local base = cfg.sprite_base

	if fox.state == "dead" then
		return base + cfg.damaged_start
	elseif fox.hit_flash and time() < fox.hit_flash then
		local frame = fox.damaged_frame or 0
		return base + cfg.damaged_start + frame
	elseif fox.state == "chasing" or fox.state == "attacking" then
		return base + cfg.walk_start + fox.walk_frame
	else
		return base + cfg.idle_start + fox.walk_frame
	end
end

-- Add foxes to visible list for depth sorting
function add_foxes_to_visible(visible)
	if not foxes_spawned then return end

	for _, fox in ipairs(foxes) do
		if fox.state ~= "dead" then
			local sx, sy = world_to_screen(fox.x, fox.y)
			-- Only add if on screen
			if sx > -32 and sx < SCREEN_W + 32 and sy > -32 and sy < SCREEN_H + 32 then
				local fox_feet_y = fox.y + 8
				add(visible, {
					type = "fox",
					y = fox_feet_y,
					cx = fox.x,
					cy = fox.y,
					sx = sx,
					sy = sy,
					data = fox
				})
			end
		end
	end
end

-- Draw a single fox
function draw_fox(fox, sx, sy)
	local cfg = FOX_CONFIG
	local sprite_id = get_fox_sprite(fox)
	local flip_x = not fox.facing_right

	local src_size = cfg.sprite_size
	local scale = cfg.sprite_scale
	local dst_size = src_size * scale

	local sprite = get_spr(sprite_id)

	-- Draw scaled sprite (same positioning as dealer)
	local draw_x = sx - dst_size / 2
	local draw_y = sy - dst_size + 4
	sspr(sprite, 0, 0, src_size, src_size,
		draw_x, draw_y,
		dst_size, dst_size, flip_x)
end

-- ============================================
-- FOX COMBAT (called from weapon.lua)
-- ============================================

-- Check if a projectile hits any fox, return the fox if hit
function check_fox_hit(proj_x, proj_y, radius)
	if not foxes_spawned then return nil end

	radius = radius or 12

	for _, fox in ipairs(foxes) do
		if fox.state ~= "dead" then
			local dx = proj_x - fox.x
			local dy = proj_y - fox.y
			local dist = sqrt(dx * dx + dy * dy)
			if dist < radius then
				return fox
			end
		end
	end

	return nil
end

-- Deal damage to a fox
function damage_fox(fox, amount)
	if fox.state == "dead" then return end

	fox.health = max(0, fox.health - amount)
	fox.hit_flash = time() + 0.35  -- Increased from 0.2 to show full damaged animation cycle
	fox.damaged_frame = 0
	fox.damaged_anim_timer = time()

	-- Small hit effect
	add_collision_effect(fox.x, fox.y, 0.2)
end

-- Show fox defeated message
function show_fox_defeated(fox_name)
	fox_defeated_message.active = true
	fox_defeated_message.end_time = time() + fox_defeated_message.duration
	fox_defeated_message.fox_name = fox_name
end

-- Draw fox defeated message in center of screen
function draw_fox_defeated_message()
	if not fox_defeated_message.active then return end

	local now = time()
	if now >= fox_defeated_message.end_time then
		fox_defeated_message.active = false
		return
	end

	-- Get text and measure width properly
	local text = "FOX DEFEATED"
	local text_w = print(text, 0, -100)
	local text_x = (SCREEN_W - text_w) / 2
	local text_y = SCREEN_H / 2 - 30

	-- Pulsing effect
	local pulse = sin(now * 4) * 0.5 + 0.5
	local color = pulse > 0.5 and 21 or 22  -- Alternate gold and yellow

	-- Draw with shadow for visibility
	print_shadow(text, text_x, text_y, color)

	-- Show fox name below
	local name = fox_defeated_message.fox_name
	local name_w = print(name, 0, -100)
	local name_x = (SCREEN_W - name_w) / 2
	print_shadow(name, name_x, text_y + 12, 33)  -- white
end
