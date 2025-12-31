--[[pod_format="raw"]]
-- weapon.lua - Weapon system, projectiles, and combat

-- ============================================
-- PROJECTILE SYSTEM
-- ============================================

-- Global projectile list
projectiles = {}

-- ============================================
-- BEAM SYSTEM
-- ============================================

-- Global beam list (active beams currently being rendered)
active_beams = {}

-- Fire a beam weapon (hits everything in its path instantly)
function fire_beam(x, y, dir, weapon_key, owner)
	local weapon = WEAPON_CONFIG.ranged[weapon_key]
	if not weapon or not weapon.is_beam then return end

	-- Direction vectors
	local dir_vectors = {
		north = { dx = 0, dy = -1 },
		south = { dx = 0, dy = 1 },
		east  = { dx = 1, dy = 0 },
		west  = { dx = -1, dy = 0 },
	}
	local vec = dir_vectors[dir]
	if not vec then return end

	-- Calculate beam length (extend to screen edge + margin)
	local beam_length = 500  -- pixels, long enough to go off screen

	-- End point of beam
	local end_x = x + vec.dx * beam_length
	local end_y = y + vec.dy * beam_length

	-- Create visual beam
	local beam = {
		x1 = x,
		y1 = y,
		x2 = end_x,
		y2 = end_y,
		dx = vec.dx,
		dy = vec.dy,
		dir = dir,
		sprite = weapon.beam_sprite,
		width = weapon.beam_width,
		end_time = time() + weapon.beam_duration,
		damage = weapon.damage,
	}
	add(active_beams, beam)

	-- Hit detection along beam path (check all entities)
	check_beam_hits(x, y, vec.dx, vec.dy, beam_length, weapon.damage, owner)

	-- Trigger panic
	trigger_weapon_panic()
end

-- Check beam hits along its path
function check_beam_hits(start_x, start_y, dx, dy, length, damage, owner)
	-- Sample points along beam
	local step = 8  -- check every 8 pixels
	local steps = flr(length / step)

	-- Track already-hit entities to avoid double damage
	local hit_npcs = {}
	local hit_dealers = {}
	local hit_vehicles = {}

	for i = 0, steps do
		local check_x = start_x + dx * i * step
		local check_y = start_y + dy * i * step

		-- Check if off screen (stop checking further)
		local sx, sy = world_to_screen(check_x, check_y)
		if sx < -50 or sx > SCREEN_W + 50 or sy < -50 or sy > SCREEN_H + 50 then
			break
		end

		if owner == "player" then
			-- Check foxes
			local fox = check_fox_hit(check_x, check_y, 12)
			if fox and not hit_dealers[fox] then  -- reuse hit_dealers table for foxes
				damage_fox(fox, damage)
				hit_dealers[fox] = true
			end

			-- Check cactus boss
			if cactus and cactus.state ~= "dead" then
				local cdx = check_x - cactus.x
				local cdy = check_y - cactus.y
				local cdist = sqrt(cdx * cdx + cdy * cdy)
				if cdist < CACTUS_CONFIG.collision_radius then
					damage_cactus(damage)
				end
			end

			-- Check Kathy boss
			if kathy and kathy.state ~= "dead" then
				local kdx = check_x - kathy.x
				local kdy = check_y - kathy.y
				local kdist = sqrt(kdx * kdx + kdy * kdy)
				if kdist < KATHY_CONFIG.collision_radius then
					damage_kathy(damage)
				end
			end

			-- Check Kathy's foxes
			local kathy_fox = check_kathy_fox_hit(check_x, check_y, 12)
			if kathy_fox and not hit_dealers[kathy_fox] then
				damage_kathy_fox(kathy_fox, damage)
				hit_dealers[kathy_fox] = true
			end

			-- Check mothership (use visual position with hover_offset)
			if mothership and mothership.state ~= "dead" and mothership.state ~= "dying" then
				local visual_y = mothership.y + MOTHERSHIP_CONFIG.hover_offset
				local mdx = check_x - mothership.x
				local mdy = check_y - visual_y
				local mdist = sqrt(mdx * mdx + mdy * mdy)
				if mdist < MOTHERSHIP_CONFIG.collision_radius then
					damage_mothership(damage)
				end
			end

			-- Check alien minions
			local alien_minion = check_alien_minion_hit(check_x, check_y, 12)
			if alien_minion and not hit_dealers[alien_minion] then
				damage_alien_minion(alien_minion, damage)
				hit_dealers[alien_minion] = true
			end

			-- Check dealers
			if arms_dealers then
				for _, dealer in ipairs(arms_dealers) do
					if dealer.state ~= "dead" and not hit_dealers[dealer] then
						local ddx = check_x - dealer.x
						local ddy = check_y - dealer.y
						local dist = sqrt(ddx * ddx + ddy * ddy)
						if dist < 16 then
							dealer.health = dealer.health - damage
							make_dealer_hostile(dealer)
							hit_dealers[dealer] = true
							sfx(SFX.vehicle_collision)  -- damage sound
						end
					end
				end
			end

			-- Check NPCs
			for _, npc in ipairs(npcs) do
				if not hit_npcs[npc] then
					local ndx = check_x - npc.x
					local ndy = check_y - npc.y
					local dist = sqrt(ndx * ndx + ndy * ndy)
					if dist < 12 then
						change_popularity(-WEAPON_CONFIG.npc_hit_popularity_loss)
						npc.damaged = true
						npc.damaged_end_time = time() + 0.5
						npc.state = "surprised"
						npc.state_end_time = time() + 0.3
						npc.scare_player_x = game.player.x
						npc.scare_player_y = game.player.y
						remove_fan_status(npc)
						hit_npcs[npc] = true
					end
				end
			end

			-- Check vehicles
			if visible_vehicles_cache then
				for _, vehicle in ipairs(visible_vehicles_cache) do
					if vehicle.state ~= "destroyed" and vehicle.state ~= "exploding" and not hit_vehicles[vehicle] then
						local vw = vehicle.vtype.w / 2
						local vh = vehicle.vtype.h / 2
						local vdx = abs(check_x - vehicle.x)
						local vdy = abs(check_y - vehicle.y)
						if vdx < vw and vdy < vh then
							vehicle.health = vehicle.health - damage
							change_popularity(-WEAPON_CONFIG.npc_hit_popularity_loss)
							hit_vehicles[vehicle] = true
						end
					end
				end
			end
		else
			-- Enemy beam - check player
			local pdx = check_x - game.player.x
			local pdy = check_y - game.player.y
			local dist = sqrt(pdx * pdx + pdy * pdy)
			if dist < 10 then
				damage_player(damage)
				return  -- Player hit, stop checking
			end
		end
	end
end

-- Update active beams (remove expired ones)
function update_beams()
	local now = time()
	for i = #active_beams, 1, -1 do
		if now >= active_beams[i].end_time then
			deli(active_beams, i)
		end
	end
end

-- Draw a stretched beam using tquad
function draw_beam_stretched(beam)
	local sx1, sy1 = world_to_screen(beam.x1, beam.y1)
	local sx2, sy2 = world_to_screen(beam.x2, beam.y2)

	local tex = get_spr(beam.sprite)
	local tw, th = tex:width(), tex:height()

	-- Calculate beam direction and length
	local beam_dx = sx2 - sx1
	local beam_dy = sy2 - sy1
	local beam_len = sqrt(beam_dx * beam_dx + beam_dy * beam_dy)

	if beam_len < 1 then return end

	-- Normalize direction
	local nx = beam_dx / beam_len
	local ny = beam_dy / beam_len

	-- Perpendicular for width
	local px = -ny
	local py = nx

	local half_w = beam.width / 2

	-- Build quad corners (stretched along beam direction)
	-- The texture will tile along the beam length
	local tiles_along = beam_len / tw  -- how many times texture repeats

	local quad = {
		{ x = sx1 + px * half_w, y = sy1 + py * half_w, u = 0, v = 0 },
		{ x = sx2 + px * half_w, y = sy2 + py * half_w, u = tiles_along * tw, v = 0 },
		{ x = sx2 - px * half_w, y = sy2 - py * half_w, u = tiles_along * tw, v = th - 0.001 },
		{ x = sx1 - px * half_w, y = sy1 - py * half_w, u = 0, v = th - 0.001 },
	}

	tquad(quad, tex, 0, 0)
end

-- Draw all active beams
function draw_beams()
	for _, beam in ipairs(active_beams) do
		draw_beam_stretched(beam)
	end
end

-- Create a new projectile
function create_projectile(x, y, dir, weapon_key, owner)
	local weapon = WEAPON_CONFIG.ranged[weapon_key]
	if not weapon then return end

	sfx(SFX.bullet_shot)

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

	-- Track bullet fired stat (only for player projectiles)
	if proj.owner == "player" and game_stats then
		game_stats.bullets_fired = (game_stats.bullets_fired or 0) + 1
	end

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

		-- Check collisions FIRST (before off-screen check)
		local hit = check_projectile_collision(proj)
		if hit then
			add(to_remove, i)
		-- Check building collision (bullets blocked by buildings)
		elseif point_in_building and point_in_building(proj.x, proj.y) then
			add(to_remove, i)
		else
			-- Check if off screen (despawn) - only if no hit
			local sx, sy = world_to_screen(proj.x, proj.y)
			if sx < -16 or sx > SCREEN_W + 16 or sy < -16 or sy > SCREEN_H + 16 then
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
	-- Player projectiles can hit: dealers (hostile), enemies, vehicles
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
					if dist < 16 then  -- 16px radius for 32x32 sprite scaled to 0.5
						-- Hit dealer - damage and make hostile
						dealer.health = dealer.health - proj.damage
						dealer.hit_flash = time() + 0.25  -- Show damaged animation for 0.25 seconds
						dealer.damaged_frame = 0  -- Reset damaged animation
						dealer.damaged_anim_timer = time()
						make_dealer_hostile(dealer)
						add_collision_effect(proj.x, proj.y, 0.3)  -- Small explosion
						sfx(SFX.vehicle_collision)  -- damage sound
						return true
					end
				end
			end
		end

		-- Check collision with vehicles (exclude boats and player's vehicle)
		if vehicles then
			for _, vehicle in ipairs(vehicles) do
				if vehicle.state ~= "destroyed" and vehicle.state ~= "exploding"
				   and not vehicle.is_player_vehicle
				   and not vehicle.vtype.water_only then
					local vw = vehicle.vtype.w / 2
					local vh = vehicle.vtype.h / 2
					local dx = abs(proj.x - vehicle.x)
					local dy = abs(proj.y - vehicle.y)
					if dx < vw and dy < vh then
						-- Hit vehicle - apply damage
						vehicle.health = vehicle.health - proj.damage
						add_collision_effect(proj.x, proj.y, 0.3)  -- Small explosion
						return true
					end
				end
			end
		end

		-- Check collision with foxes
		local fox = check_fox_hit(proj.x, proj.y, 12)
		if fox then
			damage_fox(fox, proj.damage)
			add_collision_effect(proj.x, proj.y, 0.3)
			return true
		end

		-- Check collision with cactus boss
		if cactus and cactus.state ~= "dead" then
			local cdx = proj.x - cactus.x
			local cdy = proj.y - cactus.y
			local cdist = sqrt(cdx * cdx + cdy * cdy)
			if cdist < CACTUS_CONFIG.collision_radius then
				damage_cactus(proj.damage)
				add_collision_effect(proj.x, proj.y, 0.3)
				return true
			end
		end

		-- Check collision with Kathy boss
		if kathy and kathy.state ~= "dead" then
			local kdx = proj.x - kathy.x
			local kdy = proj.y - kathy.y
			local kdist = sqrt(kdx * kdx + kdy * kdy)
			if kdist < KATHY_CONFIG.collision_radius then
				damage_kathy(proj.damage)
				add_collision_effect(proj.x, proj.y, 0.3)
				return true
			end
		end

		-- Check collision with Kathy's foxes
		local kathy_fox = check_kathy_fox_hit(proj.x, proj.y, 12)
		if kathy_fox then
			damage_kathy_fox(kathy_fox, proj.damage)
			add_collision_effect(proj.x, proj.y, 0.3)
			return true
		end

		-- Check collision with mothership
		-- Note: hover_offset is negative (e.g. -80), so visual_y = world_y + hover_offset
		-- We need to check collision against the VISUAL position, not world position
		if mothership and mothership.state ~= "dead" and mothership.state ~= "dying" then
			local visual_y = mothership.y + MOTHERSHIP_CONFIG.hover_offset
			local mdx = proj.x - mothership.x
			local mdy = proj.y - visual_y
			local mdist = sqrt(mdx * mdx + mdy * mdy)
			if mdist < MOTHERSHIP_CONFIG.collision_radius then
				damage_mothership(proj.damage)
				add_collision_effect(proj.x, proj.y, 0.3)
				return true
			end
		end

		-- Check collision with alien minions
		local alien_minion = check_alien_minion_hit(proj.x, proj.y, 12)
		if alien_minion then
			damage_alien_minion(alien_minion, proj.damage)
			add_collision_effect(proj.x, proj.y, 0.3)
			return true
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
				add_collision_effect(proj.x, proj.y, 0.3)  -- Small explosion
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
			damage_player(proj.damage)
			add_collision_effect(proj.x, proj.y, 0.3)  -- Small explosion
			return true
		end
	end

	return false
end

-- Draw all projectiles
function draw_projectiles()
	for _, proj in ipairs(projectiles) do
		local sx, sy = world_to_screen(proj.x, proj.y)
		-- Check if sprite is from extended gfx (dealer bullets use sprite_base 256+)
		if proj.sprite >= 256 then
			-- Use get_spr for extended sprites and sspr to draw
			local sprite_ud = get_spr(proj.sprite)
			if sprite_ud then
				local w, h = sprite_ud:width(), sprite_ud:height()
				sspr(sprite_ud, 0, 0, w, h, sx - w/2, sy - h/2, w, h)
			end
		else
			-- Regular sprite, center it (assuming 8x8)
			spr(proj.sprite, sx - 4, sy - 4)
		end
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
			sfx(SFX.melee_attack)
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

		-- Consume ammo and set cooldown
		p.ammo[weapon_key] = ammo - 1
		p.fire_cooldown = now + weapon.fire_rate

		-- Calculate spawn position using bullet offsets
		local spawn_x = p.x
		local spawn_y = p.y
		local offset_x = weapon.bullet_offset_x or 0
		local offset_y = weapon.bullet_offset_y or 0
		local offset_n_x = weapon.bullet_offset_n_x or 0
		local offset_n_y = weapon.bullet_offset_n_y or offset_x
		local offset_s_x = weapon.bullet_offset_s_x or 0
		local offset_s_y = weapon.bullet_offset_s_y or offset_x

		-- Apply offset based on facing direction
		local dir = p.facing_dir or "east"
		if dir == "east" then
			spawn_x = spawn_x + offset_x
			spawn_y = spawn_y + offset_y
		elseif dir == "west" then
			spawn_x = spawn_x - offset_x
			spawn_y = spawn_y + offset_y
		elseif dir == "north" then
			spawn_x = spawn_x + offset_n_x
			spawn_y = spawn_y - offset_n_y
		elseif dir == "south" then
			spawn_x = spawn_x + offset_s_x
			spawn_y = spawn_y + offset_s_y
		end

		-- Check if beam weapon
		if weapon.is_beam then
			-- Fire beam (hits everything in path instantly)
			fire_beam(spawn_x, spawn_y, p.facing_dir, weapon_key, "player")
		else
			-- Create projectile from calculated position
			create_projectile(spawn_x, spawn_y, p.facing_dir, weapon_key, "player")
			-- Trigger NPC panic
			trigger_weapon_panic()
		end

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

	local cfg = WEAPON_CONFIG
	local now = time()
	local elapsed = now - p.attack_timer
	local swing_time = cfg.melee_swing_time
	local return_time = cfg.melee_return_time
	local total_time = swing_time + return_time

	if elapsed >= total_time then
		-- Attack finished
		p.is_attacking = false
		p.attack_hit_checked = false
	else
		-- Check for hit near end of forward swing (80-100% of swing phase)
		local swing_progress = elapsed / swing_time
		if swing_progress > 0.8 and swing_progress <= 1.0 and not p.attack_hit_checked then
			check_melee_hit(weapon)
			p.attack_hit_checked = true
		end
	end
end

-- Check if melee attack hits anything
function check_melee_hit(weapon)
	local p = game.player
	local cfg = WEAPON_CONFIG
	local dir = p.facing_dir or "east"

	-- Calculate weapon center position (same logic as draw_melee_weapon)
	local facing_east = (dir == "east")
	local offset_x = facing_east and cfg.melee_offset_x or -cfg.melee_offset_x
	local offset_y = cfg.melee_offset_y

	-- Hit position is at the weapon sprite center
	local hit_x = p.x + offset_x
	local hit_y = p.y + offset_y

	-- Check building repair (fix_home quest - hammer hits damaged building)
	local weapon_key = get_equipped_weapon_key()
	if check_building_repair and check_building_repair(hit_x, hit_y, weapon_key) then
		-- Hit the building for repair, don't check other targets
		return true
	end

	-- Check foxes
	local fox = check_fox_hit(hit_x, hit_y, weapon.range)
	if fox then
		damage_fox(fox, weapon.damage)
		return true
	end

	-- Check cactus boss
	if cactus and cactus.state ~= "dead" then
		local cdx = hit_x - cactus.x
		local cdy = hit_y - cactus.y
		local cdist = sqrt(cdx * cdx + cdy * cdy)
		if cdist < weapon.range then
			damage_cactus(weapon.damage)
			return true
		end
	end

	-- Check Kathy boss
	if kathy and kathy.state ~= "dead" then
		local kdx = hit_x - kathy.x
		local kdy = hit_y - kathy.y
		local kdist = sqrt(kdx * kdx + kdy * kdy)
		if kdist < weapon.range then
			damage_kathy(weapon.damage)
			return true
		end
	end

	-- Check Kathy's foxes
	local kathy_fox = check_kathy_fox_hit(hit_x, hit_y, weapon.range)
	if kathy_fox then
		damage_kathy_fox(kathy_fox, weapon.damage)
		return true
	end

	-- Check mothership (use visual position with hover_offset)
	if mothership and mothership.state ~= "dead" and mothership.state ~= "dying" then
		local visual_y = mothership.y + MOTHERSHIP_CONFIG.hover_offset
		local mdx = hit_x - mothership.x
		local mdy = hit_y - visual_y
		local mdist = sqrt(mdx * mdx + mdy * mdy)
		if mdist < MOTHERSHIP_CONFIG.collision_radius + weapon.range then
			damage_mothership(weapon.damage)
			return true
		end
	end

	-- Check alien minions
	local alien_minion = check_alien_minion_hit(hit_x, hit_y, weapon.range)
	if alien_minion then
		damage_alien_minion(alien_minion, weapon.damage)
		return true
	end

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
					sfx(SFX.vehicle_collision)  -- damage sound
					return true
				end
			end
		end
	end

	-- Check vehicles (damage them, lose popularity)
	if visible_vehicles_cache then
		for _, vehicle in ipairs(visible_vehicles_cache) do
			if vehicle.state ~= "destroyed" and vehicle.state ~= "exploding" then
				-- Use vehicle dimensions for hit detection
				local vw = vehicle.vtype.w / 2
				local vh = vehicle.vtype.h / 2
				local dx = abs(hit_x - vehicle.x)
				local dy = abs(hit_y - vehicle.y)
				if dx < vw + weapon.range / 2 and dy < vh + weapon.range / 2 then
					vehicle.health = vehicle.health - weapon.damage
					change_popularity(-WEAPON_CONFIG.npc_hit_popularity_loss)
					return true
				end
			end
		end
	end

	-- Check NPCs (popularity loss, damaged sprite, then flee)
	for _, npc in ipairs(npcs) do
		local dx = hit_x - npc.x
		local dy = hit_y - npc.y
		local dist = sqrt(dx * dx + dy * dy)
		if dist < weapon.range then
			change_popularity(-WEAPON_CONFIG.npc_hit_popularity_loss)
			-- Show damaged sprite briefly
			npc.damaged = true
			npc.damaged_end_time = time() + 0.5
			-- Then flee
			npc.state = "surprised"
			npc.state_end_time = time() + 0.3
			npc.scare_player_x = p.x
			npc.scare_player_y = p.y

			-- If this NPC was a fan or lover, remove them from those lists
			remove_fan_status(npc)

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

	-- Display name (either weapon name or "No Weapon")
	local display_name = weapon and weapon.name or "No Weapon"
	local name_color = weapon and 33 or 6  -- white if weapon, gray if none

	-- Draw [Q] on the left of weapon name
	print_shadow("[Q]", x - 24, y, 6)

	-- Weapon name
	print_shadow(display_name, x, y, name_color)

	-- Draw [R] on the right of weapon name
	local name_width = print(display_name, 0, -100)
	print_shadow("[R]", x + name_width + 4, y, 6)

	-- Ammo count for ranged weapons
	if wtype == "ranged" and weapon_key then
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
				tline3d(tex, span.x, y, x0, y, span.u, span.v, u0, v0, 1, 1, 0x300)
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
-- flip_x: flip horizontally
-- pivot_x, pivot_y: rotation pivot offset from center (flipped with flip_x)
function rspr(sprite, cx, cy, sx, sy, rot, flip_x, pivot_x, pivot_y)
	sx = sx or 1
	sy = sy or 1
	rot = rot or 0
	pivot_x = pivot_x or 0
	pivot_y = pivot_y or 0
	local tex = get_spr(sprite)
	local tw, th = tex:width(), tex:height()
	local dx, dy = tw * sx, th * sy

	-- UV coords (flip_x swaps u values)
	local u0, u1 = 0, tw - 0.001
	if flip_x then
		u0, u1 = u1, u0
		pivot_x = -pivot_x  -- flip pivot x when sprite is flipped
	end

	local quad = {
		{ x = 0,  y = 0,  u = u0, v = 0 },
		{ x = dx, y = 0,  u = u1, v = 0 },
		{ x = dx, y = dy, u = u1, v = th - 0.001 },
		{ x = 0,  y = dy, u = u0, v = th - 0.001 },
	}
	local c, s = cos(rot), -sin(rot)
	-- Pivot point: center + offset
	local w, h = (dx - 1) / 2 + pivot_x, (dy - 1) / 2 + pivot_y
	for _, v in pairs(quad) do
		local x, y = v.x - w, v.y - h
		v.x = c * x - s * y
		v.y = s * x + c * y
	end
	tquad(quad, tex, cx, cy)
end

-- Draw equipped ranged weapon on player
-- Weapon sprite faces east by default
-- W: flip, -x offset
-- E: no flip, +x offset
function draw_ranged_weapon()
	local p = game.player
	local weapon, wtype = get_equipped_weapon()
	if not weapon or wtype ~= "ranged" then return end
	if not weapon.weapon_sprite then return end

	local screen_x, screen_y = world_to_screen(p.x, p.y)
	local dir = p.facing_dir or "east"
	local cfg = WEAPON_CONFIG

	-- Calculate offset and rotation based on direction
	-- Weapon sprite faces east by default (0 rotation)
	local offset_x, offset_y = 0, 0
	local rot = 0
	local flip_x = false

	if dir == "east" then
		offset_x = cfg.ranged_offset_x
		offset_y = cfg.ranged_offset_y
		rot = 0
	elseif dir == "west" then
		offset_x = -cfg.ranged_offset_x
		offset_y = cfg.ranged_offset_y
		rot = 0
		flip_x = true
	elseif dir == "north" then
		offset_x = cfg.ranged_offset_y  -- Use y offset for x when vertical
		offset_y = -cfg.ranged_offset_x
		rot = 0.75  -- 270 degrees (pointing up)
	elseif dir == "south" then
		offset_x = cfg.ranged_offset_y
		offset_y = cfg.ranged_offset_x
		rot = 0.25  -- 90 degrees (pointing down)
	end

	-- Draw the weapon sprite with rotation
	rspr(weapon.weapon_sprite, screen_x + offset_x, screen_y + offset_y, 1, 1, rot, flip_x, 0, 0)
end

-- Draw equipped melee weapon on player
-- Weapon sprite faces west by default
-- N/S: keep last horizontal facing for weapon position
-- W: no flip, -x offset
-- E: flip, +x offset
function draw_melee_weapon()
	local p = game.player
	local weapon, wtype = get_equipped_weapon()
	if not weapon or wtype ~= "melee" then return end

	local screen_x, screen_y = world_to_screen(p.x, p.y)
	local dir = p.facing_dir or "east"
	local cfg = WEAPON_CONFIG

	-- Only E/W affect weapon position, N/S keep last horizontal
	local facing_east = (dir == "east")
	local offset_x = facing_east and cfg.melee_offset_x or -cfg.melee_offset_x
	local flip_x = facing_east

	-- Base rotation
	local base_rot = facing_east and cfg.melee_base_rot_east or cfg.melee_base_rot_west

	-- Calculate swing rotation when attacking or returning
	local swing_rot = 0
	local swing_range = cfg.melee_swing_end - cfg.melee_swing_start

	if p.is_attacking and p.attack_timer then
		local elapsed = time() - p.attack_timer
		local swing_time = cfg.melee_swing_time
		local return_time = cfg.melee_return_time
		local total_time = swing_time + return_time

		if elapsed < swing_time then
			-- Forward swing phase
			local progress = elapsed / swing_time
			swing_rot = cfg.melee_swing_start + (swing_range * progress)
		elseif elapsed < total_time then
			-- Return phase - smoothly rotate back
			local return_progress = (elapsed - swing_time) / return_time
			swing_rot = cfg.melee_swing_end - (swing_range * return_progress)
		else
			-- Attack complete
			p.is_attacking = false
			swing_rot = 0
		end

		if not facing_east then swing_rot = -swing_rot end
	end

	-- Draw rotated weapon sprite with pivot offset
	rspr(weapon.sprite, screen_x + offset_x, screen_y + cfg.melee_offset_y, 1, 1, base_rot + swing_rot, flip_x, cfg.melee_pivot_x, cfg.melee_pivot_y)
end

-- ============================================
-- DEPTH-SORTED WEAPON RENDERING
-- ============================================

-- Get player ranged weapon as queue entry for depth sorting
-- Returns nil if no ranged weapon equipped
function get_player_ranged_weapon_entry(player)
	local weapon, wtype = get_equipped_weapon()
	if not weapon or wtype ~= "ranged" then return nil end
	if not weapon.weapon_sprite then return nil end

	local dir = player.facing_dir or "east"
	-- Player depth is player.y + 8
	-- Weapon draws in front (after player in sorted order) with tiny offset
	-- Except when facing north: weapon draws behind (before player)
	local depth_y = player.y + 8.01  -- tiny offset to sort after player
	if dir == "north" then
		-- Behind player when facing north
		depth_y = player.y + 7.99  -- tiny offset to sort before player
	end

	return {
		type = "player_ranged_weapon",
		y = depth_y,
		cx = player.x,
		cy = player.y,
		owner = player,
		weapon = weapon,
		facing_dir = dir
	}
end

-- Get player melee weapon as queue entry for depth sorting
-- Returns nil if no melee weapon equipped
function get_player_melee_weapon_entry(player)
	local weapon, wtype = get_equipped_weapon()
	if not weapon or wtype ~= "melee" then return nil end

	local dir = player.facing_dir or "east"
	-- Player depth is player.y + 8
	-- Weapon draws in front (after player in sorted order) with tiny offset
	-- Except when facing north: weapon draws behind (before player)
	local depth_y = player.y + 8.01  -- tiny offset to sort after player
	if dir == "north" then
		-- Behind player when facing north
		depth_y = player.y + 7.99  -- tiny offset to sort before player
	end

	return {
		type = "player_melee_weapon",
		y = depth_y,
		cx = player.x,
		cy = player.y,
		owner = player,
		weapon = weapon,
		facing_dir = dir
	}
end

-- Draw ranged weapon at specified screen position (for depth-sorted rendering)
function draw_ranged_weapon_at(sx, sy, owner, weapon, facing_dir)
	if not weapon or not weapon.weapon_sprite then return end

	local dir = facing_dir or "east"
	local cfg = WEAPON_CONFIG

	-- Calculate offset and rotation based on direction
	local offset_x, offset_y = 0, 0
	local rot = 0
	local flip_x = false

	if dir == "east" then
		offset_x = cfg.ranged_offset_x
		offset_y = cfg.ranged_offset_y
		rot = 0
	elseif dir == "west" then
		offset_x = -cfg.ranged_offset_x
		offset_y = cfg.ranged_offset_y
		rot = 0
		flip_x = true
	elseif dir == "north" then
		offset_x = cfg.ranged_offset_y
		offset_y = -cfg.ranged_offset_x
		rot = 0.75
	elseif dir == "south" then
		offset_x = cfg.ranged_offset_y
		offset_y = cfg.ranged_offset_x
		rot = 0.25
	end

	rspr(weapon.weapon_sprite, sx + offset_x, sy + offset_y, 1, 1, rot, flip_x, 0, 0)
end

-- Draw melee weapon at specified screen position (for depth-sorted rendering)
function draw_melee_weapon_at(sx, sy, owner, weapon, facing_dir)
	if not weapon then return end

	local dir = facing_dir or "east"
	local cfg = WEAPON_CONFIG

	-- Only E/W affect weapon position, N/S keep last horizontal
	local facing_east = (dir == "east")
	local offset_x = facing_east and cfg.melee_offset_x or -cfg.melee_offset_x
	local flip_x = facing_east

	-- Base rotation
	local base_rot = facing_east and cfg.melee_base_rot_east or cfg.melee_base_rot_west

	-- Calculate swing rotation when attacking or returning
	local swing_rot = 0
	local swing_range = cfg.melee_swing_end - cfg.melee_swing_start

	if owner.is_attacking and owner.attack_timer then
		local elapsed = time() - owner.attack_timer
		local swing_time = cfg.melee_swing_time
		local return_time = cfg.melee_return_time
		local total_time = swing_time + return_time

		if elapsed < swing_time then
			local progress = elapsed / swing_time
			swing_rot = cfg.melee_swing_start + (swing_range * progress)
		elseif elapsed < total_time then
			local return_progress = (elapsed - swing_time) / return_time
			swing_rot = cfg.melee_swing_end - (swing_range * return_progress)
		else
			owner.is_attacking = false
			swing_rot = 0
		end

		if not facing_east then swing_rot = -swing_rot end
	end

	rspr(weapon.sprite, sx + offset_x, sy + cfg.melee_offset_y, 1, 1, base_rot + swing_rot, flip_x, cfg.melee_pivot_x, cfg.melee_pivot_y)
end
