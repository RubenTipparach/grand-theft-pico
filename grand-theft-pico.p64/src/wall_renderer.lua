--[[pod_format="raw"]]
-- wall_renderer.lua - Wall rendering using tline3d
-- Two modes: "tline3d" = scanline loop, "tri" = batched userdata vectors

-- Scanline buffer for batched triangle rendering (11 values per scanline)
-- Format per row: spr, x0, y, x1, y, u0, v0, u1, v1, w0, w1
local scanlines = userdata("f64", 11, 270)

-- Draw textured triangle using BATCHED tline3d with userdata vector ops
-- Uses vec() and userdata:copy/:add for true batching (no per-scanline loops)
-- Vertices: (x1,y1,u1,v1), (x2,y2,u2,v2), (x3,y3,u3,v3)
function draw_textured_tri(spr, x1, y1, u1, v1, x2, y2, u2, v2, x3, y3, u3, v3)
	-- Sort vertices by Y (bubble sort for 3 elements)
	if y1 > y2 then
		x1, y1, u1, v1, x2, y2, u2, v2 = x2, y2, u2, v2, x1, y1, u1, v1
	end
	if y2 > y3 then
		x2, y2, u2, v2, x3, y3, u3, v3 = x3, y3, u3, v3, x2, y2, u2, v2
	end
	if y1 > y2 then
		x1, y1, u1, v1, x2, y2, u2, v2 = x2, y2, u2, v2, x1, y1, u1, v1
	end

	-- Clamp Y to screen bounds
	local start_y = y1 < 0 and 0 or flr(y1)
	local mid_y = y2 < 0 and 0 or y2 > SCREEN_H - 1 and SCREEN_H - 1 or flr(y2)
	local stop_y = y3 <= SCREEN_H - 1 and flr(y3) or SCREEN_H - 1

	local dy13 = y3 - y1
	if dy13 < 1 then return end

	-- Create vertex vectors for interpolation
	-- v1 = start values at y1: (spr, x_left, y, x_right, y, u_left, v_left, u_right, v_right, w0, w1)
	-- For a simple 2D case, we interpolate x and uv along both edges

	-- Top half of triangle (y1 to y2)
	local dy12 = y2 - y1
	if dy12 > 0 then
		local dy = mid_y - start_y
		if dy > 0 then
			-- Calculate interpolation factor for mid-point on long edge
			local t_mid = (y2 - y1) / dy13
			local x_mid = x1 + (x3 - x1) * t_mid
			local u_mid = u1 + (u3 - u1) * t_mid
			local v_mid = v1 + (v3 - v1) * t_mid

			-- Determine left/right edges (short edge v1->v2, long edge v1->v3)
			local lx1, lu1, lv1, rx1, ru1, rv1 = x1, u1, v1, x1, u1, v1
			local lx2, lu2, lv2, rx2, ru2, rv2
			if x2 < x_mid then
				-- Short edge is on left
				lx2, lu2, lv2 = x2, u2, v2
				rx2, ru2, rv2 = x_mid, u_mid, v_mid
			else
				-- Short edge is on right
				lx2, lu2, lv2 = x_mid, u_mid, v_mid
				rx2, ru2, rv2 = x2, u2, v2
			end

			-- Create start and end vectors for top half
			local v_start = vec(spr, lx1, start_y, rx1, start_y, lu1, lv1, ru1, rv1, 1, 1)
			local v_end = vec(spr, lx2, mid_y, rx2, mid_y, lu2, lv2, ru2, rv2, 1, 1)

			-- Calculate slope per scanline
			local slope = (v_end - v_start) / dy12

			-- Batch fill scanlines using userdata ops
			-- Row 0 = start value, then copy slope and accumulate
			scanlines:copy(slope * (start_y + 1 - y1) + v_start, true, 0, 0, 11)
			if dy > 1 then
				scanlines:copy(slope, true, 0, 11, 11, 0, 11, dy - 1)
				scanlines:add(scanlines, true, 0, 11, 11, 11, 11, dy - 1)
			end

			tline3d(scanlines, 0, dy)
		end
	end

	-- Bottom half of triangle (y2 to y3)
	local dy23 = y3 - y2
	if dy23 > 0 then
		local dy = stop_y - mid_y
		if dy > 0 then
			-- Calculate interpolation factor for mid-point on long edge at y2
			local t_mid = (y2 - y1) / dy13
			local x_mid = x1 + (x3 - x1) * t_mid
			local u_mid = u1 + (u3 - u1) * t_mid
			local v_mid = v1 + (v3 - v1) * t_mid

			-- Determine left/right edges (short edge v2->v3, long edge continues v1->v3)
			local lx1, lu1, lv1, rx1, ru1, rv1
			local lx2, lu2, lv2, rx2, ru2, rv2 = x3, u3, v3, x3, u3, v3
			if x2 < x_mid then
				-- Short edge is on left
				lx1, lu1, lv1 = x2, u2, v2
				rx1, ru1, rv1 = x_mid, u_mid, v_mid
			else
				-- Short edge is on right
				lx1, lu1, lv1 = x_mid, u_mid, v_mid
				rx1, ru1, rv1 = x2, u2, v2
			end

			-- Create start and end vectors for bottom half
			local v_start = vec(spr, lx1, mid_y, rx1, mid_y, lu1, lv1, ru1, rv1, 1, 1)
			local v_end = vec(spr, lx2, stop_y, rx2, stop_y, lu2, lv2, ru2, rv2, 1, 1)

			-- Calculate slope per scanline
			local slope = (v_end - v_start) / dy23

			-- Batch fill scanlines using userdata ops
			scanlines:copy(slope * (mid_y + 1 - y2) + v_start, true, 0, 0, 11)
			if dy > 1 then
				scanlines:copy(slope, true, 0, 11, 11, 0, 11, dy - 1)
				scanlines:add(scanlines, true, 0, 11, 11, 11, 11, dy - 1)
			end

			tline3d(scanlines, 0, dy)
		end
	end
end

-- Draw a single wall face using batched triangle rasterization
-- wx0,wy0 to wx1,wy1 are world coordinates of the wall base
-- ox, oy = perspective offset for roof (passed from building center)
function draw_wall_tri(sprite_idx, wx0, wy0, wx1, wy1, wall_height, ox, oy)
	if wall_height < 1 then return end

	-- Convert to screen coordinates
	local sx0, sy0 = world_to_screen(wx0, wy0)
	local sx1, sy1 = world_to_screen(wx1, wy1)

	-- Wall base coordinates (bottom of wall, on ground)
	local bx0, by0 = sx0, sy0
	local bx1, by1 = sx1, sy1

	-- Wall top coordinates (shifted up by wall_height and offset by perspective)
	local tx0, ty0 = sx0 + ox, sy0 - wall_height + oy
	local tx1, ty1 = sx1 + ox, sy1 - wall_height + oy

	-- Calculate wall width in screen pixels for texture tiling
	local wall_screen_width = sqrt((sx1 - sx0) * (sx1 - sx0) + (sy1 - sy0) * (sy1 - sy0))

	-- Texture size (16x16 sprite)
	local tex_size = 16

	-- How many times to tile the texture across width and height
	local tiles_across = max(1, wall_screen_width / tex_size)
	local tiles_down = max(1, wall_height / tex_size)

	-- UV coordinates for tiled texture
	local u0, v0 = 0, 0
	local u1, v1 = tiles_across * tex_size, tiles_down * tex_size

	-- Draw wall as two textured triangles (quad split into 2 tris)
	-- Triangle 1: top-left, bottom-left, top-right
	draw_textured_tri(sprite_idx,
		tx0, ty0, u0, v0,    -- top-left
		bx0, by0, u0, v1,    -- bottom-left
		tx1, ty1, u1, v0)    -- top-right

	-- Triangle 2: top-right, bottom-left, bottom-right
	draw_textured_tri(sprite_idx,
		tx1, ty1, u1, v0,    -- top-right
		bx0, by0, u0, v1,    -- bottom-left
		bx1, by1, u1, v1)    -- bottom-right
end

-- Draw a single wall face using tline3d scanlines
-- wx0,wy0 to wx1,wy1 are world coordinates of the wall base
-- ox, oy = perspective offset for roof (passed from building center)
function draw_wall_textured(sprite_idx, wx0, wy0, wx1, wy1, wall_height, ox, oy)
	if wall_height < 1 then return end

	-- Convert to screen coordinates
	local sx0, sy0 = world_to_screen(wx0, wy0)
	local sx1, sy1 = world_to_screen(wx1, wy1)

	-- Define the 4 corners of the wall quad (same as draw_wall_tri)
	-- Bottom = on ground, Top = raised by wall_height with perspective offset
	local bx0, by0 = sx0, sy0                           -- bottom-left
	local bx1, by1 = sx1, sy1                           -- bottom-right
	local tx0, ty0 = sx0 + ox, sy0 - wall_height + oy   -- top-left
	local tx1, ty1 = sx1 + ox, sy1 - wall_height + oy   -- top-right

	-- Calculate wall dimensions for texture tiling (matching draw_wall_tri)
	local tex_size = 16
	-- Wall width is the distance along the BASE of the wall (bx0,by0 to bx1,by1)
	local wall_screen_width = sqrt((bx1 - bx0) * (bx1 - bx0) + (by1 - by0) * (by1 - by0))
	local tiles_across = max(1, wall_screen_width / tex_size)
	local tiles_down = max(1, wall_height / tex_size)

	-- Fixed UV at each corner (matching draw_wall_tri exactly)
	-- Top-left:     (0, 0)
	-- Top-right:    (u1, 0)
	-- Bottom-left:  (0, v1)
	-- Bottom-right: (u1, v1)
	local u1 = tiles_across * tex_size
	local v1 = tiles_down * tex_size

	-- Determine if this is a "horizontal" wall (S/N) or "vertical" wall (E/W)
	-- Horizontal walls: base points differ in X, scanlines go top-to-bottom
	-- Vertical walls: base points differ in Y, scanlines go along the wall width
	local dx = abs(bx1 - bx0)
	local dy = abs(by1 - by0)

	if dx >= dy then
		-- Horizontal wall (South/North): iterate vertically (top to bottom)
		local vertical_span = max(abs(by0 - ty0), abs(by1 - ty1))
		local num_scanlines = ceil(vertical_span)
		if num_scanlines < 1 then num_scanlines = 1 end

		for i = 0, num_scanlines do
			local t = i / num_scanlines

			-- Interpolate position along left edge (top-left to bottom-left)
			local lx = tx0 + (bx0 - tx0) * t
			local ly = ty0 + (by0 - ty0) * t

			-- Interpolate position along right edge (top-right to bottom-right)
			local rx = tx1 + (bx1 - tx1) * t
			local ry = ty1 + (by1 - ty1) * t

			-- Interpolate UV: left edge (0,0)->(0,v1), right edge (u1,0)->(u1,v1)
			local lv = v1 * t
			local rv = v1 * t

			tline3d(sprite_idx, lx, ly, rx, ry,
					0, lv, u1, rv,
					1, 1, 0x200)
		end
	else
		-- Vertical wall (East/West): iterate horizontally (along wall width)
		local num_scanlines = ceil(wall_screen_width)
		if num_scanlines < 1 then num_scanlines = 1 end

		for i = 0, num_scanlines do
			local t = i / num_scanlines

			-- Interpolate position along top edge (top-left to top-right)
			local top_x = tx0 + (tx1 - tx0) * t
			local top_y = ty0 + (ty1 - ty0) * t

			-- Interpolate position along bottom edge (bottom-left to bottom-right)
			local bot_x = bx0 + (bx1 - bx0) * t
			local bot_y = by0 + (by1 - by0) * t

			-- Interpolate UV: top edge (0,0)->(u1,0), bottom edge (0,v1)->(u1,v1)
			local u = u1 * t

			tline3d(sprite_idx, top_x, top_y, bot_x, bot_y,
					u, 0, u, v1,
					1, 1, 0x200)
		end
	end
end

-- Draw a wall using solid color (fallback if no sprite)
function draw_wall_solid(color, wx0, wy0, wx1, wy1, wall_height)
	if wall_height < 1 then return end

	local sx0, sy0 = world_to_screen(wx0, wy0)
	local sx1, sy1 = world_to_screen(wx1, wy1)

	local ox0, oy0 = get_wall_offset(sx0, sy0, wall_height)
	local ox1, _ = get_wall_offset(sx1, sy1, wall_height)

	local tx0, ty0 = sx0 + ox0, sy0 - wall_height + oy0
	local tx1 = sx1 + ox1

	-- Draw as filled trapezoid using lines
	local h = flr(wall_height)
	for i = 0, h - 1 do
		local t = i / h
		local lx = tx0 + (sx0 - tx0) * t
		local rx = tx1 + (sx1 - tx1) * t
		local y = ty0 + (sy0 - ty0) * t

		-- Darken color toward bottom (simple shading)
		local shade = color
		if t > 0.5 then shade = max(1, color - 1) end

		line(lx, y, rx, y, shade)
	end
end
