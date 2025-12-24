--[[pod_format="raw"]]
-- building.lua - Building data and rendering (GTA1/2 top-down style)

-- Draw a single building with pseudo-3D walls
function draw_building(b)
	local x0, y0 = b.x, b.y
	local x1, y1 = b.x + b.w, b.y + b.h

	-- Get screen position of building center
	local cx, cy = world_to_screen(x0 + b.w / 2, y0 + b.h / 2)

	-- Calculate wall height based on distance from screen center
	local wall_h = get_wall_height(cx, cy)

	-- Get perspective offset (walls lean outward from center)
	local ox, oy = get_wall_offset(cx, cy, wall_h)

	-- Get wall sprite from building data
	local wall_spr = b.wall_sprite

	-- Determine which walls are visible (face culling optimization)
	local walls = get_visible_walls(cx, cy)

	-- Select wall drawing function based on render mode
	-- "tri" uses batched textri, "tline3d" uses per-scanline tline3d
	local draw_wall = render_mode == "tri" and draw_wall_quad or draw_wall_textured

	-- Draw walls in back-to-front order (painter's algorithm)
	-- Back walls first (west), then front walls (east and south)
	-- North wall commented out - always covered by roof in this perspective

	-- North wall (top edge) - skip, always hidden by roof
	-- draw_wall(wall_spr, x0, y0, x1, y0, wall_h, ox, oy)

	-- West wall (left edge)
	draw_wall(wall_spr, x0, y0, x0, y1, wall_h, ox, oy)

	-- East wall (right edge)
	draw_wall(wall_spr, x1, y0, x1, y1, wall_h, ox, oy)

	-- South wall (bottom edge) - draw last as it's closest to camera
	draw_wall(wall_spr, x0, y1, x1, y1, wall_h, ox, oy)

	-- Draw ROOF
	local rx0, ry0 = world_to_screen(x0, y0)
	local rx1, ry1 = world_to_screen(x1, y1)

	local roof_spr = SPRITES.ROOF.id

	-- Roof corners (top of building, offset by perspective)
	local roof_x0 = rx0 + ox
	local roof_y0 = ry0 - wall_h + oy
	local roof_x1 = rx1 + ox
	local roof_y1 = ry1 - wall_h + oy

	-- Calculate actual roof dimensions in screen pixels
	local tex_size = 16
	local roof_w = abs(roof_x1 - roof_x0)
	local roof_h = abs(roof_y1 - roof_y0)

	-- How many times to tile texture across roof (ceil to whole tiles)
	local tiles_across = max(1, ceil(roof_w / tex_size))
	local tiles_down = max(1, ceil(roof_h / tex_size))

	-- UV coordinates are whole tile counts * tex_size
	local u1 = tiles_across * tex_size
	local v1 = tiles_down * tex_size

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
					1, 1, 0x200)
		end
	end
end

-- Draw all visible buildings with culling and sorting
-- Also draws player sprite at correct depth
function draw_buildings_and_player(buildings, player, player_spr, flip_x)
	local visible = {}

	-- Phase 1: Frustum cull buildings
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

	-- Add NPCs to the list
	for _, npc in ipairs(npcs) do
		local npc_feet_y = npc.y + 8  -- feet at bottom of 16px tall sprite
		add(visible, {
			type = "npc",
			y = npc_feet_y,
			cx = npc.x,
			cy = npc.y,
			data = npc
		})
	end

	-- Phase 2: Sort for painter's algorithm
	-- Primary: Y position (lower Y = further back = draw first)
	-- Secondary: X distance from player - buildings further from player in X draw first
	--   West of player: lower X draws first (further west = draw first)
	--   East of player: higher X draws first (further east = draw first)
	-- This creates: 1,2,3,P,3,2,1 priority (higher = draw later = on top)
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

	-- Phase 3: Draw each object in sorted order
	for _, obj in ipairs(visible) do
		if obj.type == "building" then
			draw_building(obj.data)
		elseif obj.type == "player" then
			-- Draw player shadow
			local sr = PLAYER_CONFIG.shadow_radius
			local sh = PLAYER_CONFIG.shadow_height
			local sx_off = PLAYER_CONFIG.shadow_x_offset
			local sy_off = PLAYER_CONFIG.shadow_y_offset
			-- Apply color table for shadow blending (use shadow_coltab_mode sprite)
			draw_with_colortable(shadow_coltab_mode, function()
				ovalfill(SCREEN_CX - sr + sx_off, SCREEN_CY + sy_off, SCREEN_CX + sr + sx_off, SCREEN_CY + sy_off + sh, PLAYER_CONFIG.shadow_color)
			end)
			-- Draw player at screen center
			spr(obj.spr, SCREEN_CX - 8, SCREEN_CY - 8, obj.flip_x)
		elseif obj.type == "npc" then
			local npc = obj.data
			-- Convert NPC world position to screen position
			local sx, sy = world_to_screen(npc.x, npc.y)
			-- Draw NPC shadow
			local sr = NPC_CONFIG.shadow_radius
			local sh = NPC_CONFIG.shadow_height
			local sx_off = NPC_CONFIG.shadow_x_offset
			local sy_off = NPC_CONFIG.shadow_y_offset
			draw_with_colortable(shadow_coltab_mode, function()
				ovalfill(sx - sr + sx_off, sy + sy_off, sx + sr + sx_off, sy + sy_off + sh, NPC_CONFIG.shadow_color)
			end)
			-- Draw NPC sprite (centered on position)
			local npc_spr = get_npc_sprite(npc)
			local npc_w = get_npc_width(npc)
			local npc_h = get_npc_height(npc)
			spr(npc_spr, sx - npc_w / 2, sy - npc_h / 2)
		end
	end
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
