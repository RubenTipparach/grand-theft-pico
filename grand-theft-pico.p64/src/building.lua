--[[pod_format="raw"]]
-- building.lua - Building data and rendering (GTA1/2 top-down style)

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
	add(visible, {
		type = "player",
		y = player_feet_y,
		cx = player.x,
		cy = player.y,
		spr = player_spr,
		flip_x = flip_x
	})

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
				sy = sy
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
			local sr = PLAYER_CONFIG.shadow_radius
			local sh = PLAYER_CONFIG.shadow_height
			local sx_off = PLAYER_CONFIG.shadow_x_offset
			local sy_off = PLAYER_CONFIG.shadow_y_offset
			ovalfill(SCREEN_CX - sr + sx_off, SCREEN_CY + sy_off, SCREEN_CX + sr + sx_off, SCREEN_CY + sy_off + sh, PLAYER_CONFIG.shadow_color)
		elseif obj.type == "npc" then
			local sr = NPC_CONFIG.shadow_radius
			local sh = NPC_CONFIG.shadow_height
			local sx_off = NPC_CONFIG.shadow_x_offset
			local sy_off = NPC_CONFIG.shadow_y_offset
			ovalfill(obj.sx - sr + sx_off, obj.sy + sy_off, obj.sx + sr + sx_off, obj.sy + sy_off + sh, NPC_CONFIG.shadow_color)
		end
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
			spr(obj.spr, SCREEN_CX - 8, SCREEN_CY - 8, obj.flip_x)
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
		elseif obj.type == "lamp" then
			-- Draw lamp sprite with bottom-center anchored at light position
			local draw_x = obj.sx - lamp_w / 2
			local draw_y = obj.sy - lamp_h
			spr(lamp_cfg.lamp_sprite, draw_x, draw_y)
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
