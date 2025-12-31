--[[pod_format="raw"]]
-- alien_minion.lua - Alien minion enemies for mothership boss fight

-- ============================================
-- MINION STATE
-- ============================================

alien_minions = {}
alien_minion_bullets = {}
last_minion_spawn_time = 0

-- ============================================
-- MINION CREATION
-- ============================================

function create_alien_minion(x, y)
	local cfg = ALIEN_MINION_CONFIG
	return {
		x = x,
		y = y,
		health = cfg.health,
		max_health = cfg.health,
		state = "idle",  -- "idle", "chasing", "attacking", "dead"
		facing_right = true,

		-- Animation
		anim_frame = 0,
		anim_timer = 0,

		-- Attack state
		last_attack_time = 0,
		attack_pulse_count = 0,
		attack_pulse_timer = 0,
		attacking = false,

		-- Hit flash
		hit_flash = 0,
		damaged_frame = 0,
		damaged_anim_timer = 0,

		-- Spawn time
		spawn_time = time(),

		-- Surround behavior - each minion gets a unique orbit angle
		orbit_angle = rnd(1),  -- random starting angle around player
		orbit_wobble = rnd(1),  -- phase offset for wobble
		hover_offset = 0,  -- vertical hover animation
	}
end

-- ============================================
-- SPAWNING
-- ============================================

function spawn_alien_minion()
	if not mothership then return end

	local cfg = ALIEN_MINION_CONFIG
	local mcfg = MOTHERSHIP_CONFIG

	-- Don't spawn if at max
	if #alien_minions >= mcfg.max_minions then return end

	-- Spawn at random position around mothership
	local angle = rnd(1)
	local x = mothership.x + cos(angle) * cfg.spawn_radius
	local y = mothership.y + sin(angle) * cfg.spawn_radius

	local minion = create_alien_minion(x, y)
	add(alien_minions, minion)

	printh("Spawned alien minion at " .. flr(x) .. ", " .. flr(y) .. " (total: " .. #alien_minions .. ")")
end

function spawn_initial_minions()
	local mcfg = MOTHERSHIP_CONFIG
	for i = 1, mcfg.max_minions do
		spawn_alien_minion()
	end
	last_minion_spawn_time = time()
end

-- ============================================
-- UPDATE
-- ============================================

function update_alien_minions()
	if not mothership then return end

	local cfg = ALIEN_MINION_CONFIG
	local mcfg = MOTHERSHIP_CONFIG
	local now = time()

	-- Check if we need to spawn more minions
	if #alien_minions < mcfg.max_minions then
		if now >= last_minion_spawn_time + mcfg.minion_respawn_delay then
			spawn_alien_minion()
			last_minion_spawn_time = now
		end
	end

	-- Update each minion
	for i = #alien_minions, 1, -1 do
		local m = alien_minions[i]

		if m.state == "dead" then
			deli(alien_minions, i)
		else
			update_single_minion(m)
		end
	end

	-- Update bullets
	update_alien_minion_bullets()
end

function update_single_minion(m)
	local cfg = ALIEN_MINION_CONFIG
	local now = time()
	local dt = 1/60

	-- Calculate distance to player
	local dx = game.player.x - m.x
	local dy = game.player.y - m.y
	local dist = sqrt(dx * dx + dy * dy)

	-- Update facing direction
	m.facing_right = dx > 0

	-- Update hover offset for floating animation
	m.hover_offset = sin(now * cfg.hover_speed + m.orbit_wobble) * cfg.hover_amplitude

	-- State machine
	if m.attacking then
		-- Continue attack animation (stay in place while attacking)
		update_minion_attack(m)
	elseif dist < cfg.aggro_distance then
		-- Within aggro range - orbit around player
		m.state = "chasing"

		-- Update orbit angle (each minion orbits at their own pace)
		m.orbit_angle = m.orbit_angle + cfg.orbit_speed * dt

		-- Calculate target orbit position around player
		local wobble = sin(now * cfg.wobble_speed + m.orbit_wobble * 6.28) * cfg.wobble_amplitude
		local target_x = game.player.x + cos(m.orbit_angle) * (cfg.orbit_radius + wobble)
		local target_y = game.player.y + sin(m.orbit_angle) * (cfg.orbit_radius + wobble)

		-- Move towards target orbit position
		local target_dx = target_x - m.x
		local target_dy = target_y - m.y
		local target_dist = sqrt(target_dx * target_dx + target_dy * target_dy)

		if target_dist > 2 then
			local move_speed = cfg.chase_speed * dt
			local norm = target_dist > 0 and target_dist or 1
			m.x = m.x + (target_dx / norm) * move_speed
			m.y = m.y + (target_dy / norm) * move_speed
		end

		-- Check if in attack range and ready to attack
		if dist < cfg.target_distance and now >= m.last_attack_time + cfg.attack_cooldown then
			start_minion_attack(m)
		end
	else
		m.state = "idle"
		-- Drift slowly when idle
		m.orbit_angle = m.orbit_angle + cfg.orbit_speed * 0.3 * dt
	end

	-- Update animation
	update_minion_animation(m)
end

-- ============================================
-- ATTACK PATTERN (N, S, E, W)
-- ============================================

function start_minion_attack(m)
	local cfg = ALIEN_MINION_CONFIG
	m.attacking = true
	m.attack_pulse_count = 0
	m.attack_pulse_timer = time()
	m.last_attack_time = time()
	m.anim_frame = 0
	m.anim_timer = time()
end

function update_minion_attack(m)
	local cfg = ALIEN_MINION_CONFIG
	local now = time()

	-- Check if time to fire next pulse
	if now >= m.attack_pulse_timer + cfg.pulse_interval then
		fire_minion_bullets(m)
		m.attack_pulse_count = m.attack_pulse_count + 1
		m.attack_pulse_timer = now

		-- Check if attack is complete
		if m.attack_pulse_count >= cfg.attack_pulses then
			m.attacking = false
			m.state = "idle"
		end
	end
end

function fire_minion_bullets(m)
	local cfg = ALIEN_MINION_CONFIG

	-- Fire in 4 directions: N, S, E, W
	local directions = {
		{ vx = 0, vy = -cfg.bullet_speed },  -- North
		{ vx = 0, vy = cfg.bullet_speed },   -- South
		{ vx = cfg.bullet_speed, vy = 0 },   -- East
		{ vx = -cfg.bullet_speed, vy = 0 },  -- West
	}

	for _, dir in ipairs(directions) do
		local bullet = {
			x = m.x,
			y = m.y,
			vx = dir.vx,
			vy = dir.vy,
			damage = cfg.bullet_damage,
			sprite = cfg.bullet_sprite,
			spawn_time = time(),
			owner = "minion",
		}
		add(alien_minion_bullets, bullet)
	end
	sfx(SFX.bullet_shot)
end

-- ============================================
-- BULLETS UPDATE
-- ============================================

function update_alien_minion_bullets()
	local now = time()

	for i = #alien_minion_bullets, 1, -1 do
		local b = alien_minion_bullets[i]
		local dt = 1/60

		-- Move bullet
		b.x = b.x + b.vx * dt
		b.y = b.y + b.vy * dt

		-- Check collision with player
		local dx = b.x - game.player.x
		local dy = b.y - game.player.y
		local dist = sqrt(dx * dx + dy * dy)

		if dist < 12 then  -- player collision radius
			damage_player(b.damage)
			add_collision_effect(b.x, b.y, 0.2)
			deli(alien_minion_bullets, i)
		-- Check collision with buildings (player can hide behind them)
		elseif point_in_building and point_in_building(b.x, b.y) then
			deli(alien_minion_bullets, i)
		-- Remove if too old (3 seconds) or off screen
		elseif now - b.spawn_time > 3 then
			deli(alien_minion_bullets, i)
		elseif b.x < -500 or b.x > 500 or b.y < -500 or b.y > 500 then
			deli(alien_minion_bullets, i)
		end
	end
end

-- ============================================
-- ANIMATION
-- ============================================

function update_minion_animation(m)
	local cfg = ALIEN_MINION_CONFIG
	local now = time()

	-- Determine animation speed and frame count based on state
	local anim_speed, max_frames

	if m.hit_flash and now < m.hit_flash then
		-- Damaged animation (fast flicker)
		anim_speed = cfg.damaged_animation_speed
		max_frames = cfg.damaged_frames
		if now >= m.damaged_anim_timer + anim_speed then
			m.damaged_anim_timer = now
			m.damaged_frame = (m.damaged_frame + 1) % max_frames
		end
		return  -- Skip normal animation during hit flash
	elseif m.attacking then
		anim_speed = cfg.attack_animation_speed
		max_frames = cfg.attack_frames
	elseif m.state == "chasing" then
		anim_speed = cfg.move_animation_speed
		max_frames = cfg.move_frames
	else
		anim_speed = cfg.idle_animation_speed
		max_frames = cfg.idle_frames
	end

	-- Update animation frame
	if now >= m.anim_timer + anim_speed then
		m.anim_timer = now
		m.anim_frame = (m.anim_frame + 1) % max_frames
	end
end

function get_minion_sprite(m)
	local cfg = ALIEN_MINION_CONFIG
	local base = cfg.sprite_base
	local now = time()

	-- Damaged sprite takes priority
	if m.hit_flash and now < m.hit_flash then
		return base + cfg.damaged_start + m.damaged_frame
	elseif m.attacking then
		return base + cfg.attack_start + m.anim_frame
	elseif m.state == "chasing" then
		return base + cfg.move_start + m.anim_frame
	else
		return base + cfg.idle_start + m.anim_frame
	end
end

-- ============================================
-- DAMAGE
-- ============================================

function damage_alien_minion(minion, amount)
	if not minion then return end
	if minion.state == "dead" then return end

	local cfg = ALIEN_MINION_CONFIG

	minion.health = max(0, minion.health - amount)
	minion.hit_flash = time() + cfg.hit_flash_duration
	minion.damaged_frame = 0
	minion.damaged_anim_timer = time()

	add_collision_effect(minion.x, minion.y, 0.2)
	sfx(SFX.vehicle_collision)  -- damage sound

	if minion.health <= 0 then
		minion.state = "dead"
		add_collision_effect(minion.x, minion.y, 0.5)
		printh("Alien minion killed!")
	end
end

-- ============================================
-- HIT DETECTION
-- ============================================

function check_alien_minion_hit(proj_x, proj_y, radius)
	radius = radius or 10
	local cfg = ALIEN_MINION_CONFIG

	for _, m in ipairs(alien_minions) do
		if m.state ~= "dead" then
			local dx = proj_x - m.x
			local dy = proj_y - m.y
			local dist = sqrt(dx * dx + dy * dy)

			if dist < cfg.collision_radius + radius then
				return m  -- Return the minion that was hit
			end
		end
	end

	return nil
end

-- ============================================
-- RENDERING
-- ============================================

function add_alien_minions_to_visible(visible)
	for _, m in ipairs(alien_minions) do
		if m.state ~= "dead" then
			local sx, sy = world_to_screen(m.x, m.y)

			-- Only add if on screen
			if sx > -32 and sx < SCREEN_W + 32 and sy > -32 and sy < SCREEN_H + 32 then
				local feet_y = m.y + 8
				add(visible, {
					type = "alien_minion",
					y = feet_y,
					cx = m.x,
					cy = m.y,
					sx = sx,
					sy = sy,
					data = m,
				})
			end
		end
	end
end

function draw_alien_minion(m, sx, sy)
	local cfg = ALIEN_MINION_CONFIG

	-- Shadow is now drawn in building.lua shadow pass (with color table for transparency)

	local sprite_id = get_minion_sprite(m)
	local sprite = get_spr(sprite_id)

	local src_size = cfg.sprite_size
	local scale = cfg.sprite_scale
	local dst_size = src_size * scale

	-- Apply hover offset to draw position (float above ground)
	local hover = m.hover_offset or 0
	local draw_x = sx - dst_size / 2
	local draw_y = sy - dst_size + 4 + hover

	local flip_x = not m.facing_right

	sspr(sprite, 0, 0, src_size, src_size, draw_x, draw_y, dst_size, dst_size, flip_x)
end

function draw_alien_minion_bullets()
	for _, b in ipairs(alien_minion_bullets) do
		local sx, sy = world_to_screen(b.x, b.y)

		-- Only draw if on screen
		if sx > -16 and sx < SCREEN_W + 16 and sy > -16 and sy < SCREEN_H + 16 then
			local sprite = get_spr(b.sprite)
			sspr(sprite, 0, 0, 16, 16, sx - 8, sy - 8, 16, 16)
		end
	end
end

-- ============================================
-- CLEANUP
-- ============================================

function cleanup_alien_minions()
	alien_minions = {}
	alien_minion_bullets = {}
	last_minion_spawn_time = 0

	printh("Alien minions cleaned up")
end
