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
	local draw_wall = render_mode == "tri" and draw_wall_tri or draw_wall_textured

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
		-- Draw roof using batched textured triangles (2 triangles)
		-- Triangle 1: top-left, top-right, bottom-left
		draw_textured_tri(roof_spr,
			roof_x0, roof_y0, 0, 0,
			roof_x1, roof_y0, u1, 0,
			roof_x0, roof_y1, 0, v1)

		-- Triangle 2: top-right, bottom-right, bottom-left
		draw_textured_tri(roof_spr,
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
			-- This is where the building "meets the ground" from camera's perspective
			local building_depth_y = b.y + b.h
			add(visible, {
				type = "building",
				y = building_depth_y,
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
		y = player_feet_y,  -- player's feet Y position for depth
		spr = player_spr,
		flip_x = flip_x
	})

	-- Phase 2: Sort by Y position (top to bottom for painter's algo)
	-- Lower Y = further back = draw first
	sort_list(visible, function(a, b)
		return a.y < b.y
	end)

	-- Phase 3: Draw each object in sorted order
	for _, obj in ipairs(visible) do
		if obj.type == "building" then
			draw_building(obj.data)
		elseif obj.type == "player" then
			-- Draw player at screen center
			spr(obj.spr, SCREEN_CX - 8, SCREEN_CY - 8, obj.flip_x)
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
