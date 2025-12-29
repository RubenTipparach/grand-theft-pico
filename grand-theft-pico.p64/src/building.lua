--[[pod_format="raw"]]
-- building.lua - Building data and rendering (GTA1/2 top-down style)

-- Pending traffic signals to draw after night overlay (so they're not darkened)
pending_traffic_signals = {}

-- Draw east/west walls only (slant away from center, should be behind player)
function draw_building_back_walls(b)
	local x0, y0 = b.x, b.y
	local x1, y1 = b.x + b.w, b.y + b.h

	-- Get screen position of building center
	local cx, cy = world_to_screen(x0 + b.w / 2, y0 + b.h / 2)

	-- Calculate wall height based on distance from screen center, scaled by building height multiplier
	local wall_h = get_wall_height(cx, cy) * (b.wall_height or 1)

	-- Get perspective offset (walls lean outward from center)
	local ox, oy = get_wall_offset(cx, cy, wall_h)

	-- Get wall sprite from building data
	local wall_spr = b.wall_sprite

	-- Select wall drawing function based on render mode
	local draw_wall = render_mode == "tri" and draw_wall_quad or draw_wall_textured

	-- Get which walls are visible based on screen position (backface culling)
	local visible = get_visible_walls(cx, cy)

	-- Draw east/west walls (they slant away, so player draws on top of them)
	-- West wall (left edge) - only if building is right of screen center
	if visible.west then
		draw_wall(wall_spr, x0, y0, x0, y1, wall_h, ox, oy)
	end
	-- East wall (right edge) - only if building is left of screen center
	if visible.east then
		draw_wall(wall_spr, x1, y0, x1, y1, wall_h, ox, oy)
	end
end

-- Draw south wall and roof (should be in front of player)
function draw_building_front(b)
	local x0, y0 = b.x, b.y
	local x1, y1 = b.x + b.w, b.y + b.h

	-- Get screen position of building center
	local cx, cy = world_to_screen(x0 + b.w / 2, y0 + b.h / 2)

	-- Calculate wall height based on distance from screen center, scaled by building height multiplier
	local wall_h = get_wall_height(cx, cy) * (b.wall_height or 1)

	-- Get perspective offset (walls lean outward from center)
	local ox, oy = get_wall_offset(cx, cy, wall_h)

	-- Get wall sprite from building data
	local wall_spr = b.wall_sprite

	-- Select wall drawing function based on render mode
	local draw_wall = render_mode == "tri" and draw_wall_quad or draw_wall_textured

	-- South wall (bottom edge) - always visible, always in front
	draw_wall(wall_spr, x0, y1, x1, y1, wall_h, ox, oy)

	-- Draw ROOF
	local rx0, ry0 = world_to_screen(x0, y0)
	local rx1, ry1 = world_to_screen(x1, y1)

	local roof_spr = b.roof_sprite or SPRITES.ROOF.id

	-- Roof corners (offset by perspective, raised by wall height)
	local roof_x0 = rx0 + ox
	local roof_y0 = ry0 - wall_h + oy
	local roof_x1 = rx1 + ox
	local roof_y1 = ry1 - wall_h + oy

	-- Calculate actual roof dimensions in screen pixels
	local tex_size = 16
	local roof_w = abs(roof_x1 - roof_x0)
	local roof_h = abs(roof_y1 - roof_y0)

	-- UV coordinates based on actual roof size (no rounding for sub-pixel precision)
	local u1 = max(tex_size, roof_w)
	local v1 = max(tex_size, roof_h)

	if render_mode == "tri" then
		-- Draw roof using batched textri (2 triangles)
		-- Triangle 1: top-left, top-right, bottom-left
		textri(roof_spr,
			roof_x0, roof_y0, 0, 0,
			roof_x1, roof_y0, u1, 0,
			roof_x0, roof_y1, 0, v1)

		-- Triangle 2: top-right, bottom-right, bottom-left
		textri(roof_spr,
			roof_x1, roof_y0, u1, 0,
			roof_x1, roof_y1, u1, v1,
			roof_x0, roof_y1, 0, v1)
	else
		-- Draw roof using tline3d scanlines with fixed corner UVs
		-- Snap all coordinates to integers to avoid UV jitter when moving
		local x_start = flr(roof_x0)
		local x_end = ceil(roof_x1)
		local y_start = flr(roof_y0)
		local y_end = ceil(roof_y1)
		local y_span = y_end - y_start
		if y_span < 1 then y_span = 1 end

		for y = y_start, y_end do
			-- Calculate t based on integer pixel span
			local t = (y - y_start) / y_span

			-- Interpolate V from 0 to v1
			local tex_v = v1 * t

			tline3d(roof_spr, x_start, y, x_end, y,
					0, tex_v, u1, tex_v,
					1, 1)
		end
	end
end

-- Draw a single building with pseudo-3D walls (convenience wrapper)
function draw_building(b)
	draw_building_back_walls(b)
	draw_building_front(b)
end

-- Draw all visible buildings with culling and sorting
-- Also draws player sprite at correct depth
function draw_buildings_and_player(buildings, player, player_spr, flip_x)
	local visible = {}

	-- Phase 1: Frustum cull buildings
	profile("cull")
	for _, b in ipairs(buildings) do
		if is_building_visible(b) then
			-- For depth sorting, use the building's south edge (bottom in world Y)
			local building_depth_y = b.y + b.h
			-- Get building center for distance-from-player calculation
			local bcx = b.x + b.w / 2
			local bcy = b.y + b.h / 2
			add(visible, {
				type = "building",
				y = building_depth_y,
				cx = bcx,  -- building center X (world coords)
				cy = bcy,  -- building center Y (world coords)
				data = b
			})
		end
	end

	-- Add player to the list
	-- Use player's feet position for depth sorting
	-- Player sprite is 16x16, feet are roughly at center-bottom (+8 from top-left)
	local player_feet_y = player.y + 8
	local player_sx, player_sy = world_to_screen(player.x, player.y)
	add(visible, {
		type = "player",
		y = player_feet_y,
		cx = player.x,
		cy = player.y,
		sx = player_sx,  -- cache screen position for deadzone camera
		sy = player_sy,
		spr = player_spr,
		flip_x = flip_x
	})

	-- Add player weapons to visible queue for depth sorting (if not in vehicle)
	if not player_vehicle then
		local melee_entry = get_player_melee_weapon_entry(player)
		if melee_entry then
			melee_entry.sx = player_sx
			melee_entry.sy = player_sy
			add(visible, melee_entry)
		end

		local ranged_entry = get_player_ranged_weapon_entry(player)
		if ranged_entry then
			ranged_entry.sx = player_sx
			ranged_entry.sy = player_sy
			add(visible, ranged_entry)
		end
	end

profile("cull")

	-- Add visible NPCs to the list (frustum cull)
	for _, npc in ipairs(npcs) do
		local sx, sy = world_to_screen(npc.x, npc.y)
		-- Only add if on screen (with margin for sprite size)
		if sx > -16 and sx < SCREEN_W + 16 and sy > -16 and sy < SCREEN_H + 16 then
			local npc_feet_y = npc.y + 8
			add(visible, {
				type = "npc",
				y = npc_feet_y,
				cx = npc.x,
				cy = npc.y,
				sx = sx,  -- cache screen position
				sy = sy,
				data = npc
			})
		end
	end

	-- Add visible vehicles to the list (frustum cull)
	for _, vehicle in ipairs(vehicles) do
		local sx, sy = world_to_screen(vehicle.x, vehicle.y)
		local vw, vh = get_vehicle_dimensions(vehicle)
		local margin = max(vw, vh)
		-- Only add if on screen
		if sx > -margin and sx < SCREEN_W + margin and sy > -margin and sy < SCREEN_H + margin then
			local vehicle_depth_y = vehicle.y + vh / 2
			add(visible, {
				type = "vehicle",
				y = vehicle_depth_y,
				cx = vehicle.x,
				cy = vehicle.y,
				sx = sx,
				sy = sy,
				data = vehicle
			})
		end
	end

	-- Add visible arms dealers to the list (frustum cull)
	if arms_dealers then
		add_dealers_to_visible(visible)
	end

	-- Add visible foxes to the list (frustum cull)
	if foxes_spawned then
		add_foxes_to_visible(visible)
	end

	-- Add cactus boss to the list (if spawned)
	add_cactus_to_visible(visible)

	-- Add package to the list (beyond the sea quest)
	add_package_to_visible(visible)

	-- Add visible street lamps to the list (frustum cull)
	local lamp_cfg = NIGHT_CONFIG
	local lamp_w = lamp_cfg.lamp_width
	local lamp_h = lamp_cfg.lamp_height
	local lamp_margin = max(lamp_w, lamp_h)
	for _, light in ipairs(STREET_LIGHTS) do
		local sx, sy = world_to_screen(light.x, light.y)
		-- Only add if on screen (with margin for sprite size)
		if sx > -lamp_margin and sx < SCREEN_W + lamp_margin and sy > -lamp_margin and sy < SCREEN_H + lamp_margin then
			-- Depth sort by the lamp's base position (light source = bottom of sprite)
			add(visible, {
				type = "lamp",
				y = light.y,  -- base of lamp for depth sorting
				cx = light.x,
				cy = light.y,
				sx = sx,
				sy = sy,
				is_traffic_light = light.is_traffic_light,
				corner = light.corner,  -- which corner of intersection (for sprite facing)
				flip_x = light.flip_x,
				flip_y = light.flip_y,
			})
		end
	end

	-- Phase 2: Sort for painter's algorithm
	-- Primary: Y position (lower Y = further back = draw first)
	-- Secondary: X distance from player - buildings further from player in X draw first
	--   West of player: lower X draws first (further west = draw first)
	--   East of player: higher X draws first (further east = draw first)
	-- This creates: 1,2,3,P,3,2,1 priority (higher = draw later = on top)
	profile("sort")
	local px, py = player.x, player.y
	sort_list(visible, function(a, b)
		-- Primary sort by Y (buildings higher on screen draw first)
		if a.y ~= b.y then
			return a.y < b.y
		end
		-- Secondary: sort by X distance from player (further = draw first)
		local dist_a = abs(a.cx - px)
		local dist_b = abs(b.cx - px)
		return dist_a > dist_b  -- further from player in X draws first
	end)
	profile("sort")

	-- Phase 3: Draw all shadows first with one color table enable (batched)
	profile("shadows")
	local coltab_sprite = get_spr(shadow_coltab_mode)
	memmap(0x8000, coltab_sprite)
	poke(0x550b, 0x3f)  -- enable color table

	for _, obj in ipairs(visible) do
		if obj.type == "player" then
			-- Don't draw player shadow if in vehicle
			if not player_vehicle then
				local sr = PLAYER_CONFIG.shadow_radius
				local sh = PLAYER_CONFIG.shadow_height
				local sx_off = PLAYER_CONFIG.shadow_x_offset
				local sy_off = PLAYER_CONFIG.shadow_y_offset
				ovalfill(obj.sx - sr + sx_off, obj.sy + sy_off, obj.sx + sr + sx_off, obj.sy + sy_off + sh, PLAYER_CONFIG.shadow_color)
			end
		elseif obj.type == "npc" then
			local sr = NPC_CONFIG.shadow_radius
			local sh = NPC_CONFIG.shadow_height
			local sx_off = NPC_CONFIG.shadow_x_offset
			local sy_off = NPC_CONFIG.shadow_y_offset
			ovalfill(obj.sx - sr + sx_off, obj.sy + sy_off, obj.sx + sr + sx_off, obj.sy + sy_off + sh, NPC_CONFIG.shadow_color)
		elseif obj.type == "dealer" then
			-- Dealer shadow (similar to player but slightly smaller for scaled sprite)
			local sr = 6
			local sh = 3
			local sy_off = 2
			ovalfill(obj.sx - sr, obj.sy + sy_off, obj.sx + sr, obj.sy + sy_off + sh, PLAYER_CONFIG.shadow_color)
		elseif obj.type == "fox" then
			-- Fox shadow (small since fox sprites are scaled down)
			local sr = 4
			local sh = 2
			local sy_off = 2
			ovalfill(obj.sx - sr, obj.sy + sy_off, obj.sx + sr, obj.sy + sy_off + sh, PLAYER_CONFIG.shadow_color)
		elseif obj.type == "cactus" then
			-- Cactus shadow (larger for boss)
			local sr = 6
			local sh = 3
			local sy_off = 2
			ovalfill(obj.sx - sr, obj.sy + sy_off, obj.sx + sr, obj.sy + sy_off + sh, PLAYER_CONFIG.shadow_color)
		elseif obj.type == "package" then
			-- Package shadow (32x32 sprite, oval slightly wider than box)
			local sr = 17  -- shadow half-width (32/2 + 1 = 17)
			local sh = 4   -- shadow height
			local sy_off = 8  -- offset from center to bottom of sprite
			ovalfill(obj.sx - sr, obj.sy + sy_off, obj.sx + sr, obj.sy + sy_off + sh, PLAYER_CONFIG.shadow_color)
		end
		-- No shadow for vehicles (doesn't look great)
	end

	unmap(coltab_sprite)
	poke(0x550b, 0x00)  -- disable color table
	profile("shadows")

	-- Phase 4: Draw in 2 passes for correct depth ordering
	-- Pass 1: ALL east/west walls (they slant away, all sprites draw on top)
	-- Pass 2: Sprites + south walls/roofs in Y-sorted order (painter's algorithm)
	profile("sprites")

	-- Pass 1: Draw all back walls first (east/west walls slant away from viewer)
	for _, obj in ipairs(visible) do
		if obj.type == "building" then
			draw_building_back_walls(obj.data)
		end
	end

	-- Pass 2: Draw sprites and building fronts in Y-sorted order
	-- This respects depth - sprites with feet below south wall draw on top
	for _, obj in ipairs(visible) do
		if obj.type == "building" then
			draw_building_front(obj.data)
		elseif obj.type == "player" then
			-- Don't draw player sprite if in vehicle
			if not player_vehicle then
				spr(obj.spr, obj.sx - 8, obj.sy - 8, obj.flip_x)
			end
		elseif obj.type == "vehicle" then
			local vehicle = obj.data
			local vw, vh = get_vehicle_dimensions(vehicle)
			local vehicle_spr = get_vehicle_sprite(vehicle)
			local flip_x, flip_y = get_vehicle_flip(vehicle)
			local draw_x = obj.sx - vw / 2
			local draw_y = obj.sy - vh / 2

			-- Offset N/S facing vehicles so Y center aligns with E/W bottom
			if vehicle.facing_dir == "north" or vehicle.facing_dir == "south" then
				draw_y = draw_y + (vehicle.vtype.ns_y_offset or 0)
			end

			-- Draw vehicle sprite
			spr(vehicle_spr, draw_x, draw_y, flip_x, flip_y)

			-- Draw fire effect if damaged
			if vehicle.state ~= "destroyed" and vehicle.state ~= "exploding" then
				if vehicle.health <= VEHICLE_CONFIG.fire_threshold and vehicle.health > 0 then
					local fire_spr = VEHICLE_CONFIG.fire_sprites[vehicle.fire_frame]
					-- Draw fire on top of vehicle
					spr(fire_spr, draw_x + vw/2 - 4, draw_y - 8)
				end
			end

			-- Draw explosion effect
			if vehicle.state == "exploding" then
				local exp_spr = VEHICLE_CONFIG.explosion_sprites[vehicle.explosion_frame]
				if exp_spr then
					spr(exp_spr, draw_x + vw/2 - 8, draw_y - 8)
				end
			end
		elseif obj.type == "npc" then
			local npc = obj.data
			local npc_spr = get_npc_sprite(npc)
			local npc_w = get_npc_width(npc)
			local npc_h = get_npc_height(npc)
			local draw_x = obj.sx - npc_w / 2
			local draw_y = obj.sy - npc_h / 2
			spr(npc_spr, draw_x, draw_y)
			-- Draw exclamation sprite above head if surprised
			if npc_shows_surprise(npc) then
				-- Sprite 135 is 8x8, center it above head
				spr(NPC_CONFIG.surprise_sprite, draw_x, draw_y - 10)
			end
			-- Draw heart sprite above fans/lovers (bobbing animation, only when timer active)
			local fan_data = get_fan_data(npc)
			if fan_data and fan_data.heart_show_until and time() < fan_data.heart_show_until then
				-- Heart bobs up and down
				local bob = sin(time() * PLAYER_CONFIG.heart_bob_speed) * PLAYER_CONFIG.heart_bob_height
				spr(PLAYER_CONFIG.heart_sprite, draw_x, draw_y - 12 + bob)
			end
		elseif obj.type == "dealer" then
			-- Draw arms dealer
			draw_dealer(obj.data, obj.sx, obj.sy)
		elseif obj.type == "fox" then
			-- Draw fox
			draw_fox(obj.data, obj.sx, obj.sy)
		elseif obj.type == "cactus" then
			-- Draw cactus boss
			draw_cactus(obj.data, obj.sx, obj.sy)
		elseif obj.type == "package" then
			-- Draw package sprite
			draw_package_sprite(obj.sx, obj.sy)
		elseif obj.type == "player_melee_weapon" then
			-- Draw player melee weapon (depth sorted)
			draw_melee_weapon_at(obj.sx, obj.sy, obj.owner, obj.weapon, obj.facing_dir)
		elseif obj.type == "player_ranged_weapon" then
			-- Draw player ranged weapon (depth sorted)
			draw_ranged_weapon_at(obj.sx, obj.sy, obj.owner, obj.weapon, obj.facing_dir)
		elseif obj.type == "lamp" then
			-- Draw lamp sprite with bottom-center anchored at light position
			local draw_x = obj.sx - lamp_w / 2
			local draw_y = obj.sy - lamp_h
			spr(lamp_cfg.lamp_sprite, draw_x, draw_y)

			-- If this is a traffic light, store BOTH signals for later drawing (after night overlay)
			-- Each lamp has 2 signals: one N-S and one E-W
			-- Corner-specific positioning and flipping:
			--   NW: Left=N-S (flip_y), Right=E-W
			--   NE: Left=E-W, Right=N-S (swap positions from default)
			--   SW: Left=N-S, Right=E-W
			--   SE: Left=E-W, Right=N-S (swap positions from default)
			if obj.is_traffic_light then
				local base_x = draw_x + TRAFFIC_CONFIG.signal_base_x - 4  -- center 8px signal
				local base_y = draw_y + (lamp_h - TRAFFIC_CONFIG.signal_base_y) - 4  -- from bottom

				local off1_x = TRAFFIC_CONFIG.signal_1_offset_x
				local off1_y = TRAFFIC_CONFIG.signal_1_offset_y
				local off2_x = TRAFFIC_CONFIG.signal_2_offset_x
				local off2_y = TRAFFIC_CONFIG.signal_2_offset_y

				-- Corner-specific signal arrangement
				-- E-W signals flipped horizontally on east side, N-S signals flipped vertically
				if obj.corner == "ne" then
					-- NE: Left=N-S (no flip_y), Right=E-W (flip_x)
					add(pending_traffic_signals, {
						ns_light = true, corner = obj.corner,
						x = base_x + off1_x, y = base_y + off1_y,
						flip_x = false, flip_y = false,  -- N-S no flip (was flip_y)
					})
					add(pending_traffic_signals, {
						ns_light = false, corner = obj.corner,
						x = base_x + off2_x, y = base_y + off2_y,
						flip_x = true, flip_y = false,   -- E-W flipped horizontally
					})
				elseif obj.corner == "se" then
					-- SE: Left=N-S (flip_y), Right=E-W (flip_x)
					add(pending_traffic_signals, {
						ns_light = true, corner = obj.corner,
						x = base_x + off1_x, y = base_y + off1_y,
						flip_x = false, flip_y = true,   -- N-S flipped vertically (was no flip)
					})
					add(pending_traffic_signals, {
						ns_light = false, corner = obj.corner,
						x = base_x + off2_x, y = base_y + off2_y,
						flip_x = true, flip_y = false,   -- E-W flipped horizontally
					})
				elseif obj.corner == "nw" then
					-- NW: Left=E-W (no flip_x), Right=N-S (no flip_y)
					add(pending_traffic_signals, {
						ns_light = false, corner = obj.corner,
						x = base_x + off1_x, y = base_y + off1_y,
						flip_x = false, flip_y = false,  -- E-W no flip (faces west side)
					})
					add(pending_traffic_signals, {
						ns_light = true, corner = obj.corner,
						x = base_x + off2_x, y = base_y + off2_y,
						flip_x = false, flip_y = false,  -- N-S no flip (was flip_y)
					})
				elseif obj.corner == "sw" then
					-- SW: Left=E-W (no flip_x), Right=N-S (flip_y)
					add(pending_traffic_signals, {
						ns_light = false, corner = obj.corner,
						x = base_x + off1_x, y = base_y + off1_y,
						flip_x = false, flip_y = false,  -- E-W no flip (faces west side)
					})
					add(pending_traffic_signals, {
						ns_light = true, corner = obj.corner,
						x = base_x + off2_x, y = base_y + off2_y,
						flip_x = false, flip_y = true,   -- N-S flipped vertically (was no flip)
					})
				end
			end
		end
	end
	profile("sprites")
end

-- Legacy function for compatibility
function draw_buildings(buildings)
	local visible = {}

	for _, b in ipairs(buildings) do
		if is_building_visible(b) then
			add(visible, b)
		end
	end

	sort_by_y(visible)

	for _, b in ipairs(visible) do
		draw_building(b)
	end
end

-- Draw pending traffic signals (called after night overlay to avoid darkening)
function draw_traffic_signals()
	for _, sig in ipairs(pending_traffic_signals) do
		local signal_spr = get_signal_sprite(sig.ns_light, sig.corner)
		spr(signal_spr, sig.x, sig.y, sig.flip_x, sig.flip_y)
	end
	-- Clear for next frame
	pending_traffic_signals = {}
end
