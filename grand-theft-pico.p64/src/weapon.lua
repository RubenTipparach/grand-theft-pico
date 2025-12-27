--[[pod_format="raw"]]
-- weapon.lua - Weapon system, projectiles, and combat

-- ============================================
-- PROJECTILE SYSTEM
-- ============================================

-- Global projectile list
projectiles = {}

-- Create a new projectile
function create_projectile(x, y, dir, weapon_key, owner)
	local weapon = WEAPON_CONFIG.ranged[weapon_key]
	if not weapon then return end

	-- Direction vectors
	local dir_vectors = {
		north = { dx = 0, dy = -1 },
		south = { dx = 0, dy = 1 },
		east  = { dx = 1, dy = 0 },
		west  = { dx = -1, dy = 0 },
	}
	local vec = dir_vectors[dir]
	if not vec then return end

	-- Determine sprite(s)
	local sprite, sprite_frames
	if weapon.sprite_frames then
		sprite_frames = weapon.sprite_frames
		sprite = sprite_frames[1]
	elseif weapon.sprite_ew and weapon.sprite_ns then
		-- Direction-based sprite
		if dir == "north" or dir == "south" then
			sprite = weapon.sprite_ns
		else
			sprite = weapon.sprite_ew
		end
	end

	local proj = {
		x = x,
		y = y,
		dx = vec.dx,
		dy = vec.dy,
		speed = weapon.bullet_speed,
		damage = weapon.damage,
		owner = owner,  -- "player" or dealer reference
		sprite = sprite,
		sprite_frames = sprite_frames,
		frame_index = 1,
		frame_timer = 0,
		animation_speed = weapon.animation_speed or 0.1,
		weapon_key = weapon_key,
	}

	add(projectiles, proj)
	return proj
end

-- Update all projectiles
function update_projectiles()
	local now = time()
	local to_remove = {}

	for i, proj in ipairs(projectiles) do
		-- Move projectile
		local dt = 1/60  -- assume 60fps
		proj.x = proj.x + proj.dx * proj.speed * dt
		proj.y = proj.y + proj.dy * proj.speed * dt

		-- Animate if has frames
		if proj.sprite_frames then
			proj.frame_timer = proj.frame_timer + dt
			if proj.frame_timer >= proj.animation_speed then
				proj.frame_timer = 0
				proj.frame_index = (proj.frame_index % #proj.sprite_frames) + 1
				proj.sprite = proj.sprite_frames[proj.frame_index]
			end
		end

		-- Check if off screen (despawn)
		local sx, sy = world_to_screen(proj.x, proj.y)
		if sx < -16 or sx > SCREEN_W + 16 or sy < -16 or sy > SCREEN_H + 16 then
			add(to_remove, i)
		else
			-- Check collisions
			local hit = check_projectile_collision(proj)
			if hit then
				add(to_remove, i)
			end
		end
	end

	-- Remove projectiles (in reverse order to maintain indices)
	for i = #to_remove, 1, -1 do
		del(projectiles, projectiles[to_remove[i]])
	end
end

-- Check projectile collision with entities
function check_projectile_collision(proj)
	-- Player projectiles can hit: dealers (hostile), enemies
	-- Dealer/enemy projectiles can hit: player
	-- All projectiles can hit NPCs (no damage, but popularity loss)

	if proj.owner == "player" then
		-- Check collision with dealers (any state except dead)
		if arms_dealers then
			for _, dealer in ipairs(arms_dealers) do
				if dealer.state ~= "dead" then
					local dx = proj.x - dealer.x
					local dy = proj.y - dealer.y
					local dist = sqrt(dx * dx + dy * dy)
					if dist < 12 then
						-- Hit dealer - damage and make hostile
						dealer.health = dealer.health - proj.damage
						make_dealer_hostile(dealer)
						return true
					end
				end
			end
		end

		-- Check collision with regular NPCs (no damage, popularity loss)
		for _, npc in ipairs(npcs) do
			local dx = proj.x - npc.x
			local dy = proj.y - npc.y
			local dist = sqrt(dx * dx + dy * dy)
			if dist < 8 then
				-- Hit NPC - popularity loss, NPC panics
				change_popularity(-WEAPON_CONFIG.npc_hit_popularity_loss)
				-- Make NPC flee
				npc.state = "surprised"
				npc.state_end_time = time() + 0.3
				npc.scare_player_x = game.player.x
				npc.scare_player_y = game.player.y
				return true
			end
		end
	else
		-- Enemy/dealer projectile - check collision with player
		local dx = proj.x - game.player.x
		local dy = proj.y - game.player.y
		local dist = sqrt(dx * dx + dy * dy)
		if dist < 10 then
			-- Hit player
			game.player.health = max(0, game.player.health - proj.damage)
			return true
		end
	end

	return false
end

-- Draw all projectiles
function draw_projectiles()
	for _, proj in ipairs(projectiles) do
		local sx, sy = world_to_screen(proj.x, proj.y)
		-- Center the sprite (assuming 8x8)
		spr(proj.sprite, sx - 4, sy - 4)
	end
end

-- ============================================
-- WEAPON MANAGEMENT
-- ============================================

-- Get the currently equipped weapon data
function get_equipped_weapon()
	local p = game.player
	if p.equipped_index == 0 or #p.weapons == 0 then
		return nil, nil
	end

	local weapon_key = p.weapons[p.equipped_index]
	if not weapon_key then return nil, nil end

	-- Check if melee or ranged
	if WEAPON_CONFIG.melee[weapon_key] then
		return WEAPON_CONFIG.melee[weapon_key], "melee"
	elseif WEAPON_CONFIG.ranged[weapon_key] then
		return WEAPON_CONFIG.ranged[weapon_key], "ranged"
	end

	return nil, nil
end

-- Get the key of currently equipped weapon
function get_equipped_weapon_key()
	local p = game.player
	if p.equipped_index == 0 or #p.weapons == 0 then
		return nil
	end
	return p.weapons[p.equipped_index]
end

-- Cycle to next weapon
function cycle_weapon_forward()
	local p = game.player
	if #p.weapons == 0 then return end

	p.equipped_index = p.equipped_index + 1
	if p.equipped_index > #p.weapons then
		p.equipped_index = 0  -- Unequip
	end
end

-- Cycle to previous weapon
function cycle_weapon_backward()
	local p = game.player
	if #p.weapons == 0 then return end

	p.equipped_index = p.equipped_index - 1
	if p.equipped_index < 0 then
		p.equipped_index = #p.weapons
	end
end

-- Give player a weapon (called when purchased)
function give_weapon(weapon_key)
	local p = game.player
	-- Check if already owned
	for _, w in ipairs(p.weapons) do
		if w == weapon_key then return false end
	end

	-- Add weapon in order defined by weapon_order
	local order = WEAPON_CONFIG.weapon_order
	local insert_idx = #p.weapons + 1

	for i, key in ipairs(order) do
		if key == weapon_key then
			-- Find position based on order
			for j, owned in ipairs(p.weapons) do
				for k, ok in ipairs(order) do
					if ok == owned and k > i then
						insert_idx = j
						break
					end
				end
				if insert_idx <= #p.weapons then break end
			end
			break
		end
	end

	-- Insert at correct position
	if insert_idx > #p.weapons then
		add(p.weapons, weapon_key)
	else
		-- Shift and insert
		local new_weapons = {}
		for j = 1, insert_idx - 1 do
			add(new_weapons, p.weapons[j])
		end
		add(new_weapons, weapon_key)
		for j = insert_idx, #p.weapons do
			add(new_weapons, p.weapons[j])
		end
		p.weapons = new_weapons
	end

	-- Initialize ammo for ranged weapons
	if WEAPON_CONFIG.ranged[weapon_key] then
		p.ammo[weapon_key] = p.ammo[weapon_key] or 0
	end

	-- Equip if first weapon
	if p.equipped_index == 0 then
		p.equipped_index = 1
	end

	return true
end

-- Add ammo for a ranged weapon
function add_ammo(weapon_key, amount)
	local p = game.player
	if WEAPON_CONFIG.ranged[weapon_key] then
		p.ammo[weapon_key] = (p.ammo[weapon_key] or 0) + amount
		return true
	end
	return false
end

-- Check if player owns a weapon
function owns_weapon(weapon_key)
	for _, w in ipairs(game.player.weapons) do
		if w == weapon_key then return true end
	end
	return false
end

-- ============================================
-- ATTACK HANDLING
-- ============================================

-- Try to attack with current weapon
function try_attack()
	local p = game.player
	local weapon, wtype = get_equipped_weapon()

	if not weapon then return false end

	local now = time()

	if wtype == "melee" then
		-- Melee attack (no panic trigger - melee is quiet)
		if not p.is_attacking then
			p.is_attacking = true
			p.attack_timer = now
			p.attack_angle = 0  -- Start angle
			return true
		end
	elseif wtype == "ranged" then
		-- Ranged attack
		local weapon_key = get_equipped_weapon_key()
		local ammo = p.ammo[weapon_key] or 0

		if ammo <= 0 then
			return false  -- No ammo
		end

		if now < p.fire_cooldown then
			return false  -- Still on cooldown
		end

		-- Fire projectile
		p.ammo[weapon_key] = ammo - 1
		p.fire_cooldown = now + weapon.fire_rate

		-- Create projectile from player position
		create_projectile(p.x, p.y, p.facing_dir, weapon_key, "player")

		-- Trigger NPC panic
		trigger_weapon_panic()

		return true
	end

	return false
end

-- Update melee attack animation
function update_melee_attack()
	local p = game.player
	if not p.is_attacking then return end

	local weapon, wtype = get_equipped_weapon()
	if not weapon or wtype ~= "melee" then
		p.is_attacking = false
		return
	end

	local now = time()
	local elapsed = now - p.attack_timer
	local progress = elapsed / weapon.swing_speed

	if progress >= 1 then
		-- Attack finished
		p.is_attacking = false
		p.attack_angle = 0
	else
		-- Update swing angle (-45 to +90 degrees)
		p.attack_angle = -45 + (135 * progress)

		-- Check for hit at peak of swing (around 50% progress)
		if progress > 0.4 and progress < 0.6 and not p.attack_hit_checked then
			check_melee_hit(weapon)
			p.attack_hit_checked = true
		end
	end

	-- Reset hit check when attack ends
	if not p.is_attacking then
		p.attack_hit_checked = false
	end
end

-- Check if melee attack hits anything
function check_melee_hit(weapon)
	local p = game.player

	-- Calculate hit position based on facing direction
	local dir_vectors = {
		north = { dx = 0, dy = -1 },
		south = { dx = 0, dy = 1 },
		east  = { dx = 1, dy = 0 },
		west  = { dx = -1, dy = 0 },
	}
	local vec = dir_vectors[p.facing_dir]
	local hit_x = p.x + vec.dx * weapon.range
	local hit_y = p.y + vec.dy * weapon.range

	-- Check dealers (any state except dead)
	if arms_dealers then
		for _, dealer in ipairs(arms_dealers) do
			if dealer.state ~= "dead" then
				local dx = hit_x - dealer.x
				local dy = hit_y - dealer.y
				local dist = sqrt(dx * dx + dy * dy)
				if dist < weapon.range then
					dealer.health = dealer.health - weapon.damage
					make_dealer_hostile(dealer)
					return true
				end
			end
		end
	end

	-- Check NPCs (popularity loss only)
	for _, npc in ipairs(npcs) do
		local dx = hit_x - npc.x
		local dy = hit_y - npc.y
		local dist = sqrt(dx * dx + dy * dy)
		if dist < weapon.range then
			change_popularity(-WEAPON_CONFIG.npc_hit_popularity_loss)
			npc.state = "surprised"
			npc.state_end_time = time() + 0.3
			npc.scare_player_x = p.x
			npc.scare_player_y = p.y
			return true
		end
	end

	return false
end

-- Trigger panic for all visible NPCs when weapon is fired/swung
function trigger_weapon_panic()
	local p = game.player

	for _, npc in ipairs(npcs) do
		-- Check if on screen
		local sx, sy = world_to_screen(npc.x, npc.y)
		if sx > -16 and sx < SCREEN_W + 16 and sy > -16 and sy < SCREEN_H + 16 then
			-- Skip if already fleeing or in dialog
			if npc.state ~= "fleeing" and not npc.in_dialog then
				npc.state = "surprised"
				npc.state_end_time = time() + 0.5
				npc.scare_player_x = p.x
				npc.scare_player_y = p.y
			end
		end
	end
end

-- ============================================
-- WEAPON DISPLAY
-- ============================================

-- Draw equipped weapon indicator
function draw_weapon_hud()
	local weapon, wtype = get_equipped_weapon()
	local weapon_key = get_equipped_weapon_key()

	-- Position in top-right area
	local x = SCREEN_W - 80
	local y = 8

	if not weapon then
		print_shadow("No Weapon", x, y, 6)
		return
	end

	-- Weapon name
	print_shadow(weapon.name, x, y, 7)

	-- Ammo count for ranged weapons
	if wtype == "ranged" then
		local ammo = game.player.ammo[weapon_key] or 0
		print_shadow("Ammo: " .. ammo, x, y + 10, ammo > 0 and 11 or 8)
	end
end

-- ============================================
-- ROTATED SPRITE RENDERING (for melee weapons)
-- Based on rspr.lua snippet for Picotron
-- ============================================

-- Draw a textured quad using tline3d (helper for rspr)
function tquad(coords, tex, dx, dy)
	local screen_max = get_display():height() - 1
	local p0, spans = coords[#coords], {}
	local x0, y0, u0, v0 = p0.x + dx, p0.y + dy, p0.u, p0.v
	for i = 1, #coords do
		local p1 = coords[i]
		local x1, y1, u1, v1 = p1.x + dx, p1.y + dy, p1.u, p1.v
		local _x1, _y1, _u1, _v1 = x1, y1, u1, v1
		if y0 > y1 then
			x0, y0, x1, y1, u0, v0, u1, v1 = x1, y1, x0, y0, u1, v1, u0, v0
		end
		local dy_val = y1 - y0
		local dx_step, du, dv = (x1 - x0) / dy_val, (u1 - u0) / dy_val, (v1 - v0) / dy_val
		if y0 < 0 then
			x0 = x0 - y0 * dx_step
			u0 = u0 - y0 * du
			v0 = v0 - y0 * dv
			y0 = 0
		end
		local cy0 = ceil(y0)
		local sy_val = cy0 - y0
		x0 = x0 + sy_val * dx_step
		u0 = u0 + sy_val * du
		v0 = v0 + sy_val * dv
		for y = cy0, min(ceil(y1) - 1, screen_max) do
			local span = spans[y]
			if span then
				tline3d(tex, span.x, y, x0, y, span.u, span.v, u0, v0)
			else
				spans[y] = { x = x0, u = u0, v = v0 }
			end
			x0 = x0 + dx_step
			u0 = u0 + du
			v0 = v0 + dv
		end
		x0, y0, u0, v0 = _x1, _y1, _u1, _v1
	end
end

-- Draw rotated sprite at center position
-- sprite: sprite ID
-- cx, cy: center position on screen
-- sx, sy: scale (1 = normal)
-- rot: rotation in turns (0-1 = 0-360 degrees)
function rspr(sprite, cx, cy, sx, sy, rot)
	sx = sx and sx or 1
	sy = sy and sy or 1
	rot = rot and rot or 0
	local tex = get_spr(sprite)
	local dx, dy = tex:width() * sx, tex:height() * sy
	local quad = {
		{ x = 0,  y = 0,  u = 0,                  v = 0 },
		{ x = dx, y = 0,  u = tex:width() - 0.001, v = 0 },
		{ x = dx, y = dy, u = tex:width() - 0.001, v = tex:height() - 0.001 },
		{ x = 0,  y = dy, u = 0,                  v = tex:height() - 0.001 },
	}
	local c, s = cos(rot), -sin(rot)
	local w, h = (dx - 1) / 2, (dy - 1) / 2
	for _, v in pairs(quad) do
		local x, y = v.x - w, v.y - h
		v.x = c * x - s * y
		v.y = s * x + c * y
	end
	tquad(quad, tex, cx, cy)
end

-- Draw equipped melee weapon on player
-- Weapon sprite faces west by default
-- Uses quad rotation for proper swing animation
function draw_melee_weapon()
	local p = game.player
	local weapon, wtype = get_equipped_weapon()
	if not weapon or wtype ~= "melee" then return end

	local screen_x, screen_y = world_to_screen(p.x, p.y)
	local dir = p.facing_dir or "east"
	local cfg = WEAPON_CONFIG

	-- Determine facing direction for weapon positioning
	-- facing_right = true means player is facing LEFT (west) due to input.lua logic
	local facing_east = not p.facing_right
	local offset_x = 0

	-- Base rotation in turns (0-1 range) from config
	local base_rot = 0

	if dir == "east" or (dir == "north" and facing_east) or (dir == "south" and facing_east) then
		-- Facing east - weapon on right side
		offset_x = 6
		base_rot = cfg.melee_base_rot_east
	else
		-- Facing west - weapon on left side
		offset_x = -6
		base_rot = cfg.melee_base_rot_west
	end

	-- Calculate swing rotation when attacking
	local swing_rot = 0
	if p.is_attacking then
		local progress = 0
		if p.attack_timer then
			local elapsed = time() - p.attack_timer
			progress = elapsed / weapon.swing_speed
			if progress > 1 then progress = 1 end
		end
		-- Swing arc from config (0 to 0.25 turns = 0 to 90 degrees)
		local swing_range = cfg.melee_swing_end - cfg.melee_swing_start
		swing_rot = cfg.melee_swing_start + (swing_range * progress)

		-- Mirror swing direction when facing west
		if not facing_east then
			swing_rot = -swing_rot
		end
	end

	-- Final rotation
	local rot = base_rot + swing_rot

	-- Draw position (offset from player center)
	local wx = screen_x + offset_x
	local wy = screen_y - 4

	-- Draw rotated weapon sprite
	rspr(weapon.sprite, wx, wy, 1, 1, rot)
end
