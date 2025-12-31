--[[pod_format="raw"]]
-- cactus.lua - Cactus Monster boss enemy system

-- ============================================
-- CACTUS STATE
-- ============================================

-- Global cactus boss (single enemy)
cactus = nil

-- Cactus bullets (separate from player projectiles)
cactus_bullets = {}

-- Cactus defeated message display
cactus_defeated_message = {
	active = false,
	end_time = 0,
	duration = 3.0,  -- seconds to show message
}

-- ============================================
-- CACTUS CREATION AND SPAWNING
-- ============================================

-- Create the cactus monster
function create_cactus(x, y)
	local cfg = CACTUS_CONFIG

	cactus = {
		x = x,
		y = y,
		health = cfg.health,
		max_health = cfg.health,
		state = "idle",       -- "idle", "chasing", "attacking", "dead"
		facing_right = true,
		walk_frame = 0,
		anim_timer = 0,
		melee_timer = 0,      -- Cooldown for melee attacks
		ranged_timer = 0,     -- Cooldown for ranged attacks
		hit_flash = 0,        -- Timer for damage flash visual
		damaged_frame = 0,
		damaged_anim_timer = 0,
		-- Melee swing animation
		is_swinging = false,
		swing_timer = 0,
		swing_progress = 0,
	}

	printh("Cactus monster created at " .. x .. ", " .. y)
	return cactus
end

-- Find a valid spawn position in downtown area (avoiding buildings)
function find_cactus_spawn_position()
	local cfg = CACTUS_CONFIG
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

-- Check if a point is inside any building
function is_point_in_any_building(x, y)
	if not buildings then return false end

	for _, b in ipairs(buildings) do
		if x >= b.x and x <= b.x + b.w and y >= b.y and y <= b.y + b.h then
			return true
		end
	end
	return false
end

-- Spawn the cactus monster (called when quest starts)
function spawn_cactus()
	if cactus then
		printh("Cactus already exists, not spawning again")
		return
	end

	local x, y = find_cactus_spawn_position()
	create_cactus(x, y)
end

-- ============================================
-- CACTUS AI AND UPDATE
-- ============================================

-- Update cactus AI and state
function update_cactus()
	if not cactus then return end
	if not game or not game.player then return end

	local cfg = CACTUS_CONFIG
	local now = time()
	local despawn_delay = cfg.death_despawn_delay or 3  -- seconds before dead cactus despawns

	-- Handle dead state - check for despawn
	if cactus.state == "dead" then
		if cactus.death_time and now > cactus.death_time + despawn_delay then
			cactus = nil  -- Despawn the cactus
		end
		return
	end

	local p = game.player

	-- Calculate distance to player
	local dx = p.x - cactus.x
	local dy = p.y - cactus.y
	local dist = sqrt(dx * dx + dy * dy)

	-- Update facing direction
	if dx ~= 0 then
		cactus.facing_right = dx > 0
	end

	-- State machine
	if dist <= cfg.target_distance then
		-- Close enough to attack
		cactus.state = "attacking"

		-- Melee attack
		if now >= cactus.melee_timer and not cactus.is_swinging then
			cactus_melee_attack()
			cactus.melee_timer = now + cfg.melee_cooldown
		end

	elseif dist <= cfg.aggro_distance then
		-- Chase player
		cactus.state = "chasing"

		-- Move toward player
		local speed = cfg.chase_speed * (1/60)  -- per frame
		local move_x = (dx / dist) * speed
		local move_y = (dy / dist) * speed

		-- Simple collision check before moving
		local new_x = cactus.x + move_x
		local new_y = cactus.y + move_y

		if not is_point_in_any_building(new_x, new_y) then
			cactus.x = new_x
			cactus.y = new_y
		end
	else
		-- Player too far, idle
		cactus.state = "idle"
	end

	-- Ranged attack (independent of state, every 5 seconds)
	if now >= cactus.ranged_timer and dist <= cfg.aggro_distance then
		cactus_ranged_attack()
		cactus.ranged_timer = now + cfg.ranged_cooldown
	end

	-- Update melee swing animation
	update_cactus_swing(now)

	-- Update animation
	update_cactus_animation(cactus, now)

	-- Check if cactus died
	if cactus.health <= 0 and cactus.state ~= "dead" then
		cactus.state = "dead"
		cactus.death_time = now  -- Record death time for despawn timer
		mission.cactus_killed = true
		-- Show defeated message
		show_cactus_defeated()
		-- Big explosion effect
		add_collision_effect(cactus.x, cactus.y, 1.0)
		-- Check quest completion
		check_quest_completion()
	end
end

-- Melee attack (sword swing)
function cactus_melee_attack()
	local cfg = CACTUS_CONFIG

	-- Start swing animation
	cactus.is_swinging = true
	cactus.swing_timer = time()
	cactus.swing_progress = 0

	-- Check if player is in range
	local p = game.player
	local dx = p.x - cactus.x
	local dy = p.y - cactus.y
	local dist = sqrt(dx * dx + dy * dy)

	if dist <= cfg.melee_range then
		-- Hit player
		damage_player(cfg.melee_damage)
		add_collision_effect(p.x, p.y, 0.3)
	end
end

-- Update melee swing animation
function update_cactus_swing(now)
	if not cactus.is_swinging then return end

	local swing_duration = 0.3  -- Total swing time
	local elapsed = now - cactus.swing_timer

	if elapsed >= swing_duration then
		cactus.is_swinging = false
		cactus.swing_progress = 0
	else
		-- Progress from 0 to 1 and back
		local t = elapsed / swing_duration
		if t < 0.5 then
			cactus.swing_progress = t * 2  -- 0 to 1
		else
			cactus.swing_progress = (1 - t) * 2  -- 1 to 0
		end
	end
end

-- Ranged attack (10-directional bullet burst)
function cactus_ranged_attack()
	local cfg = CACTUS_CONFIG

	-- Fire bullets in 10 directions (36 degrees apart)
	for i = 0, cfg.bullet_count - 1 do
		local angle = (i / cfg.bullet_count) * 2 * 3.14159  -- 0 to 2*PI

		local bullet = {
			x = cactus.x,
			y = cactus.y,
			vx = cos(angle / (2 * 3.14159)) * cfg.bullet_speed,  -- Convert to turns for cos/sin
			vy = sin(angle / (2 * 3.14159)) * cfg.bullet_speed,
			damage = cfg.ranged_damage,
			sprite = cfg.bullet_sprite,
			spawn_time = time(),
		}

		add(cactus_bullets, bullet)
	end
end

-- Update cactus bullets
function update_cactus_bullets()
	if not game or not game.player then return end

	local dt = 1/60
	local now = time()
	local p = game.player

	for i = #cactus_bullets, 1, -1 do
		local b = cactus_bullets[i]

		-- Move bullet
		b.x = b.x + b.vx * dt
		b.y = b.y + b.vy * dt

		-- Check collision with player
		local dx = p.x - b.x
		local dy = p.y - b.y
		local dist = sqrt(dx * dx + dy * dy)

		if dist < 10 then
			-- Hit player
			damage_player(b.damage)
			add_collision_effect(p.x, p.y, 0.2)
			deli(cactus_bullets, i)
		-- Remove if too old (5 seconds) or off screen far
		elseif now - b.spawn_time > 5 then
			deli(cactus_bullets, i)
		end
	end
end

-- Update cactus animation
function update_cactus_animation(c, now)
	local cfg = CACTUS_CONFIG

	-- Update damaged animation if currently flashing from hit
	if c.hit_flash and now < c.hit_flash then
		if now >= c.damaged_anim_timer + 0.03 then
			c.damaged_anim_timer = now
			c.damaged_frame = c.damaged_frame + 1
			if c.damaged_frame >= cfg.damaged_frames then
				c.damaged_frame = 0
			end
		end
		return
	end

	-- Determine animation speed and max frames based on state
	local anim_speed, max_frames
	if c.state == "chasing" or c.state == "attacking" then
		anim_speed = cfg.walk_animation_speed
		max_frames = cfg.walk_frames
	else
		anim_speed = cfg.idle_animation_speed
		max_frames = cfg.idle_frames
	end

	-- Advance animation frame
	if now >= c.anim_timer + anim_speed then
		c.anim_timer = now
		c.walk_frame = c.walk_frame + 1
		if c.walk_frame >= max_frames then
			c.walk_frame = 0
		end
	end
end

-- ============================================
-- CACTUS RENDERING
-- ============================================

-- Get sprite ID for cactus
function get_cactus_sprite()
	if not cactus then return nil end

	local cfg = CACTUS_CONFIG
	local base = cfg.sprite_base

	if cactus.state == "dead" then
		return base + cfg.damaged_start
	elseif cactus.hit_flash and time() < cactus.hit_flash then
		local frame = cactus.damaged_frame or 0
		return base + cfg.damaged_start + frame
	elseif cactus.state == "chasing" or cactus.state == "attacking" then
		return base + cfg.walk_start + cactus.walk_frame
	else
		return base + cfg.idle_start + cactus.walk_frame
	end
end

-- Add cactus to visible list for depth sorting
function add_cactus_to_visible(visible)
	if not cactus or cactus.state == "dead" then return end

	local sx, sy = world_to_screen(cactus.x, cactus.y)
	-- Only add if on screen
	if sx > -64 and sx < SCREEN_W + 64 and sy > -64 and sy < SCREEN_H + 64 then
		local cactus_feet_y = cactus.y + 8
		add(visible, {
			type = "cactus",
			y = cactus_feet_y,
			cx = cactus.x,
			cy = cactus.y,
			sx = sx,
			sy = sy,
			data = cactus
		})
	end
end

-- Draw cactus
function draw_cactus(c, sx, sy)
	local cfg = CACTUS_CONFIG
	local sprite_id = get_cactus_sprite()
	if not sprite_id then return end

	local flip_x = not c.facing_right

	local src_size = cfg.sprite_size
	local scale = cfg.sprite_scale
	local dst_size = src_size  -- Draw at original size (scale kept for future use)

	local sprite = get_spr(sprite_id)

	-- Draw at original sprite size
	local draw_x = sx - dst_size / 2
	local draw_y = sy - dst_size + 4
	sspr(sprite, 0, 0, src_size, src_size,
		draw_x, draw_y,
		dst_size, dst_size, flip_x)

	-- Always draw sword (like player weapon)
	draw_cactus_sword(c, sx, sy)
end

-- Draw cactus sword (always visible, animates during swing)
function draw_cactus_sword(c, sx, sy)
	local cfg = CACTUS_CONFIG
	local wcfg = WEAPON_CONFIG

	-- Facing direction
	local facing_east = c.facing_right
	-- Use cactus-specific offsets for 48x48 sprite
	local offset_x = facing_east and cfg.melee_offset_x or -cfg.melee_offset_x
	local offset_y = cfg.melee_offset_y
	local flip_x = facing_east
	local base_rot = facing_east and wcfg.melee_base_rot_east or wcfg.melee_base_rot_west

	-- Calculate swing rotation
	local swing_rot = 0
	if c.is_swinging then
		local swing_range = wcfg.melee_swing_end - wcfg.melee_swing_start
		swing_rot = wcfg.melee_swing_start + (swing_range * c.swing_progress)
		if not facing_east then swing_rot = -swing_rot end
	end

	-- Draw sword using rspr (same as player)
	rspr(cfg.sword_sprite, sx + offset_x, sy + offset_y, 1, 1, base_rot + swing_rot, flip_x, wcfg.melee_pivot_x, wcfg.melee_pivot_y)
end

-- Draw cactus bullets
function draw_cactus_bullets()
	for _, b in ipairs(cactus_bullets) do
		local sx, sy = world_to_screen(b.x, b.y)
		if sx > -16 and sx < SCREEN_W + 16 and sy > -16 and sy < SCREEN_H + 16 then
			spr(b.sprite, sx - 4, sy - 4)
		end
	end
end

-- Draw cactus health bar (boss style, at top of screen)
function draw_cactus_health_bar()
	if not cactus or cactus.state == "dead" then return end

	local cfg = CACTUS_CONFIG

	-- Draw at top center of screen
	local bar_w = 150
	local bar_h = 10
	local bar_x = (SCREEN_W - bar_w) / 2
	local bar_y = 20

	-- Draw name
	local name = cfg.name
	local name_w = print(name, 0, -100)
	print_shadow(name, (SCREEN_W - name_w) / 2, bar_y - 12, 19)  -- Green

	-- Health percentage
	local health_pct = cactus.health / cactus.max_health
	health_pct = max(0, min(1, health_pct))
	local fill_w = flr(bar_w * health_pct)

	-- Draw border (green)
	rect(bar_x - 1, bar_y - 1, bar_x + bar_w, bar_y + bar_h, 19)
	-- Draw background
	rectfill(bar_x, bar_y, bar_x + bar_w - 1, bar_y + bar_h - 1, 1)
	-- Draw health fill (bright green)
	if fill_w > 0 then
		rectfill(bar_x, bar_y, bar_x + fill_w - 1, bar_y + bar_h - 1, 27)
	end
end

-- ============================================
-- CACTUS DAMAGE AND DEFEAT
-- ============================================

-- Deal damage to cactus
function damage_cactus(amount)
	if not cactus or cactus.state == "dead" then return end

	cactus.health = max(0, cactus.health - amount)
	cactus.hit_flash = time() + 0.35
	cactus.damaged_frame = 0
	cactus.damaged_anim_timer = time()

	-- Hit effect
	add_collision_effect(cactus.x, cactus.y, 0.3)
end

-- Show cactus defeated message
function show_cactus_defeated()
	cactus_defeated_message.active = true
	cactus_defeated_message.end_time = time() + cactus_defeated_message.duration
end

-- Draw cactus defeated message in center of screen
function draw_cactus_defeated_message()
	if not cactus_defeated_message.active then return end

	local now = time()
	if now >= cactus_defeated_message.end_time then
		cactus_defeated_message.active = false
		return
	end

	-- Get text and measure width properly
	local text = "CACTUS DEFEATED!"
	local text_w = print(text, 0, -100)
	local text_x = (SCREEN_W - text_w) / 2
	local text_y = SCREEN_H / 2 - 30

	-- Pulsing effect
	local pulse = sin(now * 4) * 0.5 + 0.5
	local color = pulse > 0.5 and 27 or 19  -- Alternate light green and green

	-- Draw with shadow for visibility
	print_shadow(text, text_x, text_y, color)

	-- Show subtitle
	local subtitle = "Downtown is safe!"
	local sub_w = print(subtitle, 0, -100)
	local sub_x = (SCREEN_W - sub_w) / 2
	print_shadow(subtitle, sub_x, text_y + 14, 33)  -- white
end

-- ============================================
-- CACTUS MINIMAP
-- ============================================

-- Draw cactus on minimap
function draw_cactus_on_minimap(cfg, cx, cy, scale)
	if not cactus or cactus.state == "dead" then return end

	local ccfg = CACTUS_CONFIG
	local mx = cx + cactus.x * scale
	local my = cy + cactus.y * scale

	-- Draw larger dot for boss
	circfill(mx, my, ccfg.minimap_size, ccfg.minimap_color)
end

-- ============================================
-- CACTUS CLEANUP
-- ============================================

-- Clean up cactus (called when player dies or quest resets)
function cleanup_cactus()
	cactus = nil
	cactus_bullets = {}
	cactus_defeated_message.active = false
	printh("Cactus cleaned up")
end
