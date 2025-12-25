--[[pod_format="raw"]]
-- wall_renderer.lua - Wall rendering using tline3d
-- Two modes: "tline3d" = per-scanline loop, "tri" = batched userdata vectors

-- Scanline buffer for batched triangle rendering (11 values per scanline)
-- Format per row: spr, x0, y, x1, y, u0, v0, u1, v1, w0, w1
local scanlines = userdata("f64", 11, 270)

-- Draw a single wall face using BATCHED tline3d scanlines
-- Uses vec() and userdata:copy/:add for true batching (no per-scanline loops)
-- wx0,wy0 to wx1,wy1 are world coordinates of the wall base
-- ox, oy = perspective offset for roof (passed from building center)
-- wall_height can be negative for 3-point perspective (walls go down instead of up)
function draw_wall_textured(sprite_idx, wx0, wy0, wx1, wy1, wall_height, ox, oy)
	local abs_wall_height = abs(wall_height)
	if abs_wall_height < 1 then return end

	-- Convert to screen coordinates
	local sx0, sy0 = world_to_screen(wx0, wy0)
	local sx1, sy1 = world_to_screen(wx1, wy1)

	-- Define the 4 corners of the wall quad
	-- Bottom = on ground, Top = raised by wall_height with perspective offset
	-- For negative wall_height, "top" is actually below the base (3-point perspective)
	local bx0, by0 = sx0, sy0                           -- bottom-left (base)
	local bx1, by1 = sx1, sy1                           -- bottom-right (base)
	local tx0, ty0 = sx0 + ox, sy0 - wall_height + oy   -- top-left (roof edge)
	local tx1, ty1 = sx1 + ox, sy1 - wall_height + oy   -- top-right (roof edge)

	-- Calculate wall dimensions for texture tiling based on WORLD coordinates
	-- This ensures consistent UV scale regardless of screen position
	local tex_size = 16
	local wall_world_width = sqrt((wx1 - wx0) * (wx1 - wx0) + (wy1 - wy0) * (wy1 - wy0))
	local wall_screen_width = sqrt((bx1 - bx0) * (bx1 - bx0) + (by1 - by0) * (by1 - by0))

	-- UV based on world dimensions (1 tile = 16 world units)
	local u1 = wall_world_width
	local v1 = abs_wall_height

	-- Determine wall orientation
	local dx = abs(bx1 - bx0)
	local dy = abs(by1 - by0)

	if dx >= dy then
		-- Horizontal wall (South/North): scanlines go top to bottom
		local vertical_span = max(abs(by0 - ty0), abs(by1 - ty1))
		local num_scanlines = ceil(vertical_span)
		if num_scanlines < 1 then return end

		-- Start vector: top edge (left and right endpoints)
		-- Format: spr, x0, y0, x1, y1, u0, v0, u1, v1, w0, w1
		local v_start = vec(sprite_idx, tx0, ty0, tx1, ty1, 0, 0, u1, 0, 1, 1)
		-- End vector: bottom edge
		local v_end = vec(sprite_idx, bx0, by0, bx1, by1, 0, v1, u1, v1, 1, 1)

		-- Calculate slope per scanline
		local slope = (v_end - v_start) / num_scanlines

		-- Batch fill scanlines
		scanlines:copy(v_start, true, 0, 0, 11)
		if num_scanlines > 1 then
			scanlines:copy(slope, true, 0, 11, 11, 0, 11, num_scanlines - 1)
			scanlines:add(scanlines, true, 0, 11, 11, 11, 11, num_scanlines - 1)
		end

		tline3d(scanlines, 0, num_scanlines)
	else
		-- Vertical wall (East/West): scanlines go left to right (along width)
		local num_scanlines = ceil(wall_screen_width)
		if num_scanlines < 1 then return end

		-- Start vector: left edge (top and bottom endpoints)
		-- For vertical scanlines: x0,y0 = top point, x1,y1 = bottom point
		local v_start = vec(sprite_idx, tx0, ty0, bx0, by0, 0, 0, 0, v1, 1, 1)
		-- End vector: right edge
		local v_end = vec(sprite_idx, tx1, ty1, bx1, by1, u1, 0, u1, v1, 1, 1)

		-- Calculate slope per scanline
		local slope = (v_end - v_start) / num_scanlines

		-- Batch fill scanlines
		scanlines:copy(v_start, true, 0, 0, 11)
		if num_scanlines > 1 then
			scanlines:copy(slope, true, 0, 11, 11, 0, 11, num_scanlines - 1)
			scanlines:add(scanlines, true, 0, 11, 11, 11, 11, num_scanlines - 1)
		end

		tline3d(scanlines, 0, num_scanlines)
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

-- ============================================
-- OPTIMIZED TEXTRI (based on dark-neb/picocopter)
-- ============================================
-- Fast textured triangle using batched tline3d with userdata
-- Uses vec() and scanlines buffer for true batching (no per-scanline loops)
-- @param spr: sprite index
-- @param x1,y1,u1,v1: vertex 1 (screen coords + UVs)
-- @param x2,y2,u2,v2: vertex 2
-- @param x3,y3,u3,v3: vertex 3
-- @param w1,w2,w3: perspective weights (1/z), default 1 for 2D
function textri(spr, x1, y1, u1, v1, x2, y2, u2, v2, x3, y3, u3, v3, w1, w2, w3)
	w1 = w1 or 1
	w2 = w2 or 1
	w3 = w3 or 1

	-- Sort vertices by Y (bubble sort for 3 elements)
	if y1 > y2 then
		x1, y1, u1, v1, w1, x2, y2, u2, v2, w2 = x2, y2, u2, v2, w2, x1, y1, u1, v1, w1
	end
	if y2 > y3 then
		x2, y2, u2, v2, w2, x3, y3, u3, v3, w3 = x3, y3, u3, v3, w3, x2, y2, u2, v2, w2
	end
	if y1 > y2 then
		x1, y1, u1, v1, w1, x2, y2, u2, v2, w2 = x2, y2, u2, v2, w2, x1, y1, u1, v1, w1
	end

	-- Perspective-correct UVs (multiply by w)
	local uw1, vw1 = u1 * w1, v1 * w1
	local uw2, vw2 = u2 * w2, v2 * w2
	local uw3, vw3 = u3 * w3, v3 * w3

	-- Calculate midpoint on long edge at y2
	local dy13 = y3 - y1
	if dy13 < 1 then return end

	local t = (y2 - y1) / dy13
	local x_mid = x1 + (x3 - x1) * t
	local uw_mid = uw1 + (uw3 - uw1) * t
	local vw_mid = vw1 + (vw3 - vw1) * t
	local w_mid = w1 + (w3 - w1) * t

	-- Build start/end vectors for top half
	local v_start = vec(spr, x1, y1, x1, y1, uw1, vw1, uw1, vw1, w1, w1)
	local v_end = vec(spr, x2, y2, x_mid, y2, uw2, vw2, uw_mid, vw_mid, w2, w_mid)

	-- Clamp to screen
	local start_y = y1 < 0 and 0 or flr(y1)
	local mid_y = y2 < 0 and 0 or y2 > SCREEN_H - 1 and SCREEN_H - 1 or flr(y2)
	local stop_y = y3 <= SCREEN_H - 1 and flr(y3) or SCREEN_H - 1

	-- Top half
	local dy = mid_y - start_y
	if dy > 0 then
		local slope = (v_end - v_start) / (y2 - y1)
		scanlines:copy(slope * (start_y + 1 - y1) + v_start, true, 0, 0, 11)
		if dy > 1 then
			scanlines:copy(slope, true, 0, 11, 11, 0, 11, dy - 1)
			scanlines:add(scanlines, true, 0, 11, 11, 11, 11, dy - 1)
		end
		tline3d(scanlines, 0, dy)
	end

	-- Bottom half
	v_start = vec(spr, x2, y2, x_mid, y2, uw2, vw2, uw_mid, vw_mid, w2, w_mid)
	v_end = vec(spr, x3, y3, x3, y3, uw3, vw3, uw3, vw3, w3, w3)

	dy = stop_y - mid_y
	if dy > 0 then
		local slope = (v_end - v_start) / (y3 - y2)
		scanlines:copy(slope * (mid_y + 1 - y2) + v_start, true, 0, 0, 11)
		if dy > 1 then
			scanlines:copy(slope, true, 0, 11, 11, 0, 11, dy - 1)
			scanlines:add(scanlines, true, 0, 11, 11, 11, 11, dy - 1)
		end
		tline3d(scanlines, 0, dy)
	end
end

-- ============================================
-- OPTIMIZED QUAD RENDERER
-- ============================================
-- Draw a textured quad directly without splitting into triangles
-- More efficient for axis-aligned or simple perspective quads
-- @param spr: sprite index
-- @param x0,y0 to x3,y3: four corners in order (clockwise or counter-clockwise)
-- @param u0,v0 to u3,v3: UV coordinates for each corner
function draw_textured_quad(spr, x0, y0, u0, v0, x1, y1, u1, v1, x2, y2, u2, v2, x3, y3, u3, v3)
	-- For simple 2D quads, use w=1 (no perspective correction needed)
	-- Split into 2 triangles and use textri
	textri(spr, x0, y0, u0, v0, x1, y1, u1, v1, x2, y2, u2, v2)
	textri(spr, x0, y0, u0, v0, x2, y2, u2, v2, x3, y3, u3, v3)
end

-- Fast wall quad renderer - avoids redundant calculations
-- Draws a wall as a single operation instead of 2 separate triangles
-- wall_height can be negative for 3-point perspective (walls go down instead of up)
function draw_wall_quad(sprite_idx, wx0, wy0, wx1, wy1, wall_height, ox, oy)
	local abs_wall_height = abs(wall_height)
	if abs_wall_height < 1 then return end

	-- Convert to screen coordinates
	local sx0, sy0 = world_to_screen(wx0, wy0)
	local sx1, sy1 = world_to_screen(wx1, wy1)

	-- Wall corners
	-- For negative wall_height, "top" is actually below the base (3-point perspective)
	local bx0, by0 = sx0, sy0                           -- bottom-left (base)
	local bx1, by1 = sx1, sy1                           -- bottom-right (base)
	local tx0, ty0 = sx0 + ox, sy0 - wall_height + oy   -- top-left (roof edge)
	local tx1, ty1 = sx1 + ox, sy1 - wall_height + oy   -- top-right (roof edge)

	-- Calculate UV tiling based on WORLD coordinates
	-- This ensures consistent UV scale regardless of screen position
	local wall_world_width = sqrt((wx1 - wx0) * (wx1 - wx0) + (wy1 - wy0) * (wy1 - wy0))

	-- UV based on world dimensions (1 tile = 16 world units)
	local u1 = wall_world_width
	local v1 = abs_wall_height

	-- Draw as 2 triangles using optimized textri
	textri(sprite_idx, tx0, ty0, 0, 0, bx0, by0, 0, v1, tx1, ty1, u1, 0)
	textri(sprite_idx, tx1, ty1, u1, 0, bx0, by0, 0, v1, bx1, by1, u1, v1)
end
