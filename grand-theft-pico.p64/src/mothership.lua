--[[pod_format="raw"]]
-- mothership.lua - Alien Mothership final boss

-- ============================================
-- MOTHERSHIP STATE
-- ============================================

mothership = nil
mothership_bullets = {}
mothership_spawned = false

-- Spiral attack state
mothership_spiral_active = false
mothership_spiral_start_time = 0
mothership_spiral_bullets_fired = 0
mothership_spiral_base_angle = 0
mothership_last_spiral_time = 0

-- Building destruction state
mothership_buildings_destroyed = false
mothership_destruction_time = 0

-- Death/victory state
mothership_dying = false
mothership_death_time = 0
mothership_defeated_message_active = false
mothership_defeated_message_time = 0

-- ============================================
-- MOTHERSHIP CREATION
-- ============================================

function create_mothership(x, y)
	local cfg = MOTHERSHIP_CONFIG
	return {
		x = x,
		y = y,
		health = cfg.health,
		max_health = cfg.health,
		state = "idle",  -- "idle", "attacking", "dying", "dead"

		-- Movement (circular drift)
		drift_angle = 0,
		drift_center_x = x,
		drift_center_y = y,

		-- Attack timing
		last_attack_time = 0,

		-- Hit flash
		hit_flash = 0,

		-- Spawn time for delays
		spawn_time = time(),
	}
end

-- ============================================
-- SPAWNING
-- ============================================

function spawn_mothership()
	if mothership then return end

	local cfg = MOTHERSHIP_CONFIG
	mothership = create_mothership(cfg.spawn_x, cfg.spawn_y)
	mothership_spawned = true
	mothership_buildings_destroyed = false
	mothership_destruction_time = time() + cfg.destruction_delay
	mothership_last_spiral_time = time()

	printh("Mothership spawned at " .. cfg.spawn_x .. ", " .. cfg.spawn_y)
end

-- ============================================
-- UPDATE
-- ============================================

function update_mothership()
	if not mothership then return end
	if mothership.state == "dead" then return end

	local cfg = MOTHERSHIP_CONFIG
	local now = time()
	local dt = 1/60  -- approximate delta time

	-- Check for death
	if mothership.health <= 0 and mothership.state ~= "dying" and mothership.state ~= "dead" then
		start_mothership_death()
		return
	end

	-- Handle dying state
	if mothership.state == "dying" then
		update_mothership_death()
		return
	end

	-- Update drift movement (circular pattern)
	mothership.drift_angle = mothership.drift_angle + cfg.drift_speed * dt * 0.01
	mothership.x = mothership.drift_center_x + cos(mothership.drift_angle) * cfg.drift_radius
	mothership.y = mothership.drift_center_y + sin(mothership.drift_angle) * cfg.drift_radius

	-- Building destruction (once, after delay)
	if not mothership_buildings_destroyed and now >= mothership_destruction_time then
		mothership_destroy_buildings()
		mothership_buildings_destroyed = true
	end

	-- Spiral attack pattern
	if mothership_spiral_active then
		update_spiral_attack()
	elseif now >= mothership_last_spiral_time + cfg.spiral_cooldown then
		start_spiral_attack()
	end

	-- Update bullets
	update_mothership_bullets()
end

-- ============================================
-- SPIRAL ATTACK
-- ============================================

function start_spiral_attack()
	mothership_spiral_active = true
	mothership_spiral_start_time = time()
	mothership_spiral_bullets_fired = 0
	mothership_spiral_base_angle = 0
	mothership.state = "attacking"
	printh("Mothership starting spiral attack")
end

function update_spiral_attack()
	local cfg = MOTHERSHIP_CONFIG
	local now = time()
	local elapsed = now - mothership_spiral_start_time

	-- Calculate how many bullets should have been fired by now
	local expected_bullets = flr(elapsed / cfg.spiral_fire_interval)

	-- Fire bullets until we've caught up
	while mothership_spiral_bullets_fired < expected_bullets and mothership_spiral_bullets_fired < cfg.spiral_total_bullets do
		fire_spiral_bullet()
		mothership_spiral_bullets_fired = mothership_spiral_bullets_fired + 1
	end

	-- Check if spiral is complete
	if mothership_spiral_bullets_fired >= cfg.spiral_total_bullets then
		mothership_spiral_active = false
		mothership_last_spiral_time = now
		mothership.state = "idle"
		printh("Mothership spiral attack complete")
	end
end

function fire_spiral_bullet()
	local cfg = MOTHERSHIP_CONFIG

	-- Calculate angle for this bullet (spiral effect)
	local angle = mothership_spiral_base_angle + (mothership_spiral_bullets_fired * cfg.spiral_angle_step)

	-- Convert angle (in turns) to velocity
	local vx = cos(angle) * cfg.spiral_bullet_speed
	local vy = sin(angle) * cfg.spiral_bullet_speed

	local bullet = {
		x = mothership.x,
		y = mothership.y,
		vx = vx,
		vy = vy,
		damage = cfg.spiral_damage,
		sprite = cfg.laser_sprite,
		spawn_time = time(),
		owner = "mothership",
	}

	add(mothership_bullets, bullet)
end

-- ============================================
-- BUILDING DESTRUCTION
-- ============================================

function mothership_destroy_buildings()
	local cfg = MOTHERSHIP_CONFIG
	local center_x = cfg.spawn_x
	local center_y = cfg.spawn_y
	local radius = cfg.destruction_radius

	printh("Mothership destroying buildings in radius " .. radius)

	-- Find buildings near center and destroy them
	local buildings_to_destroy = {}
	for _, b in ipairs(buildings) do
		local bx = b.x + b.w / 2
		local by = b.y + b.h / 2
		local dx = bx - center_x
		local dy = by - center_y
		local dist = sqrt(dx * dx + dy * dy)

		if dist < radius then
			add(buildings_to_destroy, b)
		end
	end

	-- Trigger collapse for each building (staggered)
	for i, b in ipairs(buildings_to_destroy) do
		-- Add explosion effect at building center
		local bx = b.x + b.w / 2
		local by = b.y + b.h / 2
		add_collision_effect(bx, by, 1.0)

		-- Start collapse (only one can collapse at a time, so we demolish others directly)
		if i == 1 then
			start_building_collapse(b)
		else
			-- For now, just mark as collapsed
			b.collapsing = true
			b.collapse_offset = 100
		end
	end

	printh("Destroyed " .. #buildings_to_destroy .. " buildings")
end

-- ============================================
-- BULLETS UPDATE
-- ============================================

function update_mothership_bullets()
	local now = time()

	for i = #mothership_bullets, 1, -1 do
		local b = mothership_bullets[i]
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
			deli(mothership_bullets, i)
		-- Remove if too old (5 seconds) or off screen
		elseif now - b.spawn_time > 5 then
			deli(mothership_bullets, i)
		elseif b.x < -500 or b.x > 500 or b.y < -500 or b.y > 500 then
			deli(mothership_bullets, i)
		end
	end
end

-- ============================================
-- DAMAGE & DEATH
-- ============================================

function damage_mothership(amount)
	if not mothership then return end
	if mothership.state == "dying" or mothership.state == "dead" then return end

	mothership.health = max(0, mothership.health - amount)
	mothership.hit_flash = time() + MOTHERSHIP_CONFIG.hit_flash_duration

	add_collision_effect(mothership.x, mothership.y, 0.3)

	printh("Mothership damaged: " .. amount .. ", health: " .. mothership.health)
end

function start_mothership_death()
	mothership.state = "dying"
	mothership_dying = true
	mothership_death_time = time()

	-- Stop spiral attack
	mothership_spiral_active = false

	-- Clear bullets
	mothership_bullets = {}

	printh("Mothership dying!")
end

function update_mothership_death()
	local cfg = MOTHERSHIP_CONFIG
	local now = time()
	local elapsed = now - mothership_death_time

	-- Add intermittent explosions while dying
	if flr(elapsed * 4) ~= flr((elapsed - 1/60) * 4) then
		local ox = (rnd(2) - 1) * 30
		local oy = (rnd(2) - 1) * 30
		add_collision_effect(mothership.x + ox, mothership.y + oy, 0.5)
	end

	-- Final explosion after delay
	if elapsed >= cfg.death_explosion_delay then
		-- Big explosion
		for i = 1, 8 do
			local angle = i / 8
			local dist = 40
			local ox = cos(angle) * dist
			local oy = sin(angle) * dist
			add_collision_effect(mothership.x + ox, mothership.y + oy, 1.0)
		end
		add_collision_effect(mothership.x, mothership.y, 1.5)

		mothership.state = "dead"
		mothership_dying = false

		-- Show victory message
		show_mothership_defeated()

		-- Mark quest as complete
		if mission then
			mission.mothership_killed = true
			check_quest_completion()
		end

		printh("Mothership destroyed!")
	end
end

function show_mothership_defeated()
	mothership_defeated_message_active = true
	mothership_defeated_message_time = time()
end

-- ============================================
-- HIT DETECTION
-- ============================================

function check_mothership_hit(proj_x, proj_y, radius)
	if not mothership then return false end
	if mothership.state == "dying" or mothership.state == "dead" then return false end

	radius = radius or 20
	local cfg = MOTHERSHIP_CONFIG

	local dx = proj_x - mothership.x
	local dy = proj_y - mothership.y
	local dist = sqrt(dx * dx + dy * dy)

	return dist < cfg.collision_radius + radius
end

-- ============================================
-- RENDERING
-- ============================================

function add_mothership_to_visible(visible)
	if not mothership then return end
	if mothership.state == "dead" then return end

	local sx, sy = world_to_screen(mothership.x, mothership.y)

	-- Only add if on screen (with margin for large sprite)
	if sx > -100 and sx < SCREEN_W + 100 and sy > -100 and sy < SCREEN_H + 100 then
		-- Use high Y value so mothership renders on top
		add(visible, {
			type = "mothership",
			y = mothership.y + 1000,  -- Always on top
			cx = mothership.x,
			cy = mothership.y,
			sx = sx,
			sy = sy,
			data = mothership,
		})
	end
end

function draw_mothership(m, sx, sy)
	local cfg = MOTHERSHIP_CONFIG
	local now = time()

	-- Apply hover offset (mothership floats above ground)
	sy = sy + cfg.hover_offset

	-- Get sprite
	local sprite_id = cfg.sprite
	local sprite = get_spr(sprite_id)

	-- Calculate draw position (centered) - support non-square sprites
	local w = cfg.sprite_w
	local h = cfg.sprite_h
	local draw_x = sx - w / 2
	local draw_y = sy - h / 2

	-- Hit flash effect: draw white overlay
	if m.hit_flash and now < m.hit_flash then
		-- Draw normal sprite first
		sspr(sprite, 0, 0, w, h, draw_x, draw_y, w, h)
		-- Draw white flash using fillp pattern (checkerboard for 50% white)
		fillp(0b0101101001011010)
		rectfill(draw_x, draw_y, draw_x + w - 1, draw_y + h - 1, 33)  -- white
		fillp()
	else
		-- Normal draw
		sspr(sprite, 0, 0, w, h, draw_x, draw_y, w, h)
	end
end

function draw_mothership_bullets()
	local cfg = MOTHERSHIP_CONFIG

	for _, b in ipairs(mothership_bullets) do
		local sx, sy = world_to_screen(b.x, b.y)

		-- Only draw if on screen
		if sx > -16 and sx < SCREEN_W + 16 and sy > -16 and sy < SCREEN_H + 16 then
			local sprite = get_spr(b.sprite)
			sspr(sprite, 0, 0, 16, 16, sx - 8, sy - 8, 16, 16)
		end
	end
end

-- ============================================
-- HEALTH BAR
-- ============================================

function draw_mothership_health_bar()
	if not mothership then return end
	if mothership.state == "dead" then return end

	local cfg = MOTHERSHIP_CONFIG

	-- Bar dimensions
	local bar_w = 200
	local bar_h = 12
	local x = (SCREEN_W - bar_w) / 2
	local y = 16

	-- Calculate health percentage
	local health_pct = mothership.health / mothership.max_health
	health_pct = max(0, min(1, health_pct))
	local fill_w = flr(bar_w * health_pct)

	-- Draw boss name
	local name = cfg.name
	local name_w = print(name, 0, -100)
	print_shadow(name, (SCREEN_W - name_w) / 2, y - 10, 12)  -- red

	-- Draw bar background
	rectfill(x, y, x + bar_w, y + bar_h, 1)  -- dark background

	-- Draw health fill
	if fill_w > 0 then
		rectfill(x, y, x + fill_w, y + bar_h, 8)  -- red fill
	end

	-- Draw border
	rect(x, y, x + bar_w, y + bar_h, 12)  -- bright red border
end

-- ============================================
-- VICTORY MESSAGE
-- ============================================

function draw_mothership_defeated_message()
	if not mothership_defeated_message_active then return end

	local cfg = MOTHERSHIP_CONFIG
	local now = time()
	local elapsed = now - mothership_defeated_message_time

	-- Check if we should show options
	if elapsed >= cfg.victory_display_delay then
		draw_victory_options()
		return
	end

	-- Pulsing effect
	local pulse = sin(now * 4)
	local color1 = pulse > 0 and 22 or 21  -- yellow / gold
	local color2 = pulse > 0 and 21 or 22

	-- Draw "CITY SAVED!" text
	local text1 = "CITY SAVED!"
	local text2 = "The alien threat has been defeated!"

	local tw1 = print(text1, 0, -100)
	local tw2 = print(text2, 0, -100)

	local cx = SCREEN_W / 2
	local cy = SCREEN_H / 2 - 20

	print_shadow(text1, cx - tw1/2, cy, color1)
	print_shadow(text2, cx - tw2/2, cy + 16, color2)
end

-- ============================================
-- VICTORY OPTIONS
-- ============================================

victory_option_selected = 1

function draw_victory_options()
	local cx = SCREEN_W / 2
	local cy = SCREEN_H / 2 - 30

	-- Title
	local title = "CONGRATULATIONS!"
	local tw = print(title, 0, -100)
	print_shadow(title, cx - tw/2, cy, 22)  -- yellow

	-- Subtitle
	local sub = "You saved the city from the alien invasion!"
	local sw = print(sub, 0, -100)
	print_shadow(sub, cx - sw/2, cy + 14, 33)  -- white

	-- Options
	local opt1 = "Continue Playing"
	local opt2 = "Return to Menu"

	local ow1 = print(opt1, 0, -100)
	local ow2 = print(opt2, 0, -100)

	local opt_y = cy + 40

	-- Draw option 1
	local c1 = victory_option_selected == 1 and 22 or 6
	print_shadow(opt1, cx - ow1/2, opt_y, c1)
	if victory_option_selected == 1 then
		print_shadow(">", cx - ow1/2 - 12, opt_y, 22)
	end

	-- Draw option 2
	local c2 = victory_option_selected == 2 and 22 or 6
	print_shadow(opt2, cx - ow2/2, opt_y + 14, c2)
	if victory_option_selected == 2 then
		print_shadow(">", cx - ow2/2 - 12, opt_y + 14, 22)
	end

	-- Handle input
	if btnp(2) then  -- up
		victory_option_selected = 1
	elseif btnp(3) then  -- down
		victory_option_selected = 2
	elseif btnp(4) or btnp(5) then  -- confirm
		if victory_option_selected == 1 then
			-- Continue playing - just dismiss the message
			mothership_defeated_message_active = false
			if mission then
				mission.game_complete = true
			end
		else
			-- Return to menu - reset game
			-- TODO: Implement proper menu return
			mothership_defeated_message_active = false
		end
	end
end

-- ============================================
-- CLEANUP
-- ============================================

function cleanup_mothership()
	mothership = nil
	mothership_bullets = {}
	mothership_spawned = false
	mothership_spiral_active = false
	mothership_buildings_destroyed = false
	mothership_dying = false
	mothership_defeated_message_active = false

	printh("Mothership cleaned up")
end
