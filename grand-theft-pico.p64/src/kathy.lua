--[[pod_format="raw"]]
-- kathy.lua - Auditor Kathy boss enemy system

-- ============================================
-- KATHY STATE
-- ============================================

-- Global Kathy boss (single enemy)
kathy = nil

-- Kathy bullets (separate from player projectiles)
kathy_bullets = {}

-- Kathy's fox minions (separate from protect_city foxes)
kathy_foxes = {}

-- Whether Kathy's foxes have been spawned
kathy_foxes_spawned = false

-- Kathy defeated message display
kathy_defeated_message = {
	active = false,
	end_time = 0,
	duration = 3.0,  -- seconds to show message
}

-- ============================================
-- KATHY CREATION AND SPAWNING
-- ============================================

-- Create the Kathy boss
function create_kathy(x, y)
	local cfg = KATHY_CONFIG

	kathy = {
		x = x,
		y = y,
		health = cfg.health,
		max_health = cfg.health,
		state = "idle",       -- "idle", "chasing", "attacking", "dead"
		facing_right = true,
		walk_frame = 0,
		anim_timer = 0,
		spiral_timer = 0,     -- Cooldown for spiral attack
		sweep_timer = 0,      -- Cooldown for sweep attack
		hit_flash = 0,        -- Timer for damage flash visual
		damaged_frame = 0,
		damaged_anim_timer = 0,
	}

	printh("Auditor Kathy created at " .. x .. ", " .. y)
	return kathy
end

-- Find a valid spawn position in downtown area (avoiding buildings)
function find_kathy_spawn_position()
	local cfg = KATHY_CONFIG
	local attempts = 50

	for i = 1, attempts do
		local x = cfg.spawn_x_min + rnd(cfg.spawn_x_max - cfg.spawn_x_min)
		local y = cfg.spawn_y_min + rnd(cfg.spawn_y_max - cfg.spawn_y_min)

		-- Check if position is valid (not inside a building)
		if not is_point_in_any_building(x, y) then
			return x, y
		end
	end

	-- Fallback: spawn at center of downtown
	return (cfg.spawn_x_min + cfg.spawn_x_max) / 2, (cfg.spawn_y_min + cfg.spawn_y_max) / 2
end

-- Spawn the Kathy boss (called when quest starts)
function spawn_kathy()
	if kathy then
		printh("Kathy already exists, not spawning again")
		return
	end

	local x, y = find_kathy_spawn_position()
	create_kathy(x, y)
end

-- Spawn fox minions near Kathy
function spawn_kathy_foxes()
	if kathy_foxes_spawned then
		printh("Kathy's foxes already spawned")
		return
	end
	if not kathy then
		printh("Cannot spawn Kathy's foxes - Kathy doesn't exist")
		return
	end

	local cfg = KATHY_CONFIG
	local fox_cfg = FOX_CONFIG
	local names = { "Agent A", "Agent B", "Agent C" }

	for i = 1, cfg.fox_minion_count do
		-- Spawn foxes in a circle around Kathy
		local angle = (i - 1) / cfg.fox_minion_count
		local dist = 80  -- Distance from Kathy
		local fx = kathy.x + cos(angle) * dist
		local fy = kathy.y + sin(angle) * dist

		local fox = {
			x = fx,
			y = fy,
			name = names[i] or ("Agent " .. i),
			health = fox_cfg.health,
			max_health = fox_cfg.health,
			state = "idle",
			facing_right = true,
			walk_frame = 0,
			anim_timer = 0,
			attack_timer = 0,
			hit_flash = 0,
			damaged_frame = 0,
			damaged_anim_timer = 0,
		}

		add(kathy_foxes, fox)
		printh("Created Kathy fox '" .. fox.name .. "' at (" .. flr(fx) .. ", " .. flr(fy) .. ")")
	end

	kathy_foxes_spawned = true
	printh("Spawned " .. cfg.fox_minion_count .. " fox minions for Kathy")
end

-- ============================================
-- KATHY AI AND UPDATE
-- ============================================

-- Update Kathy AI and state
function update_kathy()
	if not kathy then return end
	if not game or not game.player then return end

	local cfg = KATHY_CONFIG
	local now = time()
	local despawn_delay = cfg.death_despawn_delay or 3  -- seconds before dead Kathy despawns

	-- Handle dead state - check for despawn
	if kathy.state == "dead" then
		if kathy.death_time and now > kathy.death_time + despawn_delay then
			kathy = nil  -- Despawn Kathy
		end
		return
	end

	local p = game.player

	-- Calculate distance to player
	local dx = p.x - kathy.x
	local dy = p.y - kathy.y
	local dist = sqrt(dx * dx + dy * dy)

	-- Update facing direction
	if dx ~= 0 then
		kathy.facing_right = dx > 0
	end

	-- State machine
	if dist <= cfg.target_distance then
		-- Close enough to attack (but Kathy prefers ranged, so back off slightly)
		kathy.state = "attacking"

	elseif dist <= cfg.aggro_distance then
		-- Chase player (but keep some distance since ranged-only)
		if dist < cfg.target_distance * 0.7 then
			-- Too close, back away
			local speed = cfg.chase_speed * 0.5 * (1/60)
			local move_x = -(dx / dist) * speed
			local move_y = -(dy / dist) * speed
			local new_x = kathy.x + move_x
			local new_y = kathy.y + move_y
			if not is_point_in_any_building(new_x, new_y) then
				kathy.x = new_x
				kathy.y = new_y
			end
		else
			-- Chase toward player
			kathy.state = "chasing"
			local speed = cfg.chase_speed * (1/60)
			local move_x = (dx / dist) * speed
			local move_y = (dy / dist) * speed
			local new_x = kathy.x + move_x
			local new_y = kathy.y + move_y
			if not is_point_in_any_building(new_x, new_y) then
				kathy.x = new_x
				kathy.y = new_y
			end
		end
	else
		-- Player too far, idle
		kathy.state = "idle"
	end

	-- Spiral attack (every ~6 seconds when in range)
	if now >= kathy.spiral_timer and dist <= cfg.aggro_distance then
		kathy_spiral_attack()
		kathy.spiral_timer = now + cfg.spiral_cooldown
	end

	-- Sweep attack (every ~4 seconds when in range)
	if now >= kathy.sweep_timer and dist <= cfg.aggro_distance then
		kathy_sweep_attack()
		kathy.sweep_timer = now + cfg.sweep_cooldown
	end

	-- Update animation
	update_kathy_animation(kathy, now)

	-- Check if Kathy died
	if kathy.health <= 0 and kathy.state ~= "dead" then
		kathy.state = "dead"
		kathy.death_time = now  -- Record death time for despawn timer
		mission.kathy_killed = true
		-- Show defeated message
		show_kathy_defeated()
		-- Big explosion effect
		add_collision_effect(kathy.x, kathy.y, 1.0)
		-- Award popularity
		if QUEST_CONFIG.auditor_kathy and QUEST_CONFIG.auditor_kathy.popularity_reward then
			change_popularity(QUEST_CONFIG.auditor_kathy.popularity_reward)
		end
		-- Check quest completion
		check_quest_completion()
	end
end

-- ============================================
-- BULLET PATTERNS
-- ============================================

-- Spiral attack: fire bullets in a spiral pattern
function kathy_spiral_attack()
	local cfg = KATHY_CONFIG
	local now = time()

	-- Fire bullets in a spiral pattern
	for i = 0, cfg.spiral_bullet_count - 1 do
		-- Each bullet gets a slightly different angle based on its index
		local base_angle = now * 0.5  -- Rotate over time
		local angle = base_angle + (i * cfg.spiral_rotation_offset)

		local bullet = {
			x = kathy.x,
			y = kathy.y,
			vx = cos(angle) * cfg.spiral_speed,
			vy = sin(angle) * cfg.spiral_speed,
			damage = cfg.spiral_damage,
			sprites = cfg.spiral_sprites,
			sprite_index = 1,
			anim_timer = 0,
			anim_speed = cfg.spiral_animation_speed,
			spawn_time = now,
			pattern = "spiral",
		}

		add(kathy_bullets, bullet)
	end
	sfx(SFX.bullet_shot)

	printh("Kathy fired spiral attack with " .. cfg.spiral_bullet_count .. " bullets")
end

-- Sweep attack: fire a line of bullets toward player
function kathy_sweep_attack()
	if not game or not game.player then return end

	local cfg = KATHY_CONFIG
	local p = game.player
	local now = time()

	-- Calculate base direction to player
	local dx = p.x - kathy.x
	local dy = p.y - kathy.y
	local dist = sqrt(dx * dx + dy * dy)
	if dist <= 0 then return end

	-- Get base angle to player (in turns, 0-1)
	local base_angle = atan2(dx, dy)

	-- Spread bullets across an arc
	local half_arc = cfg.sweep_arc / 2
	local step = cfg.sweep_arc / (cfg.sweep_bullet_count - 1)

	for i = 0, cfg.sweep_bullet_count - 1 do
		local angle = base_angle - half_arc + (i * step)

		local bullet = {
			x = kathy.x,
			y = kathy.y,
			vx = cos(angle) * cfg.sweep_speed,
			vy = sin(angle) * cfg.sweep_speed,
			damage = cfg.sweep_damage,
			sprites = cfg.sweep_sprites,
			sprite_index = 1,
			anim_timer = 0,
			anim_speed = cfg.sweep_animation_speed,
			spawn_time = now,
			pattern = "sweep",
		}

		add(kathy_bullets, bullet)
	end
	sfx(SFX.bullet_shot)

	printh("Kathy fired sweep attack with " .. cfg.sweep_bullet_count .. " bullets")
end

-- ============================================
-- BULLET UPDATE
-- ============================================

-- Update Kathy bullets
function update_kathy_bullets()
	if not game or not game.player then return end

	local dt = 1/60
	local now = time()
	local p = game.player

	for i = #kathy_bullets, 1, -1 do
		local b = kathy_bullets[i]

		-- Move bullet
		b.x = b.x + b.vx * dt
		b.y = b.y + b.vy * dt

		-- Animate sprite
		if now >= b.anim_timer + b.anim_speed then
			b.anim_timer = now
			b.sprite_index = b.sprite_index + 1
			if b.sprite_index > #b.sprites then
				b.sprite_index = 1
			end
		end

		-- Check collision with player
		local dx = p.x - b.x
		local dy = p.y - b.y
		local dist = sqrt(dx * dx + dy * dy)

		if dist < 12 then
			-- Hit player
			damage_player(b.damage)
			add_collision_effect(p.x, p.y, 0.2)
			deli(kathy_bullets, i)
		-- Remove if too old (5 seconds)
		elseif now - b.spawn_time > 5 then
			deli(kathy_bullets, i)
		end
	end
end

-- ============================================
-- KATHY ANIMATION
-- ============================================

-- Update Kathy animation
function update_kathy_animation(k, now)
	local cfg = KATHY_CONFIG

	-- Update damaged animation if currently flashing from hit
	if k.hit_flash and now < k.hit_flash then
		if now >= k.damaged_anim_timer + 0.03 then
			k.damaged_anim_timer = now
			k.damaged_frame = k.damaged_frame + 1
			if k.damaged_frame >= cfg.damaged_frames then
				k.damaged_frame = 0
			end
		end
		return
	end

	-- Determine animation speed and max frames based on state
	local anim_speed, max_frames
	if k.state == "chasing" or k.state == "attacking" then
		anim_speed = cfg.walk_animation_speed
		max_frames = cfg.walk_frames
	else
		anim_speed = cfg.idle_animation_speed
		max_frames = cfg.idle_frames
	end

	-- Clamp walk_frame to valid range for current state (prevents showing wrong sprites when switching states)
	if k.walk_frame >= max_frames then
		k.walk_frame = 0
	end

	-- Advance animation frame
	if now >= k.anim_timer + anim_speed then
		k.anim_timer = now
		k.walk_frame = k.walk_frame + 1
		if k.walk_frame >= max_frames then
			k.walk_frame = 0
		end
	end
end

-- ============================================
-- KATHY FOX MINIONS
-- ============================================

-- Update Kathy's fox minions
function update_kathy_foxes()
	if not kathy_foxes_spawned then return end
	if not game or not game.player then return end

	local now = time()
	local p = game.player
	local cfg = FOX_CONFIG
	local despawn_delay = cfg.death_despawn_delay or 3  -- seconds before dead fox despawns

	-- Track dead foxes to remove
	local to_remove = {}

	for i, fox in ipairs(kathy_foxes) do
		if fox.state ~= "dead" then
			-- Calculate distance to player
			local dx = p.x - fox.x
			local dy = p.y - fox.y
			local dist = sqrt(dx * dx + dy * dy)

			-- State transitions based on distance
			if dist <= cfg.aggro_distance then
				if dist > cfg.target_distance then
					fox.state = "chasing"
					-- Move toward player
					local speed = cfg.chase_speed / 60
					fox.x = fox.x + (dx / dist) * speed
					fox.y = fox.y + (dy / dist) * speed
				else
					-- In attack range - fire bullets
					fox.state = "attacking"
					if now >= fox.attack_timer then
						fire_kathy_fox_bullet(fox)
						fox.attack_timer = now + cfg.fire_rate
					end
				end
				-- Face toward player
				fox.facing_right = dx >= 0
			else
				fox.state = "idle"
			end

			-- Update animation
			update_kathy_fox_animation(fox, now)

			-- Check if fox died
			if fox.health <= 0 and fox.state ~= "dead" then
				fox.state = "dead"
				fox.death_time = now  -- Record death time for despawn timer
				mission.kathy_foxes_killed = mission.kathy_foxes_killed + 1
				add_collision_effect(fox.x, fox.y, 0.5)
				show_kathy_fox_defeated(fox.name)
				-- Check quest completion
				if mission.kathy_killed and mission.kathy_foxes_killed >= mission.total_kathy_foxes then
					check_quest_completion()
				end
			end
		else
			-- Fox is dead - check if it should despawn
			if fox.death_time and now > fox.death_time + despawn_delay then
				add(to_remove, i)
			end
		end
	end

	-- Remove despawned foxes (iterate backwards to preserve indices)
	for i = #to_remove, 1, -1 do
		deli(kathy_foxes, to_remove[i])
	end
end

-- Fire a bullet from Kathy's fox toward player
function fire_kathy_fox_bullet(fox)
	local cfg = FOX_CONFIG
	local dealer_cfg = ARMS_DEALER_CONFIG
	local p = game.player

	-- Calculate fox center
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

	-- Create projectile
	local bullet_sprite = dealer_cfg.bullet_sprites[1]
	local proj = {
		x = fox_center_x,
		y = fox_center_y,
		dx = dx,
		dy = dy,
		speed = cfg.bullet_speed,
		damage = cfg.damage,
		owner = fox,
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

-- Update animation for Kathy's fox
function update_kathy_fox_animation(fox, now)
	local cfg = FOX_CONFIG

	-- Update damaged animation if flashing
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

-- Get living Kathy fox count
function get_living_kathy_fox_count()
	local count = 0
	for _, fox in ipairs(kathy_foxes) do
		if fox.state ~= "dead" then
			count = count + 1
		end
	end
	return count
end

-- ============================================
-- KATHY RENDERING
-- ============================================

-- Get sprite ID for Kathy
function get_kathy_sprite()
	if not kathy then return nil end

	local cfg = KATHY_CONFIG
	local base = cfg.sprite_base

	if kathy.state == "dead" then
		return base + cfg.damaged_start
	elseif kathy.hit_flash and time() < kathy.hit_flash then
		local frame = kathy.damaged_frame or 0
		return base + cfg.damaged_start + frame
	elseif kathy.state == "chasing" or kathy.state == "attacking" then
		return base + cfg.walk_start + kathy.walk_frame
	else
		return base + cfg.idle_start + kathy.walk_frame
	end
end

-- Add Kathy to visible list for depth sorting
function add_kathy_to_visible(visible)
	if not kathy or kathy.state == "dead" then return end

	local sx, sy = world_to_screen(kathy.x, kathy.y)
	-- Only add if on screen
	if sx > -64 and sx < SCREEN_W + 64 and sy > -64 and sy < SCREEN_H + 64 then
		local kathy_feet_y = kathy.y + 8
		add(visible, {
			type = "kathy",
			y = kathy_feet_y,
			cx = kathy.x,
			cy = kathy.y,
			sx = sx,
			sy = sy,
			data = kathy
		})
	end
end

-- Draw Kathy (no sword, unlike cactus)
function draw_kathy(k, sx, sy)
	local cfg = KATHY_CONFIG
	local sprite_id = get_kathy_sprite()
	if not sprite_id then return end

	local flip_x = not k.facing_right

	local src_size = cfg.sprite_size
	local dst_size = src_size  -- Draw at original size

	local sprite = get_spr(sprite_id)

	-- Draw at original sprite size
	local draw_x = sx - dst_size / 2
	local draw_y = sy - dst_size + 4
	sspr(sprite, 0, 0, src_size, src_size,
		draw_x, draw_y,
		dst_size, dst_size, flip_x)
end

-- Draw Kathy bullets
function draw_kathy_bullets()
	for _, b in ipairs(kathy_bullets) do
		local sx, sy = world_to_screen(b.x, b.y)
		if sx > -16 and sx < SCREEN_W + 16 and sy > -16 and sy < SCREEN_H + 16 then
			local sprite_id = b.sprites[b.sprite_index]
			spr(sprite_id, sx - 4, sy - 4)
		end
	end
end

-- Draw Kathy health bar (boss style, at top of screen)
function draw_kathy_health_bar()
	if not kathy or kathy.state == "dead" then return end

	local cfg = KATHY_CONFIG

	-- Draw at top center of screen
	local bar_w = 150
	local bar_h = 10
	local bar_x = (SCREEN_W - bar_w) / 2
	local bar_y = 20

	-- Draw name
	local name = cfg.name
	local name_w = print(name, 0, -100)
	print_shadow(name, (SCREEN_W - name_w) / 2, bar_y - 12, 6)  -- Magenta

	-- Health percentage
	local health_pct = kathy.health / kathy.max_health
	health_pct = max(0, min(1, health_pct))
	local fill_w = flr(bar_w * health_pct)

	-- Draw border (magenta)
	rect(bar_x - 1, bar_y - 1, bar_x + bar_w, bar_y + bar_h, 6)
	-- Draw background
	rectfill(bar_x, bar_y, bar_x + bar_w - 1, bar_y + bar_h - 1, 1)
	-- Draw health fill (bright magenta/pink)
	if fill_w > 0 then
		rectfill(bar_x, bar_y, bar_x + fill_w - 1, bar_y + bar_h - 1, 14)
	end
end

-- Add Kathy's foxes to visible list
function add_kathy_foxes_to_visible(visible)
	if not kathy_foxes_spawned then return end

	for _, fox in ipairs(kathy_foxes) do
		if fox.state ~= "dead" then
			local sx, sy = world_to_screen(fox.x, fox.y)
			if sx > -32 and sx < SCREEN_W + 32 and sy > -32 and sy < SCREEN_H + 32 then
				local fox_feet_y = fox.y + 8
				add(visible, {
					type = "kathy_fox",
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

-- Draw a Kathy fox (same as regular fox)
function draw_kathy_fox(fox, sx, sy)
	local cfg = FOX_CONFIG
	local sprite_id = get_kathy_fox_sprite(fox)
	local flip_x = not fox.facing_right

	local src_size = cfg.sprite_size
	local scale = cfg.sprite_scale
	local dst_size = src_size * scale

	local sprite = get_spr(sprite_id)

	local draw_x = sx - dst_size / 2
	local draw_y = sy - dst_size + 4
	sspr(sprite, 0, 0, src_size, src_size,
		draw_x, draw_y,
		dst_size, dst_size, flip_x)
end

-- Get sprite ID for Kathy's fox
function get_kathy_fox_sprite(fox)
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

-- ============================================
-- KATHY DAMAGE AND DEFEAT
-- ============================================

-- Deal damage to Kathy
function damage_kathy(amount)
	if not kathy or kathy.state == "dead" then return end

	kathy.health = max(0, kathy.health - amount)
	kathy.hit_flash = time() + 0.35
	kathy.damaged_frame = 0
	kathy.damaged_anim_timer = time()

	-- Hit effect
	add_collision_effect(kathy.x, kathy.y, 0.3)
	sfx(SFX.vehicle_collision)  -- damage sound
end

-- Check if a projectile hits Kathy
function check_kathy_hit(proj_x, proj_y, radius)
	if not kathy or kathy.state == "dead" then return false end

	radius = radius or 20  -- Larger hitbox for boss

	local dx = proj_x - kathy.x
	local dy = proj_y - kathy.y
	local dist = sqrt(dx * dx + dy * dy)

	return dist < radius
end

-- Deal damage to a Kathy fox
function damage_kathy_fox(fox, amount)
	if fox.state == "dead" then return end

	fox.health = max(0, fox.health - amount)
	fox.hit_flash = time() + 0.35
	fox.damaged_frame = 0
	fox.damaged_anim_timer = time()

	add_collision_effect(fox.x, fox.y, 0.2)
	sfx(SFX.vehicle_collision)  -- damage sound
end

-- Check if a projectile hits any Kathy fox
function check_kathy_fox_hit(proj_x, proj_y, radius)
	if not kathy_foxes_spawned then return nil end

	radius = radius or 12

	for _, fox in ipairs(kathy_foxes) do
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

-- Show Kathy defeated message
function show_kathy_defeated()
	kathy_defeated_message.active = true
	kathy_defeated_message.end_time = time() + kathy_defeated_message.duration
end

-- Show Kathy fox defeated message
kathy_fox_defeated_message = {
	active = false,
	end_time = 0,
	fox_name = "",
	duration = 2.0,
}

function show_kathy_fox_defeated(fox_name)
	kathy_fox_defeated_message.active = true
	kathy_fox_defeated_message.end_time = time() + kathy_fox_defeated_message.duration
	kathy_fox_defeated_message.fox_name = fox_name
end

-- Draw Kathy defeated message in center of screen
function draw_kathy_defeated_message()
	if not kathy_defeated_message.active then return end

	local now = time()
	if now >= kathy_defeated_message.end_time then
		kathy_defeated_message.active = false
		return
	end

	local text = "AUDITOR KATHY DEFEATED!"
	local text_w = print(text, 0, -100)
	local text_x = (SCREEN_W - text_w) / 2
	local text_y = SCREEN_H / 2 - 30

	-- Pulsing effect
	local pulse = sin(now * 4) * 0.5 + 0.5
	local color = pulse > 0.5 and 14 or 6  -- Alternate bright red and magenta

	print_shadow(text, text_x, text_y, color)

	local subtitle = "The insurance company won't bother you anymore!"
	local sub_w = print(subtitle, 0, -100)
	local sub_x = (SCREEN_W - sub_w) / 2
	print_shadow(subtitle, sub_x, text_y + 14, 33)
end

-- Draw Kathy fox defeated message
function draw_kathy_fox_defeated_message()
	if not kathy_fox_defeated_message.active then return end

	local now = time()
	if now >= kathy_fox_defeated_message.end_time then
		kathy_fox_defeated_message.active = false
		return
	end

	local text = "AGENT DEFEATED"
	local text_w = print(text, 0, -100)
	local text_x = (SCREEN_W - text_w) / 2
	local text_y = SCREEN_H / 2 - 30

	local pulse = sin(now * 4) * 0.5 + 0.5
	local color = pulse > 0.5 and 21 or 22

	print_shadow(text, text_x, text_y, color)

	local name = kathy_fox_defeated_message.fox_name
	local name_w = print(name, 0, -100)
	local name_x = (SCREEN_W - name_w) / 2
	print_shadow(name, name_x, text_y + 12, 33)
end

-- ============================================
-- KATHY MINIMAP
-- ============================================

-- Draw Kathy on minimap
function draw_kathy_on_minimap(cfg, cx, cy, scale)
	if not kathy or kathy.state == "dead" then return end

	local kcfg = KATHY_CONFIG
	local mx = cx + kathy.x * scale
	local my = cy + kathy.y * scale

	-- Draw larger dot for boss
	circfill(mx, my, kcfg.minimap_size, kcfg.minimap_color)
end

-- Draw Kathy's foxes on minimap
function draw_kathy_foxes_on_minimap(cfg, cx, cy, scale)
	if not kathy_foxes_spawned then return end

	local fox_cfg = FOX_CONFIG

	for _, fox in ipairs(kathy_foxes) do
		if fox.state ~= "dead" then
			local mx = cx + fox.x * scale
			local my = cy + fox.y * scale
			circfill(mx, my, fox_cfg.minimap_size, fox_cfg.minimap_color)
		end
	end
end

-- ============================================
-- CLEANUP
-- ============================================

-- Clean up Kathy when quest ends
function cleanup_kathy()
	kathy = nil
	kathy_bullets = {}
	kathy_foxes = {}
	kathy_foxes_spawned = false
	kathy_defeated_message.active = false
	kathy_fox_defeated_message.active = false
	printh("Kathy boss cleaned up")
end
